from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .actions import ActionError
from .project_discovery import discover_project_roots
from .project_resolver import resolve_project_context
from .targets import BOARD_TARGETS, ProjectContext


@dataclass(frozen=True)
class WorkspaceResolution:
    base_path: Path
    contexts: list[ProjectContext]


def infer_board_from_path(base_path: Path) -> str | None:
    text = str(base_path).lower()
    for board in BOARD_TARGETS:
        if board in text:
            return board
    return None


def resolve_workspace(base_path: Path, config: dict | None = None) -> WorkspaceResolution:
    direct_board = infer_board_from_path(base_path)
    contexts: list[ProjectContext] = []

    if direct_board:
        try:
            contexts.append(resolve_project_context(direct_board, str(base_path), config=config))
            return WorkspaceResolution(base_path=base_path, contexts=contexts)
        except Exception:
            pass

    for discovered in discover_project_roots(base_path):
        if not discovered.board:
            continue
        try:
            contexts.append(resolve_project_context(discovered.board, str(discovered.root), config=config))
        except Exception:
            continue

    unique: dict[tuple[str, str, str], ProjectContext] = {}
    for context in contexts:
        unique[(str(context.base_path), context.board, context.design)] = context

    return WorkspaceResolution(base_path=base_path, contexts=sorted(unique.values(), key=lambda item: (str(item.base_path), item.board, item.design)))


def resolve_single_project_for_cli(base_path: Path, config: dict | None = None) -> ProjectContext:
    workspace = resolve_workspace(base_path, config=config)
    if len(workspace.contexts) == 1:
        return workspace.contexts[0]
    if not workspace.contexts:
        raise ActionError(f"{base_path} is not a recognizable project or workspace")
    descriptions = "\n".join(f"  - {ctx.board} {ctx.design} @ {ctx.base_path}" for ctx in workspace.contexts)
    raise ActionError(f"{base_path} contains multiple project contexts; choose a more specific path:\n{descriptions}")
