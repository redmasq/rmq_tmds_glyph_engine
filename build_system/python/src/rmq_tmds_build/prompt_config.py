from __future__ import annotations

from pathlib import Path

from .config import TOOLCHAIN_STYLES, load_config, save_config, toolchain_config
from .default_project import default_project_marker, discover_project_candidates, read_default_project, write_default_project
from .paths import REPO_ROOT
from .project_config import effective_project_config, load_project_config, save_project_config, update_project_config_for_context
from .project_discovery import discover_project_roots
from .project_resolver import resolve_project_context
from .project_workspace import resolve_workspace
from .targets import BOARD_TARGETS, board_allowed_toolchains, board_display_name
from .validation import validate_context_toolchain


def _ask_choice(prompt: str, options: list[str], default: int = 1) -> int:
    while True:
        print(prompt)
        for index, option in enumerate(options, start=1):
            marker = " (default)" if index == default else ""
            print(f"  {index}. {option}{marker}")
        raw = input("> ").strip()
        if not raw:
            return default
        if raw.isdigit():
            value = int(raw)
            if 1 <= value <= len(options):
                return value
        print("Invalid selection.")


def _ask_text(prompt: str, default: str = "") -> str:
    suffix = f" [{default}]" if default else ""
    raw = input(f"{prompt}{suffix}: ").strip()
    return raw if raw else default


def _print_global_summary(config: dict) -> None:
    prefs = config["global"]["toolchain_preferences"]
    print("Global configuration")
    print(f"  Gowin-family preferred toolchain: {prefs.get('gowin_family', 'gowin')}")
    print(f"  Artix-family preferred toolchain: {prefs.get('artix_family', 'vivado')}")
    for style in TOOLCHAIN_STYLES:
        section = toolchain_config(config, style)
        print(f"  {style}: auto_detect={section.get('auto_detect', True)} base_path={section.get('base_path', '') or '(unset)'}")
        for key, value in sorted(section.get("executables", {}).items()):
            print(f"    {key}: {value or '(auto/unset)'}")


def _edit_toolchain_style(config: dict, style: str) -> None:
    section = toolchain_config(config, style)
    while True:
        executables = section.get("executables", {})
        options = [
            f"Toggle auto_detect (currently {section.get('auto_detect', True)})",
            f"Set base path (currently {section.get('base_path', '') or '(unset)'})",
        ]
        exec_keys = sorted(executables)
        options.extend(f"Set executable override: {key} [{executables.get(key) or '(auto/unset)'}]" for key in exec_keys)
        if "device_pattern" in section:
            options.append(f"Set device pattern [{section.get('device_pattern') or '(unset)'}]")
        options.extend(["Save global config", "Back"])
        choice = _ask_choice(f"{style} toolchain:", options)
        if choice == 1:
            section["auto_detect"] = not section.get("auto_detect", True)
            continue
        if choice == 2:
            section["base_path"] = _ask_text("Base path", section.get("base_path", ""))
            continue

        offset = 3
        if choice < offset + len(exec_keys):
            key = exec_keys[choice - offset]
            executables[key] = _ask_text(f"Executable override for {key}", executables.get(key, ""))
            continue

        tail = choice - (offset + len(exec_keys))
        if "device_pattern" in section:
            if tail == 0:
                section["device_pattern"] = _ask_text("Device pattern", section.get("device_pattern", ""))
                continue
            tail -= 1
        if tail == 0:
            save_config(config)
            print("Saved global config.")
            continue
        return


def _edit_global_config(config: dict) -> None:
    prefs = config["global"]["toolchain_preferences"]
    while True:
        _print_global_summary(config)
        choice = _ask_choice(
            "Global configuration menu:",
            [
                f"Set Gowin-family preferred toolchain [{prefs.get('gowin_family', 'gowin')}]",
                f"Set Artix-family preferred toolchain [{prefs.get('artix_family', 'vivado')}]",
                "Configure yosys toolchain",
                "Configure gowin toolchain",
                "Configure vivado toolchain",
                "Choose project to edit",
                "Save global config",
                "Back",
            ],
        )
        if choice == 1:
            prefs["gowin_family"] = TOOLCHAIN_STYLES[_ask_choice("Preferred toolchain:", list(TOOLCHAIN_STYLES)) - 1]
        elif choice == 2:
            prefs["artix_family"] = TOOLCHAIN_STYLES[_ask_choice("Preferred toolchain:", list(TOOLCHAIN_STYLES)) - 1]
        elif choice == 3:
            _edit_toolchain_style(config, "yosys")
        elif choice == 4:
            _edit_toolchain_style(config, "gowin")
        elif choice == 5:
            _edit_toolchain_style(config, "vivado")
        elif choice == 6:
            _edit_project_config(config)
        elif choice == 7:
            save_config(config)
            print("Saved global config.")
        else:
            return


def _pick_project_context(config: dict) -> tuple[Path, str] | None:
    discovered = ["."]
    for item in discover_project_roots(REPO_ROOT):
        rel = "." if item.root == REPO_ROOT else str(item.root.relative_to(REPO_ROOT))
        if rel not in discovered:
            discovered.append(rel)
    print("Known project/workspace roots:")
    for item in discovered:
        print(f"  - {item}")
    while True:
        selected = _ask_text("Project or workspace path", ".")
        base_path = REPO_ROOT if selected == "." else (REPO_ROOT / selected).resolve()
        try:
            workspace = resolve_workspace(base_path, config=config)
        except Exception as exc:
            print(f"Error: {exc}")
            continue
        if not workspace.contexts:
            print(f"Error: {base_path} is not a recognizable project or workspace.")
            continue
        if len(workspace.contexts) == 1:
            context = workspace.contexts[0]
            return context.base_path, context.board
        options = [f"{board_display_name(ctx.board)} | {ctx.design} | {ctx.base_path.relative_to(REPO_ROOT)}" for ctx in workspace.contexts]
        index = _ask_choice("Choose a project context:", options)
        context = workspace.contexts[index - 1]
        return context.base_path, context.board


