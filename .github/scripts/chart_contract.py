#!/usr/bin/env python3
"""Helm chart contract helpers.

Workflows own setup and invocation. These helpers own chart behavior assertions
so the workflow YAML stays thin.
"""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[2]
CHARTS_DIR = ROOT / "charts"


def run(command: list[str]) -> str:
    completed = subprocess.run(
        command,
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            f"{' '.join(command)} failed\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )
    return completed.stdout


def lint_charts() -> None:
    for chart in sorted(CHARTS_DIR.iterdir()):
        if chart.is_dir():
            run(["helm", "lint", str(chart)])


def render_chart(release: str, chart: str, *args: str) -> list[dict[str, Any]]:
    rendered = run(["helm", "template", release, f"./charts/{chart}", *args])
    return [doc for doc in yaml.safe_load_all(rendered) if isinstance(doc, dict)]


def find_doc(
    docs: list[dict[str, Any]],
    *,
    kind: str,
    name: str,
) -> dict[str, Any]:
    for doc in docs:
        if doc.get("kind") == kind and doc.get("metadata", {}).get("name") == name:
            return doc
    raise AssertionError(f"{name} {kind} missing from rendered chart")


def pod_spec(doc: dict[str, Any], context: str) -> dict[str, Any]:
    try:
        return doc["spec"]["template"]["spec"]
    except KeyError as exc:
        raise AssertionError(f"{context} pod spec missing from rendered chart") from exc


def first_container(doc: dict[str, Any], context: str) -> dict[str, Any]:
    containers = pod_spec(doc, context).get("containers", [])
    if not containers:
        raise AssertionError(f"{context} container missing from rendered chart")
    return containers[0]


def env_by_name(container: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {env_var["name"]: env_var for env_var in container.get("env", [])}


def secret_ref(container: dict[str, Any], env_name: str) -> dict[str, str] | None:
    return (
        env_by_name(container)
        .get(env_name, {})
        .get("valueFrom", {})
        .get("secretKeyRef")
    )


def assert_secret_refs(
    container: dict[str, Any],
    expected_refs: dict[str, dict[str, str]],
) -> None:
    for env_name, expected in expected_refs.items():
        actual = secret_ref(container, env_name)
        assert actual == expected, f"{env_name} must render from {expected}, got {actual}"
