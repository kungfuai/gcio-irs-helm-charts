#!/usr/bin/env python3
"""Validate that changed charts declare unreleased chart versions."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHARTS_DIR = ROOT / "charts"


def run(command: list[str], *, cwd: Path = ROOT) -> str:
    completed = subprocess.run(
        command,
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        if completed.stdout:
            print(f"stdout:\n{completed.stdout}", file=sys.stderr)
        if completed.stderr:
            print(f"stderr:\n{completed.stderr}", file=sys.stderr)
        raise RuntimeError(f"{' '.join(command)} failed with exit code {completed.returncode}")
    return completed.stdout


def chart_metadata(chart_dir: Path) -> tuple[str, str]:
    metadata: dict[str, str] = {}
    for line in (chart_dir / "Chart.yaml").read_text(encoding="utf-8").splitlines():
        if ":" not in line or line.startswith((" ", "\t", "#")):
            continue
        key, value = line.split(":", 1)
        if key in {"name", "version"}:
            metadata[key] = value.strip().strip("\"'")
    return metadata["name"], metadata["version"]


def changed_chart_names(base_ref: str, head_ref: str = "HEAD", *, root: Path = ROOT) -> set[str]:
    changed_files = run(["git", "diff", "--name-only", f"{base_ref}...{head_ref}"], cwd=root)
    charts: set[str] = set()
    for changed_file in changed_files.splitlines():
        parts = changed_file.split("/", 2)
        if len(parts) < 2 or parts[0] != "charts":
            continue
        chart_name = parts[1]
        if (root / "charts" / chart_name / "Chart.yaml").is_file():
            charts.add(chart_name)
    return charts


def tag_exists(tag_name: str, *, root: Path = ROOT) -> bool:
    completed = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", f"refs/tags/{tag_name}"],
        cwd=root,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return completed.returncode == 0


def validate_changed_chart_versions(
    *,
    base_ref: str,
    head_ref: str = "HEAD",
    root: Path = ROOT,
) -> list[str]:
    failures: list[str] = []
    charts = changed_chart_names(base_ref, head_ref, root=root)
    if not charts:
        print("no changed charts require release version validation")
        return failures

    for chart_name in sorted(charts):
        release_name, version = chart_metadata(root / "charts" / chart_name)
        tag_name = f"{release_name}-{version}"
        if tag_exists(tag_name, root=root):
            failures.append(
                f"{chart_name}: release tag {tag_name} already exists; "
                f"bump charts/{chart_name}/Chart.yaml version"
            )
        else:
            print(f"{chart_name}: release tag {tag_name} is available")

    return failures


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True, help="Base git ref for changed-file detection")
    parser.add_argument("--head", default="HEAD", help="Head git ref for changed-file detection")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        failures = validate_changed_chart_versions(base_ref=args.base, head_ref=args.head)
    except Exception as exc:  # noqa: BLE001 - normalize CI errors at the script seam.
        print(f"::error::{exc}", file=sys.stderr)
        return 1

    if failures:
        for failure in failures:
            print(f"::error::{failure}", file=sys.stderr)
        return 1

    print("chart release versions ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
