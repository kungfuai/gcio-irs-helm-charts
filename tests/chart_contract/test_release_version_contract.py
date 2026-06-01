from __future__ import annotations

import subprocess
from pathlib import Path

from validate_chart_release_versions import validate_changed_chart_versions


def run(command: list[str], cwd: Path) -> None:
    subprocess.run(command, cwd=cwd, check=True, capture_output=True, text=True)


def write_chart(root: Path, name: str, version: str) -> None:
    chart_dir = root / "charts" / name
    chart_dir.mkdir(parents=True, exist_ok=True)
    (chart_dir / "Chart.yaml").write_text(
        "\n".join(
            [
                "apiVersion: v2",
                f"name: {name}",
                "description: test chart",
                "type: application",
                f"version: {version}",
                'appVersion: "1.0.0"',
                "",
            ]
        ),
        encoding="utf-8",
    )


def init_repo(root: Path) -> None:
    run(["git", "init", "-b", "main"], root)
    run(["git", "config", "user.email", "test@example.com"], root)
    run(["git", "config", "user.name", "Test User"], root)


def test_release_version_contract_rejects_existing_changed_chart_tag(tmp_path: Path) -> None:
    init_repo(tmp_path)
    write_chart(tmp_path, "ospere", "0.1.7")
    run(["git", "add", "."], tmp_path)
    run(["git", "commit", "-m", "initial chart"], tmp_path)
    run(["git", "tag", "--no-sign", "ospere-0.1.7"], tmp_path)

    base_ref = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=tmp_path, text=True).strip()
    (tmp_path / "charts" / "ospere" / "values.yaml").write_text("worker:\n  enabled: true\n", encoding="utf-8")
    run(["git", "add", "."], tmp_path)
    run(["git", "commit", "-m", "change chart without version bump"], tmp_path)

    failures = validate_changed_chart_versions(base_ref=base_ref, root=tmp_path)

    assert failures == [
        "ospere: release tag ospere-0.1.7 already exists; bump charts/ospere/Chart.yaml version"
    ]


def test_release_version_contract_allows_unreleased_changed_chart_tag(tmp_path: Path) -> None:
    init_repo(tmp_path)
    write_chart(tmp_path, "ospere", "0.1.7")
    run(["git", "add", "."], tmp_path)
    run(["git", "commit", "-m", "initial chart"], tmp_path)
    run(["git", "tag", "--no-sign", "ospere-0.1.7"], tmp_path)

    base_ref = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=tmp_path, text=True).strip()
    write_chart(tmp_path, "ospere", "0.1.8")
    run(["git", "add", "."], tmp_path)
    run(["git", "commit", "-m", "bump chart version"], tmp_path)

    assert validate_changed_chart_versions(base_ref=base_ref, root=tmp_path) == []
