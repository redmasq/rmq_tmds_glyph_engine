from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .paths import REPO_ROOT
from .targets import BOARD_TARGETS, repo_path


@dataclass(frozen=True)
class DiscoveredProject:
    root: Path
    board: str | None
    design: str | None
    project_file: Path | None


def _guess_board(path: Path) -> str | None:
    parts = "/".join(path.parts)
    for board in BOARD_TARGETS:
        if board in parts:
            return board
    return None


def _guess_design(path: Path) -> str | None:
    parts = "/".join(path.parts).lower()
    if "blinky" in parts or "bringup" in parts:
        return "blinky"
    if "boards" in parts or "platform" in parts:
        return "tmds"
    return None


def discover_project_roots(base_path: Path | None = None) -> list[DiscoveredProject]:
    root = (base_path or REPO_ROOT).resolve()
    candidates: dict[Path, DiscoveredProject] = {}

    for board in BOARD_TARGETS.values():
        for relative_root, design in ((board.tmds_root, "tmds"), (board.blinky_root, "blinky")):
            if not relative_root:
                continue
            candidate = repo_path(relative_root).resolve()
            if candidate.is_dir() and (candidate == root or root in candidate.parents or candidate in root.parents):
                candidates[candidate] = DiscoveredProject(
                    root=candidate,
                    board=board.board,
                    design=design,
                    project_file=None,
                )

    for marker in root.rglob("default.project.toml"):
        project_root = marker.parent.resolve()
        candidates[project_root] = DiscoveredProject(
            root=project_root,
            board=_guess_board(project_root),
            design=_guess_design(project_root),
            project_file=None,
        )

    for project_file in root.rglob("*.gprj"):
        project_root = project_file.parent.resolve()
        candidates[project_root] = DiscoveredProject(
            root=project_root,
            board=_guess_board(project_root),
            design=_guess_design(project_root),
            project_file=project_file.resolve(),
        )

    special_candidates = {root}
    for board in BOARD_TARGETS.values():
        if board.tmds_root:
            special_candidates.add(repo_path(board.tmds_root).resolve())
        if board.blinky_root:
            special_candidates.add(repo_path(board.blinky_root).resolve())

    for special in special_candidates:
        if special.is_dir():
            resolved = special.resolve()
            candidates[resolved] = DiscoveredProject(
                root=resolved,
                board=_guess_board(special),
                design=_guess_design(special),
                project_file=None,
            )

    return sorted(candidates.values(), key=lambda item: str(item.root))
