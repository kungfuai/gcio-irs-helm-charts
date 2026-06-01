from __future__ import annotations

from chart_contract import env_by_name, find_doc, first_container, render_chart, secret_ref


def test_lander_chart_contract() -> None:
    docs = render_chart("lander", "lander", "-f", "./charts/lander/ci/all-values.yaml")

    find_doc(docs, kind="ServiceAccount", name="lander")
    find_doc(docs, kind="Service", name="lander")
    deployment = find_doc(docs, kind="Deployment", name="lander")
    container = first_container(deployment, "lander")
    env = env_by_name(container)

    assert container["livenessProbe"]["httpGet"]["path"] == "/livez"
    assert container["readinessProbe"]["httpGet"]["path"] == "/readyz"
    assert env["S3_BUCKET"]["value"] == "kfai-testing-cache"
    assert env["SQS_WORKER_QUEUE_URL"]["value"] == "kfai-testing-worker-queue-url"
    assert env["DISABLE_INTAKE"]["value"] == "true"
    assert secret_ref(container, "DATABASE_URL") == {"name": "lander", "key": "database-url"}

    migration = find_doc(docs, kind="Job", name="lander-migrate")
    assert migration["metadata"]["annotations"]["helm.sh/hook"] == "pre-install,pre-upgrade"
    assert first_container(migration, "lander migration")["command"] == ["python", "-m", "alembic", "upgrade", "head"]


def test_worker_chart_contract() -> None:
    docs = render_chart("worker", "worker", "-f", "./charts/worker/ci/all-values.yaml")

    find_doc(docs, kind="ServiceAccount", name="worker")
    find_doc(docs, kind="Service", name="worker")
    deployment = find_doc(docs, kind="Deployment", name="worker")
    container = first_container(deployment, "worker")
    env = env_by_name(container)

    assert "livenessProbe" not in container
    assert "readinessProbe" not in container
    assert env["S3_BUCKET"]["value"] == "kfai-testing-cache"
    assert env["SQS_NUM_WORKERS"]["value"] == "1"
    assert env["NOTIFIER_ENABLED"]["value"] == "true"
    assert secret_ref(container, "DATABASE_URL") == {"name": "worker", "key": "database-url"}
    assert secret_ref(container, "NOTIFIER_CLIENT_SECRET") == {
        "name": "kfai-testing-notifier",
        "key": "NOTIFIER_CLIENT_SECRET",
    }


def test_extractor_chart_contract() -> None:
    docs = render_chart("extractor", "extractor", "-f", "./charts/extractor/ci/all-values.yaml")

    find_doc(docs, kind="ServiceAccount", name="extractor")
    find_doc(docs, kind="Service", name="extractor")
    deployment = find_doc(docs, kind="Deployment", name="extractor")
    container = first_container(deployment, "extractor")
    env = env_by_name(container)

    assert deployment["spec"]["strategy"]["type"] == "Recreate"
    assert container["livenessProbe"]["httpGet"]["path"] == "/livez"
    assert container["readinessProbe"]["httpGet"]["path"] == "/readyz"
    assert env["S3_BUCKET"]["value"] == "kfai-testing-cache"
    assert env["LOG_LEVEL"]["value"] == "ERROR"
    assert env["BEDROCK_HAIKU_MODEL"]["value"].startswith("us-gov.anthropic.")
    assert secret_ref(container, "DATABASE_URL") == {"name": "extractor", "key": "database-url"}


def test_inspector_chart_contract() -> None:
    docs = render_chart("inspector", "inspector", "-f", "./tests/chart_contract/fixtures/inspector/all-values.yaml")

    service = find_doc(docs, kind="Service", name="inspector")
    deployment = find_doc(docs, kind="Deployment", name="inspector")
    ingress = find_doc(docs, kind="Ingress", name="inspector")
    container = first_container(deployment, "inspector")

    assert container["image"] == "example.com/facture-inspector:contract"
    assert container["livenessProbe"]["httpGet"]["path"] == "/healthz"
    assert container["readinessProbe"]["httpGet"]["path"] == "/healthz"
    assert service["spec"]["ports"][0]["targetPort"] == "http"
    assert ingress["spec"]["ingressClassName"] == "alb"
    assert ingress["spec"]["rules"][0]["host"] == "inspector.example.com"
