from __future__ import annotations

from chart_contract import lint_charts


def test_charts_lint() -> None:
    lint_charts()