def _project_file_candidates(base_path: Path, board: str, toolchain: str) -> list[str]:
    candidates = []
    for candidate in discover_project_candidates(base_path, board=board, toolchain=toolchain):
        candidates.append(candidate.resolve().relative_to(base_path.resolve()).as_posix())
    return candidates


def _print_project_summary(base_path: Path, board: str, context, project_cfg: dict, warnings: list[str]) -> None:
    default_project = read_default_project(base_path, board)
    effective_cfg = effective_project_config(project_cfg, board)
    print("Project configuration")
    print(f"  Root: {base_path.relative_to(REPO_ROOT) if base_path != REPO_ROOT else '.'}")
    print(f"  Board: {board_display_name(board)} ({board})")
    print(f"  Resolved design: {context.design}")
    print(f"  Resolved backend: {context.backend}")
    print(f"  Allowed toolchains: {', '.join(board_allowed_toolchains(board))}")
    print(f"  Resolved project file: {context.project_file or '(none)'}")
    print(f"  Preferred toolchain: {effective_cfg.get('preferred_toolchain') or '(default)'}")
    print(f"  Project file override: {effective_cfg.get('project_file') or '(default)'}")
    print(f"  default.project.toml project_file: {default_project.relative_to(base_path).as_posix() if default_project else '(unset)'}")
    if warnings:
        print("  Toolchain warnings:")
        for warning in warnings:
            print(f"    - {warning}")


def _edit_project_config(config: dict, initial_base_path: Path | None = None, initial_board: str | None = None) -> None:
    selected = (initial_base_path, initial_board) if initial_base_path and initial_board else _pick_project_context(config)
    if selected is None:
        return
    base_path, board = selected
    while True:
        project_cfg = load_project_config(base_path)
        context = resolve_project_context(board, str(base_path), config=config)
        warnings = validate_context_toolchain(context, config)
        _print_project_summary(base_path, board, context, project_cfg, warnings)
        choice = _ask_choice(
            "Project configuration menu:",
            [
                "Set project file mode/value",
                "Write default.project.toml from current resolved project",
                "Set project toolchain backend",
                "Validate configured toolchain",
                "Save project config",
                "Choose another project",
                "Back",
            ],
        )
        if choice == 1:
            effective_cfg = effective_project_config(project_cfg, board)
            active_toolchain = effective_cfg.get("preferred_toolchain") or context.backend
            candidates = _project_file_candidates(base_path, board, active_toolchain)
            options = ["Use detected/default"]
            options.extend(f"Use override: {candidate}" for candidate in candidates)
            options.append("Type relative path manually")
            project_choice = _ask_choice("Project file selection:", options)
            if project_choice == 1:
                update_project_config_for_context(base_path, board, lambda target: target.__setitem__("project_file", ""))
            elif project_choice == len(options):
                value = _ask_text("Project file relative path", effective_cfg.get("project_file", ""))
                update_project_config_for_context(base_path, board, lambda target, value=value: target.__setitem__("project_file", value))
            else:
                value = candidates[project_choice - 2]
                update_project_config_for_context(base_path, board, lambda target, value=value: target.__setitem__("project_file", value))
        elif choice == 2:
            resolved_context = resolve_project_context(board, str(base_path), config=config)
            if resolved_context.project_file is None:
                print("No resolved project file is available to write into default.project.toml.")
            else:
                write_default_project(base_path, resolved_context.project_file, force=True, board=board)
                print(f"Wrote {default_project_marker(base_path)}.")
        elif choice == 3:
            style_options = ["Use default"] + list(board_allowed_toolchains(board))
            style_choice = _ask_choice("Toolchain selection:", style_options)
            if style_choice == 1:
                update_project_config_for_context(base_path, board, lambda target: target.__setitem__("preferred_toolchain", ""))
            else:
                value = style_options[style_choice - 1]
                update_project_config_for_context(base_path, board, lambda target, value=value: target.__setitem__("preferred_toolchain", value))
        elif choice == 4:
            if warnings:
                print("Toolchain warnings:")
                for warning in warnings:
                    print(f"  - {warning}")
            else:
                print("Toolchain validation succeeded.")
        elif choice == 5:
            save_project_config(base_path, project_cfg)
            print(f"Saved project config in {base_path}.")
        elif choice == 6:
            next_selected = _pick_project_context(config)
            if next_selected is not None:
                base_path, board = next_selected
        else:
            return


def run_prompt_config() -> int:
    config = load_config()
    while True:
        choice = _ask_choice(
            "Configuration options:",
            [
                "Display current configuration",
                "Edit global configuration",
                "Edit project configuration",
                "Exit",
            ],
        )
        if choice == 1:
            _print_global_summary(config)
        elif choice == 2:
            _edit_global_config(config)
            config = load_config()
        elif choice == 3:
            _edit_project_config(config)
        else:
            return 0
