from __future__ import annotations

from pathlib import Path

from .actions import ActionError
from .project_config import effective_project_config, load_project_config, project_config_path, save_project_config, update_project_config_for_context
from .targets import board_allowed_toolchains


def default_project_marker(base_path: Path) -> Path:
    return project_config_path(base_path)


def read_default_project(base_path: Path, board: str | None = None) -> Path | None:
    project_cfg = load_project_config(base_path)
    if board:
        project_cfg = effective_project_config(project_cfg, board)
    rel = project_cfg.get("project_file", "").strip() if isinstance(project_cfg.get("project_file"), str) else ""
    if not rel:
        return None
    project = (base_path / rel).resolve()
    if not project.exists():
        marker = default_project_marker(base_path)
        raise ActionError(f"default project listed in {marker} was not found: {project}")
    return project


def write_default_project(base_path: Path, project_file: Path, force: bool = False, board: str | None = None) -> Path:
    marker = default_project_marker(base_path)
    rel = project_file.resolve().relative_to(base_path.resolve())
    config = load_project_config(base_path)
    effective = effective_project_config(config, board) if board else config
    if effective.get("project_file") and not force and effective["project_file"] != rel.as_posix():
        raise FileExistsError(f"{marker} already exists")
    if board:
        update_project_config_for_context(base_path, board, lambda target: target.__setitem__("project_file", rel.as_posix()))
    else:
        config["project_file"] = rel.as_posix()
        save_project_config(base_path, config)
    return marker


def _source_project_candidates(base_path: Path) -> list[Path]:
    candidates: list[Path] = []
    for candidate in (base_path / "top.v", base_path / "src" / "blinky.v"):
        if candidate.exists():
            candidates.append(candidate.resolve())
    return candidates


def discover_project_candidates(base_path: Path, board: str | None = None, toolchain: str | None = None) -> list[Path]:
    styles = [toolchain] if toolchain else list(board_allowed_toolchains(board)) if board else []
    if not styles:
        styles = ["gowin", "vivado", "yosys"]

    candidates: list[Path] = []
    for style in styles:
        if style == "gowin":
            for candidate in sorted(base_path.glob("*.gprj")):
                resolved = candidate.resolve()
                if resolved not in candidates:
                    candidates.append(resolved)
            platform_dir = base_path / "platform"
            if platform_dir.is_dir():
                for candidate in sorted(platform_dir.glob("*/*/*/*.gprj")):
                    resolved = candidate.resolve()
                    if resolved not in candidates:
                        candidates.append(resolved)
        else:
            for candidate in _source_project_candidates(base_path):
                if candidate not in candidates:
                    candidates.append(candidate)
    return candidates
