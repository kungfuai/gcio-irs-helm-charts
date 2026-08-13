from __future__ import annotations

from chart_contract import env_by_name, find_doc, first_container, render_chart, secret_ref

SCALABLE_CHARTS = ("lander", "worker", "extractor")


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
    assert env["NOTIFIER_WIRE_MONIKERS"]["value"] == (
        '{"falpha_2025_12":"FALPHA_2025_12","fbeta_2025":"FBETA_2025_10"}'
    )
    assert secret_ref(container, "DATABASE_URL") == {"name": "worker", "key": "database-url"}
    assert secret_ref(container, "NOTIFIER_CLIENT_SECRET") == {
        "name": "kfai-testing-notifier",
        "key": "NOTIFIER_CLIENT_SECRET",
    }


def test_worker_wire_monikers_env_absent_when_map_empty() -> None:
    """An empty wireMonikers map must omit NOTIFIER_WIRE_MONIKERS entirely.

    The worker treats an absent env var as passthrough (emit internal labels).
    Rendering an empty-string or "{}" value instead would change behavior at
    the app's validator boundary, so absence is the asserted contract.
    """
    docs = render_chart(
        "worker",
        "worker",
        "--set",
        "aws.s3Bucket=b",
        "--set",
        "aws.sqs.workerQueueURL=q",
        "--set",
        "aws.sqs.statusQueueURL=s",
    )
    env = env_by_name(first_container(find_doc(docs, kind="Deployment", name="worker"), "worker"))
    assert "NOTIFIER_WIRE_MONIKERS" not in env


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


def test_replicas_omitted_when_replica_count_is_null() -> None:
    """A null replicaCount must omit .spec.replicas from the Deployment.

    Rendering the field is what puts it under helm's field management, so a
    later `kubectl scale` (throughput profiling) makes kubectl the field manager
    and the next sync fails with an apply conflict on .spec.replicas. Omitting
    the field entirely lets helm own the pod spec while kubectl or an HPA owns
    scaling. Rendering `replicas: null` would not do: the field is still
    applied, so helm still manages it.
    """
    for chart in SCALABLE_CHARTS:
        docs = render_chart(
            chart,
            chart,
            "-f",
            f"./charts/{chart}/ci/all-values.yaml",
            "--set",
            "replicaCount=null",
        )
        deployment = find_doc(docs, kind="Deployment", name=chart)

        assert "replicas" not in deployment["spec"], f"{chart} still renders .spec.replicas"


def test_replicas_rendered_when_replica_count_is_set() -> None:
    """An explicit replicaCount still renders, including the scale-to-zero case.

    Zero is falsy in templates, so a truthiness guard would silently drop it and
    scale a paused service back to the Kubernetes default of 1. Only an unset
    value opts out of helm-managed replicas.
    """
    for chart in SCALABLE_CHARTS:
        values = f"./charts/{chart}/ci/all-values.yaml"

        default = find_doc(render_chart(chart, chart, "-f", values), kind="Deployment", name=chart)
        assert default["spec"]["replicas"] == 1, f"{chart} default replicas changed"

        scaled = find_doc(
            render_chart(chart, chart, "-f", values, "--set", "replicaCount=3"),
            kind="Deployment",
            name=chart,
        )
        assert scaled["spec"]["replicas"] == 3, f"{chart} ignored an explicit replicaCount"

        paused = find_doc(
            render_chart(chart, chart, "-f", values, "--set", "replicaCount=0"),
            kind="Deployment",
            name=chart,
        )
        assert paused["spec"]["replicas"] == 0, f"{chart} dropped a scale-to-zero replicaCount"
