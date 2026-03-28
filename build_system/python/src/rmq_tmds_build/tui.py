from __future__ import annotations

import argparse
import os
import pty
import threading
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable

from .actions import ActionError
from .config import TOOLCHAIN_STYLES, editor_config, load_config, save_config, toolchain_config
from .default_project import default_project_marker, discover_project_candidates, read_default_project, write_default_project
from .host import detect_host
from .paths import BUILD_SYSTEM_ROOT, REPO_ROOT
from .project_config import effective_project_config, load_project_config, save_project_config, update_project_config_for_context
from .project_discovery import discover_project_roots
from .project_resolver import resolve_project_context
from .project_workspace import resolve_workspace
from .targets import ProjectContext, board_allowed_toolchains, board_display_name
from .validation import validate_context_toolchain

KNOWN_TEXT_EDITORS = [
    ("nano", "nano", "{file}", "terminal"),
    ("joe", "joe", "{file}", "terminal"),
    ("vi", "vi", "{file}", "terminal"),
    ("vim", "vim", "{file}", "terminal"),
    ("emacs", "emacs", "{file}", "terminal"),
    ("gedit", "gedit", "{file}", "gui"),
    ("notepad", "notepad", "{file}", "gui"),
    ("notepad++", "notepad++", "{file}", "gui"),
    ("vscode", "code", "--wait {file}", "gui"),
    ("ed", "ed", "{file}", "terminal"),
]

KNOWN_HEX_VIEWERS = [
    ("xxd", "xxd", "{file}", "terminal"),
    ("hexdump", "hexdump", "-C {file}", "terminal"),
    ("od", "od", "-Ax -tx1z {file}", "terminal"),
]


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="rmq-tmds-build-tui")
    parser.add_argument("--mode", choices=("config", "project"), default="config")
    parser.add_argument("--project-path", default=".")
    parser.add_argument("--no-validate-toolchain", action="store_true")
    return parser


@dataclass
class MenuEntry:
    label: str
    action: Callable[[], None]
    detail: str = ""


@dataclass
class MenuState:
    title: str
    summary: list[str]
    entries: list[MenuEntry]
    footer: str = ""
    selected: int = 0


@dataclass
class InputState:
    title: str
    prompt: str
    initial: str
    on_submit: Callable[[str], None]
    on_cancel: Callable[[], None] | None = None


@dataclass
class DialogState:
    title: str
    lines: list[str]
    on_close: Callable[[], None] | None = None


@dataclass
class BrowserState:
    title: str
    current_path: Path
    select_mode: str
    on_select: Callable[[Path], None]
    on_cancel: Callable[[], None] | None = None
    selected: int = 0
    selected_entry: Path | None = None


def _repo_relative(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(REPO_ROOT))
    except ValueError:
        return str(path.resolve())


def _choice_labels(root: Path) -> list[str]:
    choices = ["."]
    for item in discover_project_roots(REPO_ROOT):
        label = _repo_relative(item.root)
        if label not in choices:
            choices.append(label)
    if _repo_relative(root) not in choices:
        choices.append(_repo_relative(root))
    return choices


def _project_file_candidates(base_path: Path, board: str, toolchain: str) -> list[str]:
    candidates: list[str] = []
    for candidate in discover_project_candidates(base_path, board=board, toolchain=toolchain):
        rel = candidate.relative_to(base_path.resolve()).as_posix()
        if rel not in candidates:
            candidates.append(rel)
    return candidates


def _toolchain_probe(style: str, candidate: Path) -> list[str]:
    hints: list[str] = []
    if not candidate.exists():
        return ["path does not exist"]
    if style == "gowin":
        ide_bin = candidate / "IDE" / "bin"
        prog_bin = candidate / "Programmer" / "bin"
        found = []
        for probe in (ide_bin / "gw_sh", ide_bin / "gw_sh.exe", ide_bin / "gw_ide", ide_bin / "gw_ide.exe", prog_bin / "programmer_cli", prog_bin / "programmer_cli.exe"):
            if probe.exists():
                found.append(probe.relative_to(candidate).as_posix())
        if found:
            hints.append("looks like a Gowin install")
            hints.extend(f"found {item}" for item in found[:6])
        else:
            hints.append("no obvious Gowin IDE/programmer layout found")
        return hints
    if style == "vivado":
        found = []
        for probe in (candidate / "bin" / "vivado", candidate / "bin" / "vivado.bat", candidate / "settings64.sh"):
            if probe.exists():
                found.append(probe.relative_to(candidate).as_posix())
        if found:
            hints.append("looks like a Vivado install")
            hints.extend(f"found {item}" for item in found[:6])
        else:
            hints.append("no obvious Vivado install layout found")
        return hints
    if style == "yosys":
        names = {"yosys", "yosys.exe", "nextpnr-gowin", "nextpnr-gowin.exe", "nextpnr-xilinx", "nextpnr-xilinx.exe", "gowin_pack", "gowin_pack.exe", "openFPGALoader", "openFPGALoader.exe"}
        found: list[str] = []
        for probe_root in (candidate, candidate / "bin"):
            if probe_root.is_dir():
                for entry in sorted(probe_root.iterdir()):
                    if entry.name in names:
                        found.append(entry.relative_to(candidate).as_posix())
        if found:
            hints.append("tool-like executables detected")
            hints.extend(f"found {item}" for item in found[:8])
        else:
            hints.append("no obvious yosys-family executables found here")
        return hints
    return ["no toolchain probe available"]


def _project_probe(candidate: Path) -> list[str]:
    if not candidate.exists():
        return ["path does not exist"]
    hints = []
    try:
        workspace = resolve_workspace(candidate)
    except Exception as exc:
        return [str(exc)]
    if not workspace.contexts:
        return ["not recognized as a project/workspace"]
    if len(workspace.contexts) == 1:
        context = workspace.contexts[0]
        hints.append(f"single project: {board_display_name(context.board)} {context.design}")
        hints.append(f"root: {_repo_relative(context.base_path)}")
    else:
        hints.append(f"workspace with {len(workspace.contexts)} project contexts")
        for context in workspace.contexts[:6]:
            hints.append(f"{board_display_name(context.board)} {context.design} @ {_repo_relative(context.base_path)}")
    return hints


