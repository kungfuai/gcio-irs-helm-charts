from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = ROOT / ".github" / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
