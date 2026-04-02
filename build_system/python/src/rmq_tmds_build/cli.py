from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .actions import ActionError, build, deploy, program
from .config import init_user_config, load_config, toolchain_config
from .host import available_package_managers, detect_host, python_version_ok
from .paths import CONFIG_PATH
from .prompt_config import run_prompt_config
from .project_resolver import resolve_project_context
from .targets import list_targets
from .project_workspace import resolve_single_project_for_cli
from .tool_discovery import check_tool, install_hints


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="rmq-tmds-build")
    parser.add_argument("-p", "--project-path", default=".", help="project root or board subtree to resolve from")
    parser.add_argument("--json", action="store_true", help="emit JSON for the check action")
    parser.add_argument("--list-targets", action="store_true")
    parser.add_argument("--config-show", action="store_true")
    parser.add_argument("--config-init", action="store_true")
    parser.add_argument("--config-init-force", action="store_true")
    parser.add_argument("--tui", action="store_true")
    parser.add_argument("--no-validate-toolchain", action="store_true")
    parser.add_argument("board", nargs="?")
    parser.add_argument("action", nargs="?")
    parser.add_argument("overrides", nargs="*")
    return parser


def print_targets() -> None:
    for target in list_targets():
        print(f"{target.board:24s} default-backend={target.default_backend}")


def parse_overrides(items: list[str]) -> dict[str, str]:
    overrides: dict[str, str] = {}
    for item in items:
        if "=" not in item:
            raise ActionError(f"override must be NAME=value, got: {item}")
        key, value = item.split("=", 1)
        key = key.strip().upper()
        if not key:
            raise ActionError(f"override key is empty in: {item}")
        overrides[key] = value
    return overrides


def run_sanity_check(as_json: bool) -> int:
    config = load_config()
    host = detect_host()
    managers = available_package_managers()
    min_cfg = config["python"]
    yosys_cfg = toolchain_config(config, "yosys")
    gowin_cfg = toolchain_config(config, "gowin")
    vivado_cfg = toolchain_config(config, "vivado")
    checks = [
        check_tool("yosys", yosys_cfg["executables"].get("yosys", "yosys")),
        check_tool("nextpnr-gowin", yosys_cfg["executables"].get("nextpnr_gowin", "nextpnr-gowin")),
        check_tool("nextpnr-xilinx", yosys_cfg["executables"].get("nextpnr_xilinx", "nextpnr-xilinx")),
        check_tool("gowin_pack", yosys_cfg["executables"].get("gowin_pack", "gowin_pack")),
        check_tool("openFPGALoader", yosys_cfg["executables"].get("openfpgaloader", "openFPGALoader")),
        check_tool("prjxray", yosys_cfg["executables"].get("prjxray", "")),
    ]
    result = {
        "host_mode": host.mode_name,
        "package_managers": managers,
        "config_path": str(CONFIG_PATH),
        "python_version_ok": python_version_ok(min_cfg["minimum_major"], min_cfg["minimum_minor"]),
        "gowin": gowin_cfg,
        "vivado": vivado_cfg,
        "yosys": yosys_cfg,
        "tools": [
            {
                "key": item.key,
                "command": item.command,
                "available": item.available,
                "resolved_path": item.resolved_path,
                "install_hints": install_hints(item.key, managers),
            }
            for item in checks
        ],
    }

    if as_json:
        print(json.dumps(result, indent=2))
        return 0

    print(f"Host mode: {result['host_mode']}")
    print(f"Package managers: {', '.join(managers) if managers else '(none detected)'}")
    print(f"Config path: {result['config_path']}")
    print(f"Python version OK: {result['python_version_ok']}")
    print(f"Gowin base path: {gowin_cfg.get('base_path') or '(auto/unset)'}")
    print(f"Vivado base path: {vivado_cfg.get('base_path') or '(auto/unset)'}")
    print("")
    for item in result["tools"]:
        status = "OK" if item["available"] else "MISSING"
        detail = item["resolved_path"] or item["command"] or "(unset)"
        print(f"[{status}] {item['key']}: {detail}")
        if not item["available"]:
            for hint in item["install_hints"]:
                print(f"  hint: {hint}")
    return 0


def handle_action(board: str, action: str, project_path: str, raw_overrides: list[str]) -> int:
    config = load_config()
    overrides = parse_overrides(raw_overrides)
    context = resolve_project_context(board=board, project_path=project_path, config=config)

    if action == "build":
        build(context=context, config=config, overrides=overrides)
    elif action == "program-sram":
        program(context=context, config=config, overrides=overrides, load_target="sram")
    elif action == "program-flash":
        program(context=context, config=config, overrides=overrides, load_target="flash")
    elif action == "deploy":
        load_target = overrides.get("LOAD_TARGET", "sram").lower()
        if load_target not in {"sram", "flash"}:
            raise ActionError(f"LOAD_TARGET must be sram or flash, got {load_target}")
        deploy(context=context, config=config, overrides=overrides, load_target=load_target)
    elif action == "check":
        return run_sanity_check(as_json="JSON" in overrides and overrides["JSON"].lower() in {"1", "true", "yes", "on"})
    else:
        raise ActionError(f"unknown action '{action}'. Expected one of: build, program-sram, program-flash, deploy, check")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = make_parser()
    args = parser.parse_args(argv)

    try:
        if args.list_targets:
            print_targets()
            return 0
        if args.config_show:
            print(json.dumps(load_config(), indent=2))
            return 0
        if args.config_init:
            path = init_user_config(force=args.config_init_force)
            print(path)
            return 0
        if args.tui:
            from .tui import main as tui_main

            return tui_main([])

        if not args.board or not args.action:
            if args.board in {"config", "menuconfig", "projectmenu"}:
                args.action = ""
            else:
                parser.error("expected <board> <action> or one of the utility flags")

        if args.board == "config":
            if not CONFIG_PATH.exists():
                path = init_user_config(force=False)
                print(f"Initialized config at {path}")
            return run_prompt_config()
            return 0

        if args.board == "menuconfig":
            from .tui import main as tui_main

            tui_args = ["--mode", "config"]
            if args.project_path and args.project_path != ".":
                context = resolve_single_project_for_cli(Path(args.project_path).resolve(), config=load_config())
                tui_args.extend(["--project-path", str(context.base_path)])
            return tui_main(tui_args)

        if args.board == "projectmenu":
            from .tui import main as tui_main

            tui_args = ["--mode", "project"]
            if args.project_path and args.project_path != ".":
                context = resolve_single_project_for_cli(Path(args.project_path).resolve(), config=load_config())
                tui_args.extend(["--project-path", str(context.base_path)])
            if args.no_validate_toolchain:
                tui_args.append("--no-validate-toolchain")
            return tui_main(tui_args)

        if args.action == "check":
            return handle_action(args.board, args.action, args.project_path, args.overrides + (["JSON=true"] if args.json else []))

        return handle_action(args.board, args.action, args.project_path, args.overrides)
    except (ActionError, FileExistsError, ModuleNotFoundError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
