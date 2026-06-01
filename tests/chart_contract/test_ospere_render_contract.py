from __future__ import annotations

import json

from chart_contract import (
    assert_secret_refs,
    env_by_name,
    find_doc,
    first_container,
    pod_spec,
    render_chart,
)


def test_ospere_hooks_and_workloads_render_from_chart_contract_fixture() -> None:
    docs = render_chart(
        "ospere",
        "ospere",
        "--namespace",
        "ospere",
        "-f",
        "./charts/ospere/ci/all-values.yaml",
        "--set",
        "jobs.ensureAdmin.create=true",
        "--set",
        "jobs.ensureAdmin.existingSecret=ospere-admin-bootstrap",
    )

    find_doc(docs, kind="ServiceAccount", name="ospere")
    find_doc(docs, kind="Deployment", name="ospere")
    find_doc(docs, kind="Deployment", name="ospere-worker")
    find_doc(docs, kind="Deployment", name="ospere-beat")

    migration = find_doc(docs, kind="Job", name="ospere-migrate")
    migration_annotations = migration["metadata"]["annotations"]
    assert migration_annotations["helm.sh/hook"] == "pre-install,pre-upgrade"
    assert migration_annotations["helm.sh/hook-weight"] == "8"
    assert "serviceAccountName" not in pod_spec(migration, "ospere migration")
    assert first_container(migration, "ospere migration")["command"] == [
        "python",
        "manage.py",
        "lockedmigrate",
        "--noinput",
    ]

    ensure_admin = find_doc(docs, kind="Job", name="ospere-ensure-admin")
    ensure_admin_annotations = ensure_admin["metadata"]["annotations"]
    assert ensure_admin_annotations["helm.sh/hook"] == "pre-install,pre-upgrade"
    assert ensure_admin_annotations["helm.sh/hook-weight"] == "16"
    assert "serviceAccountName" not in pod_spec(ensure_admin, "ospere ensure-admin")
    ensure_admin_container = first_container(ensure_admin, "ospere ensure-admin")
    assert ensure_admin_container["command"] == ["python", "manage.py", "syncadmin"]
    assert_secret_refs(
        ensure_admin_container,
        {
            "DJANGO_ADMIN_USERNAME": {"name": "ospere-admin-bootstrap", "key": "username"},
            "DJANGO_ADMIN_EMAIL": {"name": "ospere-admin-bootstrap", "key": "email"},
            "DJANGO_ADMIN_PASSWORD": {"name": "ospere-admin-bootstrap", "key": "password"},
        },
    )


def test_ospere_value_backed_mef_and_celery_contract() -> None:
    docs = render_chart(
        "ospere",
        "ospere",
        "--namespace",
        "ospere",
        "-f",
        "./charts/ospere/ci/all-values.yaml",
    )

    web_env = env_by_name(first_container(find_doc(docs, kind="Deployment", name="ospere"), "ospere web"))
    assert web_env["MEF_CLIENT_SYSTEM_IDS"]["value"] == "client-system,client-system-secondary"
    assert web_env["MEF_CLIENT_SYSTEM_ID"]["value"] == "client-system"
    assert json.loads(web_env["MEF_SOFTWARE_IDS_BY_TAX_YEAR"]["value"]) == {
        "2024": "24024829",
        "2025": "25024827",
        "2026": "26024828",
    }
    assert web_env["MEF_DEFAULT_TAX_YEAR"]["value"] == "2025"
    assert web_env["CELERY_BROKER_URL"]["valueFrom"]["secretKeyRef"] == {
        "name": "ospere",
        "key": "celery-broker-url",
    }

    worker = first_container(find_doc(docs, kind="Deployment", name="ospere-worker"), "ospere worker")
    worker_env = env_by_name(worker)
    assert worker_env["OSPERE_SERVICE_COMPONENT"]["value"] == "celery.worker"
    assert worker_env["CELERY_WORKER_CONCURRENCY"]["value"] == "5"
    assert "--concurrency=$(CELERY_WORKER_CONCURRENCY)" in worker["args"]

    beat_env = env_by_name(first_container(find_doc(docs, kind="Deployment", name="ospere-beat"), "ospere beat"))
    assert beat_env["OSPERE_SERVICE_COMPONENT"]["value"] == "celery.beat"


def test_ospere_secret_backed_mef_contract() -> None:
    docs = render_chart(
        "ospere",
        "ospere",
        "--namespace",
        "ospere",
        "--set",
        "database.host=postgres.example.com",
        "--set",
        "aws.s3.artifactsBucket=ospere-artifacts",
        "--set",
        "secrets.celeryBrokerURL.name=ospere-db",
        "--set",
        "secrets.celeryResultBackend.name=ospere-db",
        "--set",
        "ospere.mef.cert.secretName=ospere-mef-client-cert-bundle",
    )

    web_container = first_container(find_doc(docs, kind="Deployment", name="ospere"), "ospere web")
    assert_secret_refs(
        web_container,
        {
            "MEF_CLIENT_SYSTEM_IDS": {"name": "ospere-mef-client-cert-bundle", "key": "client_system_ids"},
            "MEF_CLIENT_SYSTEM_ID": {"name": "ospere-mef-client-cert-bundle", "key": "client_system_id"},
            "MEF_EFIN": {"name": "ospere-mef-client-cert-bundle", "key": "efin"},
            "MEF_ETIN": {"name": "ospere-mef-client-cert-bundle", "key": "etin"},
            "MEF_SOFTWARE_IDS_BY_TAX_YEAR": {
                "name": "ospere-mef-client-cert-bundle",
                "key": "software_ids_by_tax_year",
            },
        },
    )

    assert any(mount["name"] == "mef-cert" for mount in web_container.get("volumeMounts", []))
