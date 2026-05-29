#!/usr/bin/env ruby
# frozen_string_literal: true

# Validate rendered Helm chart contracts.
#
# The workflow owns setup and invocation. This script owns chart behavior
# assertions so CI YAML stays wiring-only.

require "open3"
require "json"
require "yaml"

ROOT = File.expand_path("../..", __dir__)
CHARTS_DIR = File.join(ROOT, "charts")

def run!(*command)
  stdout, stderr, status = Open3.capture3(*command, chdir: ROOT)
  unless status.success?
    warn stderr
    raise "#{command.join(' ')} failed"
  end
  stdout
end

def render_chart(release, chart, *args)
  rendered = run!("helm", "template", release, "./charts/#{chart}", *args)
  YAML.load_stream(rendered).select { |doc| doc.is_a?(Hash) }
end

def find_doc!(docs, kind:, name:)
  docs.find do |doc|
    doc["kind"] == kind && doc.dig("metadata", "name") == name
  end || raise("#{name} #{kind} missing from rendered chart")
end

def pod_spec!(doc, context)
  doc.dig("spec", "template", "spec") || raise("#{context} pod spec missing from rendered chart")
end

def first_container!(doc, context)
  container = pod_spec!(doc, context).dig("containers", 0)
  container || raise("#{context} container missing from rendered chart")
end

def env_by_name(container)
  (container["env"] || []).each_with_object({}) do |env_var, refs|
    refs[env_var["name"]] = env_var
  end
end

def assert_secret_refs!(container, expected_refs, context)
  env = env_by_name(container)

  expected_refs.each do |name, expected|
    actual = env.dig(name, "valueFrom", "secretKeyRef")
    next if actual == expected

    raise "#{context} must render #{name} from #{expected}"
  end
end

def lint_charts!
  Dir.children(CHARTS_DIR).sort.each do |name|
    chart = File.join(CHARTS_DIR, name)
    next unless File.directory?(chart)

    system("helm", "lint", chart, chdir: ROOT, exception: true)
  end
end

def validate_worker_non_http_contract!
  docs = render_chart(
    "worker",
    "worker",
    "--set", "aws.s3Bucket=contract-bucket",
    "--set", "aws.sqs.workerQueueURL=https://example.com/worker-queue",
    "--set", "aws.sqs.statusQueueURL=https://example.com/status-queue"
  )
  deployment = find_doc!(docs, kind: "Deployment", name: "worker")
  container = first_container!(deployment, "worker")

  raise "worker deployment still emits livenessProbe" if container.key?("livenessProbe")
  raise "worker deployment still emits readinessProbe" if container.key?("readinessProbe")
end

def validate_ospere_hook_contract!
  docs = render_chart(
    "ospere",
    "ospere",
    "--namespace", "ospere",
    "-f", "./charts/ospere/ci/all-values.yaml",
    "--set", "jobs.ensureAdmin.create=true",
    "--set", "jobs.ensureAdmin.existingSecret=ospere-admin-bootstrap"
  )

  migration = find_doc!(docs, kind: "Job", name: "ospere-migrate")
  migration_annotations = migration.dig("metadata", "annotations") || {}
  raise "ospere migration hook must run before install and upgrade" unless migration_annotations["helm.sh/hook"] == "pre-install,pre-upgrade"
  raise "ospere migration hook weight must be 8" unless migration_annotations["helm.sh/hook-weight"] == "8"

  migration_pod_spec = pod_spec!(migration, "ospere migration")
  if migration_pod_spec.key?("serviceAccountName")
    raise "ospere pre-install migration hook must not reference chart-created serviceAccountName by default"
  end

  migration_container = first_container!(migration, "ospere migration")
  unless migration_container["command"] == ["python", "manage.py", "lockedmigrate", "--noinput"]
    raise "ospere migration hook must use lockedmigrate"
  end

  ensure_admin = find_doc!(docs, kind: "Job", name: "ospere-ensure-admin")
  ensure_admin_annotations = ensure_admin.dig("metadata", "annotations") || {}
  raise "ospere ensure-admin hook must run before install and upgrade" unless ensure_admin_annotations["helm.sh/hook"] == "pre-install,pre-upgrade"
  raise "ospere ensure-admin hook must run after migrations" unless ensure_admin_annotations["helm.sh/hook-weight"] == "16"

  ensure_admin_pod_spec = pod_spec!(ensure_admin, "ospere ensure-admin")
  if ensure_admin_pod_spec.key?("serviceAccountName")
    raise "ospere pre-install ensure-admin hook must not reference chart-created serviceAccountName by default"
  end

  ensure_admin_container = first_container!(ensure_admin, "ospere ensure-admin")
  raise "ospere ensure-admin hook must use syncadmin" unless ensure_admin_container["command"] == ["python", "manage.py", "syncadmin"]

  assert_secret_refs!(
    ensure_admin_container,
    {
      "DJANGO_ADMIN_USERNAME" => {"name" => "ospere-admin-bootstrap", "key" => "username"},
      "DJANGO_ADMIN_EMAIL" => {"name" => "ospere-admin-bootstrap", "key" => "email"},
      "DJANGO_ADMIN_PASSWORD" => {"name" => "ospere-admin-bootstrap", "key" => "password"}
    },
    "ospere ensure-admin hook"
  )

  find_doc!(docs, kind: "ServiceAccount", name: "ospere")
  deployment = find_doc!(docs, kind: "Deployment", name: "ospere")
  web_env = env_by_name(first_container!(deployment, "ospere web"))
  unless web_env.dig("MEF_CLIENT_SYSTEM_IDS", "value") == "client-system,client-system-secondary"
    raise "ospere chart must render canonical MEF_CLIENT_SYSTEM_IDS"
  end
  raise "ospere chart must preserve compatibility MEF_CLIENT_SYSTEM_ID" unless web_env.dig("MEF_CLIENT_SYSTEM_ID", "value") == "client-system"
  expected_software_ids = {"2024" => "24024829", "2025" => "25024827", "2026" => "26024828"}
  unless JSON.parse(web_env.dig("MEF_SOFTWARE_IDS_BY_TAX_YEAR", "value")) == expected_software_ids
    raise "ospere chart must render canonical MEF_SOFTWARE_IDS_BY_TAX_YEAR"
  end
  raise "ospere chart must render MEF_DEFAULT_TAX_YEAR" unless web_env.dig("MEF_DEFAULT_TAX_YEAR", "value") == "2025"
