from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any, Callable

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python 3.10 fallback
    import tomli as tomllib

from .paths import REPO_ROOT


PROJECT_CONFIG_FILENAME = "default.project.toml"
LEGACY_PROJECT_CONFIG_FILENAME = "project.config.json"
TOOLCHAIN_STYLES = ("yosys", "gowin", "vivado")


def project_config_path(base_path: Path) -> Path:
    return base_path / PROJECT_CONFIG_FILENAME


def load_project_config(base_path: Path) -> dict[str, Any]:
    path = project_config_path(base_path)
    if path.exists():
        with path.open("rb") as handle:
            return normalize_project_config(tomllib.load(handle))
    legacy_path = base_path / LEGACY_PROJECT_CONFIG_FILENAME
    if legacy_path.exists():
        with legacy_path.open("r", encoding="utf-8") as handle:
            return normalize_project_config(json.load(handle))
    return normalize_project_config({})


def save_project_config(base_path: Path, config: dict[str, Any]) -> Path:
    path = project_config_path(base_path)
    path.write_text(_to_toml(normalize_project_config(config)), encoding="utf-8")
    return path


def normalize_project_config(config: dict[str, Any], *, allow_boards: bool = True) -> dict[str, Any]:
    normalized = dict(config)
    normalized.setdefault("project_file", "")
    if normalized.get("preferred_backend") and not normalized.get("preferred_toolchain"):
        normalized["preferred_toolchain"] = normalized["preferred_backend"]
    normalized.setdefault("preferred_toolchain", "")

    legacy_toolchain = normalized.pop("toolchain", {})
    if legacy_toolchain.get("mode") == "override" and legacy_toolchain.get("style") and not normalized["preferred_toolchain"]:
        normalized["preferred_toolchain"] = legacy_toolchain["style"]

    toolchains = normalized.setdefault("toolchains", {})
    for style in TOOLCHAIN_STYLES:
        section = toolchains.setdefault(style, {})
        section.setdefault("base_path", "")
        section.setdefault("executables", {})
        if style == "vivado":
            section.setdefault("device_pattern", "")

    if allow_boards:
        boards = normalized.setdefault("boards", {})
        normalized["boards"] = {
            board: normalize_project_config(board_cfg, allow_boards=False)
            for board, board_cfg in boards.items()
            if isinstance(board_cfg, dict)
        }
    else:
        normalized.pop("boards", None)

    normalized.pop("preferred_backend", None)
    return normalized


def effective_project_config(config: dict[str, Any], board: str) -> dict[str, Any]:
    normalized = normalize_project_config(config)
    effective = copy.deepcopy(normalized)
    effective.pop("boards", None)
    board_cfg = normalized.get("boards", {}).get(board, {})
    if board_cfg:
        for key in ("project_file", "preferred_toolchain"):
            if board_cfg.get(key):
                effective[key] = board_cfg[key]
        for style in TOOLCHAIN_STYLES:
            override = board_cfg.get("toolchains", {}).get(style, {})
            if override.get("base_path"):
                effective["toolchains"][style]["base_path"] = override["base_path"]
            for key, value in override.get("executables", {}).items():
                if value:
                    effective["toolchains"][style]["executables"][key] = value
            if override.get("device_pattern"):
                effective["toolchains"][style]["device_pattern"] = override["device_pattern"]
    return effective


def uses_board_sections(base_path: Path) -> bool:
    return base_path.resolve() == REPO_ROOT or (base_path / "platform").is_dir()


def update_project_config_for_context(base_path: Path, board: str, update: Callable[[dict[str, Any]], None]) -> dict[str, Any]:
    config = load_project_config(base_path)
    if uses_board_sections(base_path):
        target = config.setdefault("boards", {}).setdefault(board, normalize_project_config({}, allow_boards=False))
    else:
        target = config
    update(target)
    save_project_config(base_path, config)
    return config


def _toml_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def _toolchain_sections_to_toml(prefix: str, toolchains: dict[str, Any]) -> list[str]:
    lines: list[str] = []
    for style in TOOLCHAIN_STYLES:
        section = toolchains.get(style, {})
        lines.extend(
            [
                f"[{prefix}.{style}]",
                f"base_path = {_toml_quote(section.get('base_path', ''))}",
            ]
        )
        if "device_pattern" in section:
            lines.append(f"device_pattern = {_toml_quote(section.get('device_pattern', ''))}")
        lines.append("")
        lines.append(f"[{prefix}.{style}.executables]")
        for key, value in sorted(section.get("executables", {}).items()):
            lines.append(f"{key} = {_toml_quote(value)}")
        lines.append("")
    return lines


def _to_toml(config: dict[str, Any]) -> str:
    normalized = normalize_project_config(config)
    lines = [
        f"project_file = {_toml_quote(normalized.get('project_file', ''))}",
        f"preferred_toolchain = {_toml_quote(normalized.get('preferred_toolchain', ''))}",
        "",
    ]
    lines.extend(_toolchain_sections_to_toml("toolchains", normalized["toolchains"]))
    for board, board_cfg in sorted(normalized.get("boards", {}).items()):
        lines.extend(
            [
                f"[boards.{board}]",
                f"project_file = {_toml_quote(board_cfg.get('project_file', ''))}",
                f"preferred_toolchain = {_toml_quote(board_cfg.get('preferred_toolchain', ''))}",
                "",
            ]
        )
        lines.extend(_toolchain_sections_to_toml(f"boards.{board}.toolchains", board_cfg.get("toolchains", {})))
    return "\n".join(lines)
