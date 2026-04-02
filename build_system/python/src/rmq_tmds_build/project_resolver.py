from __future__ import annotations

from pathlib import Path

from .actions import ActionError
from .config import normalize_config
from .default_project import read_default_project
from .paths import REPO_ROOT
from .project_config import effective_project_config, load_project_config
from .targets import ProjectContext, board_allowed_toolchains, board_supports_toolchain, get_board_target, repo_path


def _normalize_base_path(project_path: str | None) -> Path:
    if not project_path:
        return REPO_ROOT
    candidate = Path(project_path)
    if not candidate.is_absolute():
        candidate = (REPO_ROOT / candidate).resolve()
    if not candidate.exists():
        raise ActionError(f"project path does not exist: {candidate}")
    if not candidate.is_dir():
        raise ActionError(f"project path is not a directory: {candidate}")
    return candidate

def _single_project_in_dir(base_path: Path) -> Path | None:
    project_files = sorted(base_path.glob("*.gprj"))
    if len(project_files) == 1:
        return project_files[0].resolve()
    if len(project_files) > 1:
        raise ActionError(f"multiple .gprj files found in {base_path}; set project_file in default.project.toml to disambiguate")
    return None


def _artix_project_root(base_path: Path) -> Path | None:
    top = base_path / "top.v"
    xdcs = sorted(base_path.glob("*.xdc"))
    if top.exists() and xdcs:
        return top.resolve()

    bringup_top = base_path / "src" / "blinky.v"
    bringup_xdcs = sorted((base_path / "src").glob("*.xdc")) if (base_path / "src").is_dir() else []
    if bringup_top.exists() and bringup_xdcs:
        return bringup_top.resolve()
    return None


def _project_from_platform_layout(base_path: Path, related_name: str) -> Path | None:
    platform_dir = base_path / "platform"
    if not platform_dir.is_dir():
        return None
    candidates = sorted(platform_dir.glob(f"*/boards/{related_name}/*.gprj"))
    if len(candidates) == 1:
        return candidates[0].resolve()
    if len(candidates) > 1:
        raise ActionError(f"multiple board project files found for {related_name} under {platform_dir}")
    return None


def _project_from_board_layout(base_path: Path, related_name: str) -> Path | None:
    board_dir_candidates = [
        base_path / "platform" / "artix" / "boards" / related_name,
        base_path / "bringup" / f"blinky-{related_name}",
    ]
    for candidate in board_dir_candidates:
        project = _artix_project_root(candidate)
        if project is not None:
            return project
    return None


def _infer_design(base_path: Path, project_file: Path | None, board: str) -> str:
    haystacks = [part.lower() for part in base_path.parts]
    if project_file is not None:
        haystacks.append(project_file.name.lower())
        haystacks.extend(part.lower() for part in project_file.parent.parts)
    if "blinky" in " ".join(haystacks):
        return "blinky"
    if base_path == REPO_ROOT:
        return "tmds"
    if "bringup" in haystacks:
        return "blinky"
    return "tmds"


def _validate_project_file_for_toolchain(project_file: Path | None, backend: str) -> None:
    if project_file is None:
        return
    suffix = project_file.suffix.lower()
    if backend == "gowin" and suffix != ".gprj":
        raise ActionError(f"Gowin projects must use a .gprj project file, got: {project_file}")
    if backend in {"vivado", "yosys"} and suffix == ".gprj":
        raise ActionError(f"{backend} projects should use a source entry file rather than a .gprj project file: {project_file}")


def resolve_project_context(board: str, project_path: str | None, config: dict | None = None) -> ProjectContext:
    board_target = get_board_target(board)
    base_path = _normalize_base_path(project_path)
    raw_project_cfg = load_project_config(base_path)
    project_cfg = effective_project_config(raw_project_cfg, board)

    project_file = (
        _project_from_config(base_path, project_cfg)
        or read_default_project(base_path, board)
        or _single_project_in_dir(base_path)
        or _project_from_platform_layout(base_path, board_target.related_name)
        or _artix_project_root(base_path)
        or _project_from_board_layout(base_path, board_target.related_name)
    )
    design = _infer_design(base_path, project_file, board)
    backend = _default_backend_for_board(board, config)
    if project_cfg.get("preferred_toolchain"):
        backend = project_cfg["preferred_toolchain"]
    if not board_supports_toolchain(board, backend):
        allowed = ", ".join(board_allowed_toolchains(board))
        raise ActionError(f"{board} does not support toolchain '{backend}'. Allowed toolchains: {allowed}")
    _validate_project_file_for_toolchain(project_file, backend)

    if base_path == REPO_ROOT and project_file is None:
        default_project = board_target.blinky_project if design == "blinky" else board_target.tmds_project
        if default_project:
            project_file = repo_path(default_project)

    return ProjectContext(
        board=board,
        design=design,
        backend=backend,
        base_path=base_path,
        project_file=project_file,
        project_config=project_cfg,
    )


def _project_from_config(base_path: Path, project_cfg: dict) -> Path | None:
    rel = project_cfg.get("project_file", "").strip() if isinstance(project_cfg.get("project_file"), str) else ""
    if not rel:
        return None
    project = (base_path / rel).resolve()
    if not project.exists():
        raise ActionError(f"default.project.toml points to a missing project file: {project}")
    return project


def _default_backend_for_board(board: str, config: dict | None) -> str:
    board_target = get_board_target(board)
    if not config:
        return board_target.default_backend
    prefs = normalize_config(config)["global"]["toolchain_preferences"]
    preferred = prefs.get(board_target.family_key, board_target.default_backend)
    if preferred in board_target.allowed_toolchains:
        return preferred
    if board_target.default_backend in board_target.allowed_toolchains:
        return board_target.default_backend
    return board_target.allowed_toolchains[0]
