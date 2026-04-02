from __future__ import annotations

from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parent
PYTHON_ROOT = PACKAGE_ROOT.parent.parent
BUILD_SYSTEM_ROOT = PYTHON_ROOT.parent
REPO_ROOT = BUILD_SYSTEM_ROOT.parent
CONFIG_TEMPLATE_PATH = BUILD_SYSTEM_ROOT / "tooling.template.json"
CONFIG_PATH = BUILD_SYSTEM_ROOT / "tooling.json"
BOARDS_MANIFEST_PATH = REPO_ROOT / "resources" / "boards.json"