end

def validate_ospere_secret_backed_env_contract!
  docs = render_chart(
    "ospere",
    "ospere",
    "--namespace", "ospere",
    "--set", "database.host=postgres.example.com",
    "--set", "aws.s3.artifactsBucket=ospere-artifacts",
    "--set", "ospere.mef.cert.secretName=ospere-mef-client-cert-bundle"
  )
  deployment = find_doc!(docs, kind: "Deployment", name: "ospere")
  web_container = first_container!(deployment, "ospere web")

  assert_secret_refs!(
    web_container,
    {
      "MEF_CLIENT_SYSTEM_IDS" => {"name" => "ospere-mef-client-cert-bundle", "key" => "client_system_ids"},
      "MEF_CLIENT_SYSTEM_ID" => {"name" => "ospere-mef-client-cert-bundle", "key" => "client_system_id"},
      "MEF_EFIN" => {"name" => "ospere-mef-client-cert-bundle", "key" => "efin"},
      "MEF_ETIN" => {"name" => "ospere-mef-client-cert-bundle", "key" => "etin"},
      "MEF_SOFTWARE_IDS_BY_TAX_YEAR" => {"name" => "ospere-mef-client-cert-bundle", "key" => "software_ids_by_tax_year"}
    },
    "ospere chart"
  )

  mounts = web_container["volumeMounts"] || []
  raise "ospere chart must mount the MeF cert Secret" unless mounts.any? { |mount| mount["name"] == "mef-cert" }
end

def validate_ospere_worker_contract!
  docs = render_chart(
    "ospere",
    "ospere",
    "--namespace", "ospere",
    "-f", "./charts/ospere/ci/all-values.yaml",
    "--set", "worker.enabled=true",
    "--set", "worker.concurrency=5"
  )
  deployment = find_doc!(docs, kind: "Deployment", name: "ospere-worker")
  worker_container = first_container!(deployment, "ospere worker")
  worker_env = env_by_name(worker_container)

  raise "ospere worker must render CELERY_WORKER_CONCURRENCY" unless worker_env.dig("CELERY_WORKER_CONCURRENCY", "value") == "5"
  unless (worker_container["args"] || []).include?("--concurrency=$(CELERY_WORKER_CONCURRENCY)")
    raise "ospere worker args must pass CELERY_WORKER_CONCURRENCY to Celery"
  end
end

begin
  lint_charts!
  validate_worker_non_http_contract!
  validate_ospere_hook_contract!
  validate_ospere_secret_backed_env_contract!
  validate_ospere_worker_contract!
  puts "chart contracts ok"
rescue StandardError => e
  warn "::error::#{e.message}"
  exit 1
end