def _directory_entries(current_path: Path) -> list[Path]:
    try:
        children = sorted(current_path.iterdir(), key=lambda item: (not item.is_dir(), item.name.lower()))
    except OSError:
        return []
    entries: list[Path] = []
    if current_path.parent != current_path:
        entries.append(current_path.parent)
    entries.extend(children)
    return entries


def main(argv: list[str] | None = None) -> int:
    try:
        from rich.text import Text
        from textual.app import App, ComposeResult
        from textual.containers import Vertical
        from textual.events import Key
        from textual.widgets import Footer, Header, Input, RichLog, Static
    except ModuleNotFoundError as exc:
        raise ModuleNotFoundError("Textual is not installed. Create the venv and install the [tui] extra first.") from exc

    args = make_parser().parse_args(argv)
    host = detect_host()

    class BuildSystemApp(App[None]):
        TITLE = "rmq_tmds_build"

        def __init__(self) -> None:
            super().__init__()
            self.config = load_config()
            self.start_mode = args.mode
            project_path = Path(args.project_path)
            if not project_path.is_absolute():
                project_path = (REPO_ROOT / project_path).resolve()
            self.start_project_path = project_path
            self.no_validate_toolchain = args.no_validate_toolchain
            self.menu_stack: list[MenuState] = []
            self.dialog: DialogState | None = None
            self.input_state: InputState | None = None
            self.browser_state: BrowserState | None = None
            self.current_context: ProjectContext | None = None
            self.status_text = ""
            self.output_lines: list[str] = []
            self.output_visible = False
            self.output_title = "Execution Output"
            self.action_running = False

        def compose(self) -> ComposeResult:
            yield Header()
            with Vertical():
                yield Static("", id="body")
                yield RichLog(id="log", wrap=False, highlight=False, markup=False)
                yield Input(placeholder="", id="input")
                yield Static("", id="status")
            yield Footer()

        def on_mount(self) -> None:
            input_widget = self.query_one("#input", Input)
            input_widget.display = False
            log_widget = self.query_one("#log", RichLog)
            log_widget.display = False
            if self.start_mode == "config":
                if args.project_path != ".":
                    self._open_project_config(self._resolve_project_for_cli(self.start_project_path), return_to_project=False)
                else:
                    self._open_global_menu()
            else:
                if args.project_path != ".":
                    self._open_project_menu(self._resolve_project_for_cli(self.start_project_path), validate=not self.no_validate_toolchain)
                else:
                    self._open_project_selector("project")
            self._refresh()

        def _resolve_project_for_cli(self, base_path: Path) -> ProjectContext:
            workspace = resolve_workspace(base_path, config=self.config)
            if not workspace.contexts:
                raise ActionError(f"{base_path} is not a recognizable project or workspace")
            if len(workspace.contexts) != 1:
                raise ActionError(f"{base_path} contains multiple project contexts; use a more specific path")
            return workspace.contexts[0]

        def _set_menu(self, menu: MenuState) -> None:
            self.menu_stack = [menu]
            self._refresh()

        def _push_menu(self, menu: MenuState) -> None:
            self.menu_stack.append(menu)
            self._refresh()

        def _replace_menu(self, menu: MenuState) -> None:
            self.menu_stack[-1] = menu
            self._refresh()

        def _pop_menu(self) -> None:
            if len(self.menu_stack) > 1:
                self.menu_stack.pop()
                self.status_text = ""
                self._refresh()
            else:
                self.exit()

        def _show_dialog(self, title: str, lines: list[str], on_close: Callable[[], None] | None = None) -> None:
            self.dialog = DialogState(title=title, lines=lines, on_close=on_close)
            self._refresh()

        def _dismiss_dialog(self) -> None:
            dialog = self.dialog
            self.dialog = None
            if dialog and dialog.on_close:
                dialog.on_close()
            self._refresh()

        def _prompt(self, title: str, prompt: str, initial: str, on_submit: Callable[[str], None], on_cancel: Callable[[], None] | None = None) -> None:
            self.input_state = InputState(title=title, prompt=prompt, initial=initial, on_submit=on_submit, on_cancel=on_cancel)
            input_widget = self.query_one("#input", Input)
            input_widget.display = True
            input_widget.value = initial
            input_widget.placeholder = prompt
            input_widget.focus()
            self._refresh()

        def _cancel_prompt(self) -> None:
            if self.input_state and self.input_state.on_cancel:
                self.input_state.on_cancel()
            self.input_state = None
            input_widget = self.query_one("#input", Input)
            input_widget.display = False
            self._refresh()

        def _submit_prompt(self, value: str) -> None:
            input_state = self.input_state
            self.input_state = None
            input_widget = self.query_one("#input", Input)
            input_widget.display = False
            if input_state:
                input_state.on_submit(value.strip())
            self._refresh()

        def _render_menu(self) -> str:
            if self.browser_state:
                return self._render_browser()
            if self.dialog:
                lines = [self.dialog.title, "", *self.dialog.lines, "", "[ Enter ] OK"]
                return "\n".join(lines)

            menu = self.menu_stack[-1]
            lines = [menu.title, ""]
            lines.extend(menu.summary)
            if menu.summary:
                lines.append("")
            for index, entry in enumerate(menu.entries):
                marker = ">" if index == menu.selected else " "
                detail = f"  {entry.detail}" if entry.detail else ""
                lines.append(f"{marker} {index + 1}. {entry.label}{detail}")
            if self.input_state:
                lines.extend(["", self.input_state.title, self.input_state.prompt])
            if menu.footer:
                lines.extend(["", menu.footer])
            return "\n".join(lines)

        def _render_browser(self) -> str:
            browser = self.browser_state
            assert browser is not None
            entries = _directory_entries(browser.current_path)
            lines = [browser.title, "", f"Current path: {browser.current_path}", ""]
            probe_lines = self._browser_probe_lines(browser)
            lines.extend(probe_lines)
            if probe_lines:
                lines.append("")
            for index, entry in enumerate(entries):
                marker = ">" if index == browser.selected else " "
                if index == 0 and entry == browser.current_path.parent and browser.current_path.parent != browser.current_path:
                    label = ".."
                    detail = "parent"
                else:
                    label = entry.name + ("/" if entry.is_dir() else "")
                    detail = self._browser_entry_detail(browser, entry)
                lines.append(f"{marker} {index + 1}. {label}{('  ' + detail) if detail else ''}")
            lines.extend(
                [
                    "",
                    "Enter opens/selects. S selects current directory. E opens text editor for a file. H opens hex viewer for a file. Esc cancels.",
                ]
            )
            return "\n".join(lines)

        def _refresh(self) -> None:
            body = self.query_one("#body", Static)
            log = self.query_one("#log", RichLog)
            if self.output_visible:
                body.display = False
                log.display = True
                log.focus()
                if not getattr(log, "_rmq_tmds_loaded", False):
                    log.clear()
                    for line in self.output_lines:
                        log.write(line)
                    setattr(log, "_rmq_tmds_loaded", True)
            else:
                body.display = True
                log.display = False
                setattr(log, "_rmq_tmds_loaded", False)
                body.update(Text(self._render_menu(), no_wrap=True))
            self.query_one("#status", Static).update(Text(self.status_text, no_wrap=True))

        def _browser_probe_lines(self, browser: BrowserState) -> list[str]:
            if browser.select_mode.startswith("toolchain-base:"):
                style = browser.select_mode.split(":", 1)[1]
                return _toolchain_probe(style, browser.current_path)
            if browser.select_mode.startswith("toolchain-exec:"):
                style = browser.select_mode.split(":", 1)[1]
                return _toolchain_probe(style, browser.current_path.parent if browser.current_path.is_file() else browser.current_path)
            if browser.select_mode == "project-root":
                return _project_probe(browser.current_path)
            return []

        def _browser_entry_detail(self, browser: BrowserState, entry: Path) -> str:
            if entry.is_dir():
                return "dir"
            if browser.select_mode.startswith("toolchain-exec:"):
                style = browser.select_mode.split(":", 1)[1]
                name = entry.name.lower()
                if style == "gowin" and ("gw_" in name or "programmer" in name):
                    return "candidate executable"
                if style == "vivado" and "vivado" in name:
                    return "candidate executable"
                if style == "yosys" and any(token in name for token in ("yosys", "nextpnr", "gowin_pack", "openfpgaloader")):
                    return "candidate executable"
            return "file"

        def _global_summary(self) -> list[str]:
            prefs = self.config["global"]["toolchain_preferences"]
            lines = [
                f"Host mode: {host.mode_name}",
                f"Gowin-family toolchain: {prefs.get('gowin_family', 'gowin')}",
                f"Artix-family toolchain: {prefs.get('artix_family', 'vivado')}",
            ]
            for style in TOOLCHAIN_STYLES:
                section = toolchain_config(self.config, style)
                lines.append(f"{style}: auto_detect={section.get('auto_detect', True)} base_path={section.get('base_path', '') or '(unset)'}")
            text_editor = editor_config(self.config, "text")
            hex_editor = editor_config(self.config, "hex")
            lines.append(f"text editor: {text_editor.get('command') or os.environ.get(text_editor.get('env_var', ''), '(env/default)')}")
            lines.append(f"hex viewer: {hex_editor.get('command') or os.environ.get(hex_editor.get('env_var', ''), '(env/default)')}")
            return lines

        def _open_global_menu(self) -> None:
            prefs = self.config["global"]["toolchain_preferences"]
            self._set_menu(
                MenuState(
                    title="Global Configuration",
                    summary=self._global_summary(),
                    footer="Enter selects. Esc backs out. Use Configure Toolchain to edit paths and overrides.",
                    entries=[
                        MenuEntry(
                            f"Set Gowin-family preferred toolchain [{prefs.get('gowin_family', 'gowin')}]",
                            lambda: self._open_toolchain_preference_menu("gowin_family", "Gowin-family"),
                        ),
                        MenuEntry(
                            f"Set Artix-family preferred toolchain [{prefs.get('artix_family', 'vivado')}]",
                            lambda: self._open_toolchain_preference_menu("artix_family", "Artix-family"),
                        ),
                        MenuEntry("Configure yosys toolchain", lambda: self._open_toolchain_menu("yosys")),
                        MenuEntry("Configure gowin toolchain", lambda: self._open_toolchain_menu("gowin")),
                        MenuEntry("Configure vivado toolchain", lambda: self._open_toolchain_menu("vivado")),
                        MenuEntry("Configure text editor", lambda: self._open_editor_menu("text")),
                        MenuEntry("Configure hex viewer", lambda: self._open_editor_menu("hex")),
                        MenuEntry("Browse Modified Files", self._open_modified_files_menu),
                        MenuEntry("Choose Project To Edit", lambda: self._open_project_selector("config")),
                        MenuEntry("Save Global Configuration", self._save_global_config),
                        MenuEntry("Exit", self.exit),
                    ],
                )
            )

        def _open_editor_menu(self, kind: str) -> None:
            cfg = editor_config(self.config, kind)
            entries = [
                MenuEntry("Choose detected preset", lambda: self._open_editor_presets(kind)),
                MenuEntry(
                    f"Set command [{cfg.get('command') or '(env/default)'}]",
                    lambda: self._prompt_editor_field(kind, "command", "Editor command"),
                ),
                MenuEntry(
                    f"Set args template [{cfg.get('args_template', '{file}')}]", 
                    lambda: self._prompt_editor_field(kind, "args_template", "Args template"),
                ),
                MenuEntry(
                    f"Set env var [{cfg.get('env_var', '')}]",
                    lambda: self._prompt_editor_field(kind, "env_var", "Environment variable override"),
                ),
                MenuEntry(
                    f"Set launch mode [{cfg.get('launch_mode', 'terminal')}]",
                    lambda: self._open_editor_launch_mode_menu(kind),
                ),
                MenuEntry("Save Global Configuration", self._save_global_config),
                MenuEntry("Back", self._pop_menu),
            ]
            self._push_menu(
                MenuState(
                    title=f"{kind.capitalize()} Editor",
                    summary=[
                        f"Command: {cfg.get('command') or '(env/default)'}",
                        f"Args template: {cfg.get('args_template', '{file}')}",
                        f"Env var: {cfg.get('env_var', '')}",
                        f"Launch mode: {cfg.get('launch_mode', 'terminal')}",
                    ],
                    entries=entries,
                )
            )

        def _open_editor_presets(self, kind: str) -> None:
            presets = KNOWN_TEXT_EDITORS if kind == "text" else KNOWN_HEX_VIEWERS
            entries = []
            for label, command, args_template, launch_mode in presets:
                if shutil.which(command):
                    entries.append(
                        MenuEntry(
                            f"Use {label}",
                            lambda command=command, args_template=args_template, launch_mode=launch_mode: self._set_editor_preset(
                                kind, command, args_template, launch_mode
                            ),
                        )
                    )
            if not entries:
                entries.append(MenuEntry("No known presets detected on PATH", self._pop_menu))
            entries.append(MenuEntry("Back", self._pop_menu))
            self._push_menu(MenuState(title=f"{kind.capitalize()} Editor Presets", summary=["Detected editor commands on PATH."], entries=entries))

        def _set_editor_preset(self, kind: str, command: str, args_template: str, launch_mode: str) -> None:
            cfg = editor_config(self.config, kind)
            cfg["command"] = command
            cfg["args_template"] = args_template
            cfg["launch_mode"] = launch_mode
            self.status_text = f"Configured {kind} editor preset: {command}"
            self._open_editor_menu(kind)

        def _prompt_editor_field(self, kind: str, field_name: str, label: str) -> None:
            cfg = editor_config(self.config, kind)
            self._prompt(
                f"{kind.capitalize()} Editor",
                label,
                cfg.get(field_name, ""),
                lambda value: self._set_editor_field(kind, field_name, value),
            )

        def _set_editor_field(self, kind: str, field_name: str, value: str) -> None:
            cfg = editor_config(self.config, kind)
            cfg[field_name] = value
            self.status_text = f"Updated {kind} editor {field_name}."
            self._open_editor_menu(kind)

        def _open_editor_launch_mode_menu(self, kind: str) -> None:
            self._push_menu(
                MenuState(
                    title=f"{kind.capitalize()} Editor Launch Mode",
                    summary=["Choose how the editor should be launched."],
                    entries=[
                        MenuEntry("terminal", lambda: self._set_editor_field(kind, "launch_mode", "terminal")),
                        MenuEntry("gui", lambda: self._set_editor_field(kind, "launch_mode", "gui")),
                        MenuEntry("Back", self._pop_menu),
                    ],
                )
            )

        def _open_toolchain_preference_menu(self, family_key: str, label: str) -> None:
            entries = []
            for style in TOOLCHAIN_STYLES:
                entries.append(
                    MenuEntry(
                        f"Use {style}",
                        lambda style=style: self._set_toolchain_preference(family_key, style),
                    )
                )
            entries.append(MenuEntry("Back", self._pop_menu))
            self._push_menu(
                MenuState(
                    title=f"{label} Preferred Toolchain",
                    summary=[f"Current value: {self.config['global']['toolchain_preferences'].get(family_key, '') or '(unset)'}"],
                    entries=entries,
                )
            )

        def _set_toolchain_preference(self, family_key: str, style: str) -> None:
            self.config["global"]["toolchain_preferences"][family_key] = style
            self.status_text = f"Set {family_key} to {style}."
            self._pop_menu()

        def _open_toolchain_menu(self, style: str) -> None:
            section = toolchain_config(self.config, style)
            entries = [
                MenuEntry(
                    f"Toggle auto_detect [{section.get('auto_detect', True)}]",
                    lambda: self._toggle_toolchain_autodetect(style),
                ),
                MenuEntry(
                    f"Set base path [{section.get('base_path', '') or '(unset)'}]",
                    lambda: self._prompt_toolchain_field(style, "base_path", "Base path"),
                ),
                MenuEntry(
                    "Browse for base path",
                    lambda: self._open_browser(
                        title=f"{style} Toolchain Browser",
                        start_path=Path(section.get("base_path") or REPO_ROOT),
                        select_mode=f"toolchain-base:{style}",
                        on_select=lambda path: self._set_toolchain_field(style, "base_path", str(path)),
                    ),
                ),
            ]
            for key, value in sorted(section.get("executables", {}).items()):
                entries.append(
                    MenuEntry(
                        f"Set executable override: {key} [{value or '(auto/unset)'}]",
                        lambda key=key: self._prompt_toolchain_executable(style, key),
                    )
                )
                entries.append(
                    MenuEntry(
                        f"Browse for executable: {key}",
                        lambda key=key, value=value: self._open_browser(
                            title=f"{style} Executable Browser",
                            start_path=Path(value).parent if value else Path(section.get("base_path") or REPO_ROOT),
                            select_mode=f"toolchain-exec:{style}",
                            on_select=lambda path, key=key: self._set_toolchain_executable(style, key, str(path)),
                        ),
                    )
                )
            if "device_pattern" in section:
                entries.append(
                    MenuEntry(
                        f"Set device pattern [{section.get('device_pattern') or '(unset)'}]",
                        lambda: self._prompt_toolchain_field(style, "device_pattern", "Vivado device pattern"),
                    )
                )
            entries.extend([MenuEntry("Save Global Configuration", self._save_global_config), MenuEntry("Back", self._pop_menu)])
            self._push_menu(
                MenuState(
                    title=f"{style} Toolchain",
                    summary=[f"auto_detect={section.get('auto_detect', True)}", f"base_path={section.get('base_path', '') or '(unset)'}"],
                    entries=entries,
                )
            )

        def _toggle_toolchain_autodetect(self, style: str) -> None:
            section = toolchain_config(self.config, style)
            section["auto_detect"] = not section.get("auto_detect", True)
            self.status_text = f"Toggled {style} auto_detect to {section['auto_detect']}."
            self._open_toolchain_menu(style)

        def _prompt_toolchain_field(self, style: str, field_name: str, label: str) -> None:
            section = toolchain_config(self.config, style)
            current = section.get(field_name, "")
            self._prompt(
                f"{style} Toolchain",
                f"{label} (blank allowed)",
                current,
                lambda value: self._set_toolchain_field(style, field_name, value),
            )

        def _set_toolchain_field(self, style: str, field_name: str, value: str) -> None:
            section = toolchain_config(self.config, style)
            section[field_name] = value
            self.status_text = f"Updated {style}.{field_name}."
            self._open_toolchain_menu(style)

        def _prompt_toolchain_executable(self, style: str, key: str) -> None:
            section = toolchain_config(self.config, style)
            current = section.get("executables", {}).get(key, "")
            self._prompt(
                f"{style} Toolchain",
                f"Executable override for {key}",
                current,
                lambda value: self._set_toolchain_executable(style, key, value),
            )

        def _set_toolchain_executable(self, style: str, key: str, value: str) -> None:
            section = toolchain_config(self.config, style)
            section.setdefault("executables", {})[key] = value
            self.status_text = f"Updated {style} executable override for {key}."
            self._open_toolchain_menu(style)

        def _save_global_config(self) -> None:
            save_config(self.config)
            self.status_text = "Saved global configuration."
            self._refresh()

        def _open_project_selector(self, destination: str) -> None:
            choices = _choice_labels(self.start_project_path)
            entries = [
                MenuEntry(
                    label,
                    lambda label=label: self._handle_project_root_selection(label, destination),
                    detail="folder/workspace",
                )
                for label in choices
            ]
            entries.append(
                MenuEntry(
                    "Browse filesystem",
                    lambda: self._open_browser(
                        title="Project Browser",
                        start_path=self.start_project_path if self.start_project_path.exists() else REPO_ROOT,
                        select_mode="project-root",
                        on_select=lambda path: self._handle_project_root_selection(str(path), destination),
                    ),
                )
            )
            entries.append(MenuEntry("Type path manually", lambda: self._prompt_for_project_path(destination)))
            entries.append(MenuEntry("Back", self._pop_menu if self.menu_stack else self.exit))
            self._push_menu(
                MenuState(
                    title="Project Selection",
                    summary=["Choose a project root or workspace. '.' is allowed and may expand into multiple project contexts."],
                    entries=entries,
                )
            )

        def _prompt_for_project_path(self, destination: str) -> None:
            self._prompt(
                "Project Selection",
                "Project or workspace path",
                ".",
                lambda value: self._handle_project_root_selection(value or ".", destination),
            )

        def _handle_project_root_selection(self, label: str, destination: str) -> None:
            selected_candidate = Path(label)
            if label == ".":
                selected_root = REPO_ROOT
            elif selected_candidate.is_absolute():
                selected_root = selected_candidate.resolve()
            else:
                selected_root = (REPO_ROOT / label).resolve()
            try:
                workspace = resolve_workspace(selected_root, config=self.config)
            except Exception as exc:
                self._show_dialog("Project Error", [str(exc)])
                return
            if not workspace.contexts:
                self._show_dialog("Project Error", [f"{selected_root} is not a recognizable project or workspace."])
                return
            if len(workspace.contexts) == 1:
                self._activate_context(workspace.contexts[0], destination)
                return
            entries = [
                MenuEntry(
                    f"{board_display_name(context.board)} | {context.design} | {_repo_relative(context.base_path)}",
                    lambda context=context: self._activate_context(context, destination),
                )
                for context in workspace.contexts
            ]
            entries.append(MenuEntry("Back", self._pop_menu))
            self._push_menu(
                MenuState(
                    title="Project Context Selection",
                    summary=[f"{_repo_relative(selected_root)} contains multiple project contexts. Choose one."],
                    entries=entries,
                )
            )

        def _activate_context(self, context: ProjectContext, destination: str) -> None:
            if destination == "config":
                self._open_project_config(context, return_to_project=False)
            else:
                self._open_project_menu(context, validate=not self.no_validate_toolchain)

        def _project_summary(self, context: ProjectContext) -> list[str]:
            project_cfg = load_project_config(context.base_path)
            effective_cfg = effective_project_config(project_cfg, context.board)
            default_project = read_default_project(context.base_path, context.board)
            lines = [
                f"Project root: {_repo_relative(context.base_path)}",
                f"Board: {board_display_name(context.board)} ({context.board})",
                f"Resolved design: {context.design}",
                f"Resolved backend: {context.backend}",
                f"Allowed toolchains: {', '.join(board_allowed_toolchains(context.board))}",
                f"Resolved project file: {context.project_file or '(none)'}",
                f"default.project.toml project_file: {default_project.relative_to(context.base_path).as_posix() if default_project else '(unset)'}",
                f"Preferred toolchain: {effective_cfg.get('preferred_toolchain') or '(default)'}",
                f"Project file override: {effective_cfg.get('project_file') or '(default)'}",
            ]
            return lines

        def _open_project_config(self, context: ProjectContext, return_to_project: bool) -> None:
            self.current_context = context
            entries = [
                MenuEntry("Configure Project File", self._open_project_file_menu),
                MenuEntry("Write default.project.toml", self._write_current_default_project),
                MenuEntry("Configure Project Toolchain Backend", self._open_project_toolchain_menu),
                MenuEntry("Save Project Configuration", self._save_current_project_config),
                MenuEntry("Validate Configured Toolchain", self._show_current_toolchain_validation),
                MenuEntry("Back To Project Menu" if return_to_project else "Back To Global Configuration", self._pop_to_previous_menu),
            ]
            self._set_or_replace_project_menu(
                MenuState(
                    title="Project Configuration",
                    summary=self._project_summary(context),
                    footer="Use default or override values explicitly. Project settings inherit from global settings unless overridden here.",
                    entries=entries,
                ),
                replace=return_to_project,
            )

        def _set_or_replace_project_menu(self, menu: MenuState, replace: bool) -> None:
            if replace and self.menu_stack:
                self._replace_menu(menu)
            else:
                self._push_menu(menu) if self.menu_stack else self._set_menu(menu)

        def _pop_to_previous_menu(self) -> None:
            self._pop_menu()

        def _reload_current_context(self) -> None:
            if not self.current_context:
                return
            self.current_context = resolve_project_context(
                self.current_context.board,
                str(self.current_context.base_path),
                config=self.config,
            )

        def _open_project_file_menu(self) -> None:
            if not self.current_context:
                return
            base_path = self.current_context.base_path
            project_cfg = load_project_config(base_path)
            effective_cfg = effective_project_config(project_cfg, self.current_context.board)
            active_toolchain = effective_cfg.get("preferred_toolchain") or self.current_context.backend
            candidates = _project_file_candidates(base_path, self.current_context.board, active_toolchain)
            entries = [MenuEntry("Use detected/default project file", lambda: self._set_project_file_override(""))]
            entries.extend(MenuEntry(f"Use override: {candidate}", lambda candidate=candidate: self._set_project_file_override(candidate)) for candidate in candidates)
            entries.append(
                MenuEntry(
                    "Browse filesystem",
                    lambda: self._open_browser(
                        title="Project File Browser",
                        start_path=base_path,
                        select_mode="project-file",
                        on_select=lambda path: self._set_project_file_override(path.relative_to(base_path).as_posix()),
                    ),
                )
            )
            entries.append(MenuEntry("Type relative path manually", self._prompt_project_file_override))
            entries.append(MenuEntry("Back", self._pop_menu))
            self._push_menu(
                MenuState(
                    title="Project File Configuration",
                    summary=[
                        f"Toolchain context: {active_toolchain}",
                        f"Current override: {effective_cfg.get('project_file') or '(default)'}",
                    ],
                    entries=entries,
                )
            )

        def _prompt_project_file_override(self) -> None:
            if not self.current_context:
                return
            project_cfg = load_project_config(self.current_context.base_path)
            self._prompt(
                "Project File Configuration",
                "Project file relative path",
                project_cfg.get("project_file", ""),
                self._set_project_file_override,
            )

        def _set_project_file_override(self, value: str) -> None:
            if not self.current_context:
                return
            update_project_config_for_context(
                self.current_context.base_path,
                self.current_context.board,
                lambda target, value=value: target.__setitem__("project_file", value),
            )
            self._reload_current_context()
            self.status_text = "Updated project file override."
            self._open_project_config(self.current_context, return_to_project=self.start_mode == "project")

        def _open_project_toolchain_menu(self) -> None:
            if not self.current_context:
                return
            project_cfg = load_project_config(self.current_context.base_path)
            self._push_menu(
                MenuState(
                    title="Project Toolchain Backend",
                    summary=[
                        f"Preferred: {effective_project_config(project_cfg, self.current_context.board).get('preferred_toolchain') or '(default)'}",
                        f"Allowed: {', '.join(board_allowed_toolchains(self.current_context.board))}",
                    ],
                    entries=[
                        MenuEntry("Use default/inherited toolchain", lambda: self._set_project_toolchain_override(""))
                    ]
                    + [
                        MenuEntry(f"Override to {style}", lambda style=style: self._set_project_toolchain_override(style))
                        for style in board_allowed_toolchains(self.current_context.board)
                    ]
                    + [MenuEntry("Back", self._pop_menu)],
                )
            )

        def _set_project_toolchain_override(self, style: str) -> None:
            if not self.current_context:
                return
            update_project_config_for_context(
                self.current_context.base_path,
                self.current_context.board,
                lambda target, style=style: target.__setitem__("preferred_toolchain", style),
            )
            self._reload_current_context()
            self.status_text = "Updated preferred project toolchain."
            self._open_project_config(self.current_context, return_to_project=self.start_mode == "project")

        def _save_current_project_config(self) -> None:
            if not self.current_context:
                return
            project_cfg = load_project_config(self.current_context.base_path)
            save_project_config(self.current_context.base_path, project_cfg)
            self.status_text = f"Saved project configuration for {_repo_relative(self.current_context.base_path)}."
            self._refresh()

        def _write_current_default_project(self) -> None:
            if not self.current_context:
                return
            if self.current_context.project_file is None:
                self._show_dialog("Project Marker", ["No resolved project file is available for default.project.toml."])
                return
            write_default_project(self.current_context.base_path, self.current_context.project_file, force=True, board=self.current_context.board)
            self.status_text = f"Wrote {default_project_marker(self.current_context.base_path)}."
            self._open_project_config(self.current_context, return_to_project=self.start_mode == "project")

        def _open_browser(self, title: str, start_path: Path, select_mode: str, on_select: Callable[[Path], None]) -> None:
            current_path = start_path.resolve()
            selected_entry: Path | None = None
            if current_path.is_file():
                selected_entry = current_path
                current_path = current_path.parent
            self.browser_state = BrowserState(
                title=title,
                current_path=current_path,
                select_mode=select_mode,
                on_select=on_select,
                on_cancel=lambda: None,
                selected_entry=selected_entry,
            )
            if selected_entry is not None:
                entries = _directory_entries(current_path)
                try:
                    self.browser_state.selected = entries.index(selected_entry)
                except ValueError:
                    self.browser_state.selected = 0
            self.status_text = "Browser opened."
            self._refresh()

        def _close_browser(self) -> None:
            self.browser_state = None
            self.status_text = ""
            self._refresh()

        def _browser_select_current_directory(self) -> None:
            browser = self.browser_state
            if not browser:
                return
            if browser.select_mode in {"project-root"} or browser.select_mode.startswith("toolchain-base:"):
                selected = browser.current_path
                self.browser_state = None
                browser.on_select(selected)
                self._refresh()

        def _selected_browser_entry(self) -> Path | None:
            browser = self.browser_state
            if not browser:
                return None
            entries = _directory_entries(browser.current_path)
            if not entries:
                return None
            return entries[browser.selected]

        def _browser_activate_selected(self) -> None:
            browser = self.browser_state
            if not browser:
                return
            entries = _directory_entries(browser.current_path)
            if not entries:
                return
            entry = entries[browser.selected]
            browser.selected_entry = entry.resolve()
            if entry.is_dir():
                browser.current_path = entry.resolve()
                browser.selected = 0
                browser.selected_entry = None
                self._refresh()
                return
            if browser.select_mode in {"project-file"} or browser.select_mode.startswith("toolchain-exec:"):
                self.browser_state = None
                browser.on_select(entry.resolve())
                self._refresh()

        def _toggle_output_view(self) -> None:
            if not self.output_lines:
                self.status_text = "No execution output has been captured yet."
                self._refresh()
                return
            self.output_visible = not self.output_visible
            if self.output_visible:
                self.status_text = "Log view open. Esc returns. W saves log."
            else:
                self.status_text = "Log view closed."
            self._refresh()

        def _save_output_log(self) -> None:
            if not self.output_lines:
                self.status_text = "No execution output to save."
                self._refresh()
                return
            logs_dir = BUILD_SYSTEM_ROOT / "logs"
            logs_dir.mkdir(parents=True, exist_ok=True)
            stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            path = logs_dir / f"tui-log-{stamp}.log"
            path.write_text("".join(self.output_lines), encoding="utf-8")
            self.status_text = f"Saved log to {path}"
            self._refresh()

        def _append_output_text(self, text: str) -> None:
            self.output_lines.append(text)
            if self.output_visible:
                log = self.query_one("#log", RichLog)
                log.write(text.rstrip("\n"))
                log.scroll_end(animate=False)

        def _finish_project_action(self, action_name: str, returncode: int) -> None:
            if len(self.output_lines) == 1:
                self._append_output_text("(no command output)\n")
            self.action_running = False
            if returncode != 0:
                self.status_text = f"{action_name} failed with exit code {returncode}. Live log remains open."
            else:
                self.status_text = f"{action_name} completed. Live log remains open."
            self._refresh()

        def _fail_project_action(self, action_name: str, message: str) -> None:
            self.action_running = False
            self._append_output_text(f"{message}\n")
            self.status_text = f"{action_name} failed to start. Live log remains open."
            self._refresh()

        def _launch_editor_for_file(self, kind: str, path: Path) -> None:
            cfg = editor_config(self.config, kind)
            env_var = cfg.get("env_var", "")
            command = os.environ.get(env_var, "") if env_var else ""
            if not command:
                command = cfg.get("command", "")
            if not command:
                self.status_text = f"No {kind} editor is configured."
                self._refresh()
                return
            args_template = cfg.get("args_template", "{file}")
            rendered = args_template.format(file=str(path), exe=command)
            argv = [command]
            if rendered.strip():
                argv.extend(shlex.split(rendered))
            launch_mode = cfg.get("launch_mode", "terminal")
            try:
                if launch_mode == "terminal":
                    with self.suspend():
                        subprocess.run(argv, check=False)
                else:
                    subprocess.Popen(argv)
                self.status_text = f"Launched {kind} editor for {path.name}."
            except Exception as exc:
                self.status_text = f"Failed to launch {kind} editor: {exc}"
            self._refresh()

        def _modified_files(self) -> list[Path]:
            results: list[Path] = []
            commands = [
                ["git", "diff", "--name-only"],
                ["git", "diff", "--name-only", "--cached"],
                ["git", "ls-files", "--others", "--exclude-standard"],
            ]
            for command in commands:
                completed = subprocess.run(command, cwd=REPO_ROOT, capture_output=True, text=True, check=False)
                if completed.returncode != 0:
                    continue
                for line in completed.stdout.splitlines():
                    if line:
                        path = (REPO_ROOT / line).resolve()
                        if path not in results and path.exists():
                            results.append(path)
            return results

        def _open_modified_file_actions(self, path: Path) -> None:
            self._push_menu(
                MenuState(
                    title="Modified File Actions",
                    summary=[
                        f"File: {_repo_relative(path)}",
                        "Open the file with the configured text editor or hex viewer, or browse the containing folder.",
                    ],
                    entries=[
                        MenuEntry("Open in text editor", lambda path=path: self._launch_editor_for_file("text", path)),
                        MenuEntry("Open in hex viewer", lambda path=path: self._launch_editor_for_file("hex", path)),
                        MenuEntry(
                            "Browse containing folder",
                            lambda path=path: self._open_browser(
                                title=f"Modified File Browser: {path.name}",
                                start_path=path,
                                select_mode="project-file",
                                on_select=lambda chosen: None,
                            ),
                        ),
                        MenuEntry("Back", self._pop_menu),
                    ],
                )
            )

        def _open_modified_files_menu(self) -> None:
            files = self._modified_files()
            entries = [MenuEntry(_repo_relative(path), lambda path=path: self._open_modified_file_actions(path), detail="modified") for path in files]
            if not entries:
                entries = [MenuEntry("No modified files detected", self._pop_menu)]
            entries.append(MenuEntry("Back", self._pop_menu))
            self._push_menu(
                MenuState(
                    title="Modified Files",
                    summary=["Select a modified file to open it directly or browse around it."],
                    entries=entries,
                )
            )

        def _show_current_toolchain_validation(self) -> None:
            if not self.current_context:
                return
            warnings = validate_context_toolchain(self.current_context, self.config)
            if warnings:
                self._show_dialog("Toolchain Warning", warnings)
            else:
                self._show_dialog("Toolchain Check", ["Configured toolchain looks usable for this project."])

        def _open_project_menu(self, context: ProjectContext, validate: bool) -> None:
            self.current_context = context
            entries = [
                MenuEntry("Build", lambda: self._run_project_action("build")),
                MenuEntry("Program SRAM", lambda: self._run_project_action("program-sram")),
                MenuEntry("Program Flash", lambda: self._run_project_action("program-flash")),
                MenuEntry("Deploy", lambda: self._run_project_action("deploy")),
                MenuEntry("Check Toolchain", self._show_current_toolchain_validation),
                MenuEntry("Configure Project", lambda: self._open_project_config(context, return_to_project=True)),
                MenuEntry("Browse Modified Files", self._open_modified_files_menu),
                MenuEntry("Change Project", lambda: self._open_project_selector("project")),
                MenuEntry("Exit", self.exit),
            ]
            self._set_menu(
                MenuState(
                    title="Project Menu",
                    summary=self._project_summary(context),
                    footer="This menu uses the current project configuration. Validation warnings do not block entry.",
                    entries=entries,
                )
            )
            if validate:
                warnings = validate_context_toolchain(context, self.config)
                if warnings:
                    self._show_dialog("Toolchain Warning", warnings)

        def _run_project_action(self, action_name: str) -> None:
            if not self.current_context:
                return
            if self.action_running:
                self.status_text = "Another action is already running."
                self._refresh()
                return
            command = [
                sys.executable,
                "-m",
                "rmq_tmds_build.cli",
                "-p",
                str(self.current_context.base_path),
                self.current_context.board,
                action_name,
            ]
            env = os.environ.copy()
            src_dir = str(BUILD_SYSTEM_ROOT / "python" / "src")
            env["PYTHONPATH"] = f"{src_dir}{os.pathsep}{env['PYTHONPATH']}" if env.get("PYTHONPATH") else src_dir
            self.action_running = True
            self.output_title = f"Execution Output: {action_name}"
            self.output_lines = [f"$ {' '.join(command)}\n\n"]
            self.output_visible = True
            self.status_text = f"{action_name} started. Live log opened."
            self._refresh()

            def runner() -> None:
                try:
                    if os.name == "posix":
                        master_fd, slave_fd = pty.openpty()
                        process = subprocess.Popen(
                            command,
                            cwd=REPO_ROOT,
                            env=env,
                            stdin=subprocess.DEVNULL,
                            stdout=slave_fd,
                            stderr=slave_fd,
                            text=False,
                            close_fds=True,
                        )
                        os.close(slave_fd)
                    else:
                        master_fd = None
                        process = subprocess.Popen(
                            command,
                            cwd=REPO_ROOT,
                            env=env,
                            stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT,
                            text=True,
                            bufsize=1,
                        )
                except Exception as exc:
                    self.call_from_thread(self._fail_project_action, action_name, str(exc))
                    return

                if master_fd is not None:
                    try:
                        while True:
                            try:
                                chunk = os.read(master_fd, 4096)
                            except OSError:
                                break
                            if not chunk:
                                break
                            self.call_from_thread(self._append_output_text, chunk.decode("utf-8", errors="replace"))
                    finally:
                        os.close(master_fd)
                else:
                    assert process.stdout is not None
                    for line in process.stdout:
                        self.call_from_thread(self._append_output_text, line)
                    process.stdout.close()
                returncode = process.wait()
                self.call_from_thread(self._finish_project_action, action_name, returncode)

            threading.Thread(target=runner, daemon=True).start()

        def on_input_submitted(self, event: Input.Submitted) -> None:
            self._submit_prompt(event.value)

        def on_key(self, event: Key) -> None:
            if self.output_visible:
                log = self.query_one("#log", RichLog)
                if event.key in {"escape", "q"}:
                    self.output_visible = False
                    self.status_text = "Log view closed."
                    self._refresh()
                elif event.key.lower() == "w":
                    self._save_output_log()
                elif event.key in {"up", "k"}:
                    log.scroll_up(animate=False)
                elif event.key in {"down", "j"}:
                    log.scroll_down(animate=False)
                elif event.key in {"pageup"}:
                    log.scroll_page_up(animate=False)
                elif event.key in {"pagedown"}:
                    log.scroll_page_down(animate=False)
                elif event.key in {"home"}:
                    log.scroll_home(animate=False)
                elif event.key in {"end"}:
                    log.scroll_end(animate=False)
                event.prevent_default()
                return

            if self.browser_state:
                browser = self.browser_state
                assert browser is not None
                entries = _directory_entries(browser.current_path)
                if event.key in {"up", "k"} and entries:
                    browser.selected = (browser.selected - 1) % len(entries)
                    self._refresh()
                elif event.key in {"down", "j"} and entries:
                    browser.selected = (browser.selected + 1) % len(entries)
                    self._refresh()
                elif event.key == "enter":
                    self._browser_activate_selected()
                elif event.key == "escape":
                    self._close_browser()
                elif event.key.lower() == "s":
                    self._browser_select_current_directory()
                elif event.key.lower() == "e":
                    selected = self._selected_browser_entry()
                    if selected and selected.is_file():
                        self._launch_editor_for_file("text", selected)
                elif event.key.lower() == "h":
                    selected = self._selected_browser_entry()
                    if selected and selected.is_file():
                        self._launch_editor_for_file("hex", selected)
                elif event.key.isdigit():
                    index = int(event.key) - 1
                    if 0 <= index < len(entries):
                        browser.selected = index
                        self._refresh()
                event.prevent_default()
                return

            if self.dialog:
                if event.key in {"enter", "escape"}:
                    self._dismiss_dialog()
                    event.prevent_default()
                return

            if self.input_state:
                if event.key == "escape":
                    self._cancel_prompt()
                    event.prevent_default()
                return

            menu = self.menu_stack[-1]
            if event.key.lower() == "l":
                self._toggle_output_view()
            elif event.key.lower() == "w":
                self._save_output_log()
            elif event.key in {"up", "k"}:
                menu.selected = (menu.selected - 1) % len(menu.entries)
                self._refresh()
            elif event.key in {"down", "j"}:
                menu.selected = (menu.selected + 1) % len(menu.entries)
                self._refresh()
            elif event.key == "enter":
                menu.entries[menu.selected].action()
            elif event.key == "escape":
                self._pop_menu()
            elif event.key.isdigit():
                index = int(event.key) - 1
                if 0 <= index < len(menu.entries):
                    menu.selected = index
                    self._refresh()

    BuildSystemApp().run()
    return 0
