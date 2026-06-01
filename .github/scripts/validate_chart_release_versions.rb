#!/usr/bin/env ruby
# frozen_string_literal: true

# Validate that changed charts declare an unreleased chart version.
#
# Chart releaser publishes releases as <chart-name>-<chart-version>. If a chart
# changes without a version bump, the release workflow fails after merge with a
# GitHub "tag already exists" error. This script moves that invariant into CI.

require "open3"
require "yaml"
require "set"
require "optparse"

ROOT = File.expand_path("../..", __dir__)
CHARTS_DIR = File.join(ROOT, "charts")

options = {
  base_ref: ENV["CHART_VERSION_BASE_REF"],
  head_ref: ENV.fetch("CHART_VERSION_HEAD_REF", "HEAD")
}

OptionParser.new do |parser|
  parser.on("--base REF", "Base git ref for changed-file detection") { |value| options[:base_ref] = value }
  parser.on("--head REF", "Head git ref for changed-file detection") { |value| options[:head_ref] = value }
end.parse!

def run!(*command)
  stdout, stderr, status = Open3.capture3(*command, chdir: ROOT)
  unless status.success?
    warn stderr
    raise "#{command.join(' ')} failed"
  end
  stdout
end

def chart_metadata(chart_name)
  path = File.join(CHARTS_DIR, chart_name, "Chart.yaml")
  metadata = YAML.safe_load(File.read(path))
  name = metadata.fetch("name")
  version = metadata.fetch("version")
  [name, version]
end

def changed_chart_names(base_ref, head_ref)
  raise "base ref is required for chart release version validation" if base_ref.to_s.empty?

  changed_files = run!("git", "diff", "--name-only", "#{base_ref}...#{head_ref}").lines.map(&:strip)
  changed_files.each_with_object(Set.new) do |path, charts|
    next unless path.start_with?("charts/")

    _charts_dir, chart_name, = path.split("/", 3)
    next if chart_name.to_s.empty?
    next unless File.file?(File.join(CHARTS_DIR, chart_name, "Chart.yaml"))

    charts << chart_name
  end
end

def tag_exists?(tag_name)
  system("git", "rev-parse", "--verify", "--quiet", "refs/tags/#{tag_name}", chdir: ROOT, out: File::NULL)
end

begin
  charts = changed_chart_names(options.fetch(:base_ref), options.fetch(:head_ref))

  if charts.empty?
    puts "no changed charts require release version validation"
    exit 0
  end

  failures = []
  charts.sort.each do |chart_name|
    release_name, version = chart_metadata(chart_name)
    tag_name = "#{release_name}-#{version}"
    if tag_exists?(tag_name)
      failures << "#{chart_name}: release tag #{tag_name} already exists; bump charts/#{chart_name}/Chart.yaml version"
    else
      puts "#{chart_name}: release tag #{tag_name} is available"
    end
  end

  unless failures.empty?
    failures.each { |failure| warn "::error::#{failure}" }
    exit 1
  end

  puts "chart release versions ok"
rescue StandardError => e
  warn "::error::#{e.message}"
  exit 1
end
