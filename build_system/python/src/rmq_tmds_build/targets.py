from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from .config import deep_merge, load_json
from .paths import BOARDS_LOCAL_MANIFEST_PATH, BOARDS_MANIFEST_PATH, REPO_ROOT


@dataclass(frozen=True)
class BoardTarget:
    board: str
    display_name: str
    family_key: str
    default_backend: str
    allowed_toolchains: tuple[str, ...]
    related_name: str
    tmds_project: str | None
    blinky_project: str | None
    tmds_root: str | None
    blinky_root: str | None


@dataclass(frozen=True)
class ProjectContext:
    board: str
    design: str
    backend: str
    base_path: Path
    project_file: Path | None
    project_config: dict

def load_checked_in_boards_manifest() -> dict:
    with BOARDS_MANIFEST_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def load_boards_local_manifest() -> dict:
    if not BOARDS_LOCAL_MANIFEST_PATH.exists():
        return {}
    return load_json(BOARDS_LOCAL_MANIFEST_PATH)


def default_boards_local_manifest(manifest: dict | None = None) -> dict:
    source_manifest = manifest or load_checked_in_boards_manifest()
    boards: dict[str, dict] = {}
    for board, metadata in source_manifest.get("boards", {}).items():
        host_interface = metadata.get("host_interfaces", {}).get("wsl2_ftdi")
        if not isinstance(host_interface, dict):
            continue
        boards[board] = {
            "host_interfaces": {
                "wsl2_ftdi": {
                    "local_override": {
                        "preferred_serial": "",
                        "preferred_vid_pid": host_interface.get("expected_vid_pid", ""),
                        "preferred_tty_ports": list(host_interface.get("expected_tty_ports", [])),
                        "notes": "",
                    }
                }
            }
        }
    return {
        "manifest_version": source_manifest.get("manifest_version", 1),
        "notes": [
            "Machine-local WSL2 FTDI overrides. Safe to edit locally; do not commit this file.",
            "Only host-interface data should be overridden here. Canonical board metadata stays in resources/boards.json.",
        ],
        "boards": boards,
    }


def ensure_boards_local_manifest() -> Path:
    if BOARDS_LOCAL_MANIFEST_PATH.exists():
        return BOARDS_LOCAL_MANIFEST_PATH
    manifest = default_boards_local_manifest()
    BOARDS_LOCAL_MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return BOARDS_LOCAL_MANIFEST_PATH


def load_boards_manifest() -> dict:
    manifest = load_checked_in_boards_manifest()
    local_manifest = load_boards_local_manifest()
    if local_manifest:
        manifest = deep_merge(manifest, local_manifest)
    return manifest


def _family_key_for_platform(platform: str) -> str:
    if platform == "gowin":
        return "gowin_family"
    if platform == "artix":
        return "artix_family"
    return f"{platform}_family"


def _project_root_for_path(relative_path: str | None) -> str | None:
    if not relative_path:
        return None
    return str(Path(relative_path).parent)


def _blinky_root_for_paths(paths: dict) -> str | None:
    if paths.get("blinky_project"):
        return _project_root_for_path(paths["blinky_project"])
    if paths.get("blinky_source"):
        return str(Path(paths["blinky_source"]).parent.parent)
    return None


def _build_targets() -> dict[str, BoardTarget]:
    manifest = load_boards_manifest()
    targets: dict[str, BoardTarget] = {}
    for board, metadata in manifest.get("boards", {}).items():
        paths = metadata.get("paths", {})
        platform = metadata.get("platform", "")
        vendor_toolchain = metadata.get("vendor_toolchain", "")
        targets[board] = BoardTarget(
            board=board,
            display_name=metadata.get("display_name", board),
            family_key=_family_key_for_platform(platform),
            default_backend=vendor_toolchain or platform or "yosys",
            allowed_toolchains=tuple(metadata.get("supported_toolchains", [vendor_toolchain or platform or "yosys"])),
            related_name=board,
            tmds_project=paths.get("project"),
            blinky_project=paths.get("blinky_project"),
            tmds_root=_project_root_for_path(paths.get("project")) or _project_root_for_path(paths.get("top")),
            blinky_root=_blinky_root_for_paths(paths),
        )
    return targets


BOARD_TARGETS: dict[str, BoardTarget] = _build_targets()
BOARDS_MANIFEST: dict = load_boards_manifest()


def list_targets() -> list[BoardTarget]:
    return list(BOARD_TARGETS.values())


def repo_path(relative_path: str) -> Path:
    return REPO_ROOT / relative_path


def get_board_target(board: str) -> BoardTarget:
    try:
        return BOARD_TARGETS[board]
    except KeyError as exc:
        valid = ", ".join(sorted(BOARD_TARGETS))
        raise ValueError(f"unknown board '{board}'. Valid boards: {valid}") from exc


def target_default_backend(board: str) -> str:
    return get_board_target(board).default_backend


def board_display_name(board: str) -> str:
    return get_board_target(board).display_name


def board_manifest_entry(board: str) -> dict:
    try:
        return BOARDS_MANIFEST["boards"][board]
    except KeyError as exc:
        valid = ", ".join(sorted(BOARD_TARGETS))
        raise ValueError(f"unknown board '{board}'. Valid boards: {valid}") from exc


def board_allowed_toolchains(board: str) -> tuple[str, ...]:
    return get_board_target(board).allowed_toolchains


def board_supports_toolchain(board: str, style: str) -> bool:
    return style in board_allowed_toolchains(board)
