from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

from .config import toolchain_config
from .paths import REPO_ROOT
from .targets import ProjectContext, board_manifest_entry, get_board_target, repo_path


class ActionError(RuntimeError):
    pass


def run_command(args: list[str], env: dict[str, str] | None = None) -> None:
    merged_env = os.environ.copy()
    if env:
        merged_env.update({k: v for k, v in env.items() if v})
    completed = subprocess.run(args, cwd=REPO_ROOT, env=merged_env, check=False)
    if completed.returncode != 0:
        raise ActionError(f"command failed with exit code {completed.returncode}: {' '.join(args)}")


def ensure_cp437_mem() -> None:
    run_command([
        sys.executable,
        str(repo_path("scripts/gen_font_module.py")),
        "--graph-input",
        str(repo_path("third_party/pcface/out/moderndos-8x16/graph.txt")),
        "--mem-output",
        str(repo_path("resources/cp437_8x16.mem")),
        "--mi-output",
        str(repo_path("resources/cp437_8x16.mi")),
        "--source-note",
        "PC Face moderndos-8x16 graph.txt (https://github.com/susam/pcface/tree/main/out/moderndos-8x16)",
    ])


def ensure_gowin_font_rom() -> None:
    ensure_cp437_mem()
    run_command([
        sys.executable,
        str(repo_path("scripts/gen_font_module.py")),
        "--format",
        "gowin",
        "--input",
        str(repo_path("resources/cp437_8x16.mem")),
        "--output",
        str(repo_path("platform/gowin/gowin_prom_cp437_8x16/gowin_prom_cp437_8x16.v")),
        "--module-name",
        "Gowin_pROM_cp437_8x16",
    ])


def ensure_artix_font_rom() -> None:
    ensure_cp437_mem()
    output = repo_path("platform/artix/generated/artix_cp437_font_rom.v")
    output.parent.mkdir(parents=True, exist_ok=True)
    run_command([
        sys.executable,
        str(repo_path("scripts/gen_font_module.py")),
        "--format",
        "artix",
        "--input",
        str(repo_path("resources/cp437_8x16.mem")),
        "--output",
        str(output),
        "--module-name",
        "artix_cp437_font_rom",
    ])


def ensure_gowin_video_mode(board: str, video_mode: str) -> None:
    config_file = repo_path("platform/gowin/generated/video_mode_config.vh")
    config_file.parent.mkdir(parents=True, exist_ok=True)
    if video_mode == "720p":
        config_file.write_text("`define VIDEO_MODE_720P\n`define VIDEO_MODE 1\n", encoding="ascii")
        hdmi_5x = "2.694"
        hdmi = "13.468"
    else:
        config_file.write_text("`define VIDEO_MODE 0\n", encoding="ascii")
        hdmi_5x = "7.407"
        hdmi = "37.037"

    sdc = _gowin_timing_constraint_path(board)

    sdc.write_text(
        "\n".join(
            [
                "create_clock -name clk_in -period 37.037 [get_ports {clk}]",
                f"create_clock -name hdmi_clk_5x -period {hdmi_5x} [get_pins {{hdmi_pll/u_pll/rpll_inst/CLKOUT}}]",
                f"create_clock -name hdmi_clk -period {hdmi} [get_pins {{u_clkdiv5/CLKOUT}}]",
            ]
        )
        + "\n",
        encoding="ascii",
    )


def ensure_gowin_feature_config(enable_uart_cursor_console: str) -> None:
    config_file = repo_path("platform/gowin/generated/feature_config.vh")
    config_file.parent.mkdir(parents=True, exist_ok=True)
    lines: list[str] = []
    if enable_uart_cursor_console not in {"0", "false", "False", "FALSE"}:
      lines.append("`define ENABLE_UART_TEXT_CURSOR_CONSOLE")
    config_file.write_text(("\n".join(lines) + "\n") if lines else "", encoding="ascii")


def _effective_toolchain_config(config: dict, context: ProjectContext, style: str) -> dict:
    merged = {
        "base_path": toolchain_config(config, style).get("base_path", ""),
        "executables": dict(toolchain_config(config, style).get("executables", {})),
    }
    if style == "vivado":
        merged["device_pattern"] = toolchain_config(config, style).get("device_pattern", "")
    override = context.project_config.get("toolchains", {}).get(style, {})
    if override.get("base_path"):
        merged["base_path"] = override["base_path"]
    for key, value in override.get("executables", {}).items():
        if value:
            merged["executables"][key] = value
    if style == "vivado" and override.get("device_pattern"):
        merged["device_pattern"] = override["device_pattern"]
    return merged


def gowin_env(config: dict, context: ProjectContext) -> dict[str, str]:
    tool_cfg = _effective_toolchain_config(config, context, "gowin")
    return {
        "GOWIN_ROOT": tool_cfg.get("base_path", ""),
        "GOWIN_IDE_BIN": tool_cfg.get("executables", {}).get("ide_bin", ""),
        "GOWIN_PROGRAMMER_BIN": tool_cfg.get("executables", {}).get("programmer_bin", ""),
    }


def vivado_env(config: dict, context: ProjectContext) -> dict[str, str]:
    tool_cfg = _effective_toolchain_config(config, context, "vivado")
    return {
        "VIVADO_ROOT": tool_cfg.get("base_path", ""),
        "VIVADO_BIN": tool_cfg.get("executables", {}).get("bin", ""),
        "VIVADO_JOBS": os.environ.get("VIVADO_JOBS", ""),
    }


def _string_override(overrides: dict[str, str], primary: str, fallback: str | None = None, default: str = "") -> str:
    if primary in overrides:
        return overrides[primary]
    if fallback and fallback in overrides:
        return overrides[fallback]
    return default


def _resolve_gowin_project(context: ProjectContext) -> Path:
    if context.project_file is not None:
        return context.project_file
    target = get_board_target(context.board)
    rel = target.blinky_project if context.design == "blinky" else target.tmds_project
    if rel is None:
        raise ActionError(f"no Gowin project mapping found for {context.board} {context.design}")
    return repo_path(rel)


def _board_paths(board: str) -> dict:
    return board_manifest_entry(board).get("paths", {})


def _board_platform(board: str) -> str:
    return board_manifest_entry(board).get("platform", "")


def _board_part(board: str) -> str:
    return board_manifest_entry(board).get("device", {}).get("tool_name", "")


def _gowin_timing_constraint_path(board: str) -> Path:
    timing_path = _board_paths(board).get("constraints", {}).get("timing")
    if not timing_path:
        raise ActionError(f"no timing constraint path defined for {board}")
    return repo_path(timing_path)


def build(context: ProjectContext, config: dict, overrides: dict[str, str]) -> None:
    video_mode = _string_override(overrides, "VIDEO_MODE", default="480p")
    process = _string_override(overrides, "RUN_PROCESS", "PROCESS", default="all")
    backend = _string_override(overrides, "BACKEND", default=context.backend)
    enable_uart_cursor_console = _string_override(overrides, "UART_CURSOR_CONSOLE", default="1")
    vivado_jobs = _string_override(overrides, "VIVADO_JOBS", default=os.environ.get("VIVADO_JOBS", ""))

    if backend == "gowin":
        if _board_platform(context.board) != "gowin":
            raise ActionError(f"{backend} does not match board {context.board}")
        env = gowin_env(config, context)
        project = _resolve_gowin_project(context)
        if context.design == "tmds":
            ensure_gowin_font_rom()
            ensure_gowin_video_mode(context.board, video_mode)
            ensure_gowin_feature_config(enable_uart_cursor_console)
        run_command(
            [
                "bash",
                str(repo_path("scripts/build_gowin.sh")),
                "--project",
                str(project),
                "--process",
                process,
            ],
            env=env,
        )
        return

    if backend == "vivado":
        env = vivado_env(config, context)
        if vivado_jobs:
            env["VIVADO_JOBS"] = vivado_jobs
        if _board_platform(context.board) != "artix":
            raise ActionError(f"{backend} does not match board {context.board}")
        part = _board_part(context.board)
        if not part:
            raise ActionError(f"no Vivado part is defined for {context.board}")
        if context.design == "blinky":
            base = context.base_path
            source = base / "src" / "blinky.v"
            xdc_candidates = sorted((base / "src").glob("*.xdc")) if (base / "src").is_dir() else []
            xdc = xdc_candidates[0] if xdc_candidates else base / "src" / "blinky.xdc"
            out_dir = base / "impl"
            if not source.exists():
                blinky_source = _board_paths(context.board).get("blinky_source")
                blinky_constraints = _board_paths(context.board).get("blinky_constraints")
                if not blinky_source or not blinky_constraints:
                    raise ActionError(f"no blinky sources are defined for {context.board}")
                source = repo_path(blinky_source)
                xdc = repo_path(blinky_constraints)
                base = source.parent.parent
                out_dir = base / "impl"
            run_command(
                [
                    "bash",
                    str(repo_path("scripts/build_vivado.sh")),
                    "--name",
                    f"blinky-{context.board}",
                    "--out-dir",
                    str(out_dir),
                    "--top",
                    "top",
                    "--part",
                    part,
                    "--source",
                    str(source),
                    "--xdc",
                    str(xdc),
                ],
                env=env,
            )
            return

        ensure_artix_font_rom()
        base = context.base_path
        if not (base / "top.v").exists():
            tmds_top = _board_paths(context.board).get("top")
            if not tmds_top:
                raise ActionError(f"no TMDS top path is defined for {context.board}")
            base = repo_path(tmds_top).parent
        xdc_path = _board_paths(context.board).get("constraints", {}).get("physical_and_timing")
        if not xdc_path:
            raise ActionError(f"no Vivado constraint path is defined for {context.board}")
        args = [
            "bash",
            str(repo_path("scripts/build_vivado.sh")),
            "--name",
            context.board,
            "--out-dir",
            str(base / "impl"),
            "--top",
            "top",
            "--part",
            part,
        ]
        for source in (
            str(base / "top.v"),
            "platform/artix/artix_video_pll.v",
            "platform/artix/artix_hdmi_phy.v",
            "platform/artix/artix_serializer_10to1.v",
            "platform/artix/pll/artix_pll_480p.v",
            "platform/artix/pll/artix_mmcm_720p.v",
            "platform/artix/generated/artix_cp437_font_rom.v",
            "aux/active_low_button_pulse.v",
            "aux/text_mode_status_tracker.v",
            "aux/text_mode_uart_debug_dump.v",
            "aux/uart_text_cursor_console.v",
            "aux/uart_rx.v",
            "aux/uart_tx.v",
            "core/cp437_font_rom.v",
            "core/display_signal.v",
            "core/text_cell_bram.v",
            "core/text_frame_ctrl.v",
            "core/text_init_writer.v",
            "core/text_mode_source.v",
            "core/text_plane.v",
            "core/text_snapshot_loader.v",
            "core/tmds_encoder.v",
            "core/vga16_palette.v",
        ):
            args.extend(["--source", source if source.startswith("/") else str(repo_path(source))])
        args.extend(["--xdc", str(repo_path(xdc_path))])
        if video_mode == "720p":
            args.extend(["--define", "USE_ARTIX_GENERATED_FONT_ROM", "--define", "VIDEO_MODE_720P"])
        else:
            args.extend(["--define", "USE_ARTIX_GENERATED_FONT_ROM"])
        run_command(args, env=env)
        return

    if backend == "yosys":
        raise ActionError("yosys/open-source project builds are not wired yet through the Python front end.")

    raise ActionError(f"unknown backend: {backend}")


def program(context: ProjectContext, config: dict, overrides: dict[str, str], load_target: str) -> None:
    backend = _string_override(overrides, "BACKEND", default=context.backend)

    if backend == "gowin":
        env = gowin_env(config, context)
        paths = _board_paths(context.board)
        if context.design == "blinky":
            project_rel = paths.get("blinky_project")
            if not project_rel:
                raise ActionError(f"no blinky project is defined for {context.board}")
            project_path = repo_path(project_rel)
            bitstream_path = project_path.parent / "impl" / "pnr" / f"{project_path.stem}.fs"
        else:
            bitstream_rel = paths.get("bitstream")
            if not bitstream_rel:
                raise ActionError(f"no TMDS bitstream is defined for {context.board}")
            bitstream_path = repo_path(bitstream_rel)
        device = _string_override(
            overrides,
            "DEVICE",
            default=board_manifest_entry(context.board).get("programming", {}).get("default_device", ""),
        )
        mode = "--flash" if load_target == "flash" else "--sram"
        run_command(
            [
                "bash",
                str(repo_path("scripts/program_gowin.sh")),
                mode,
                "--device",
                device,
                "--bitstream",
                str(bitstream_path),
            ],
            env=env,
        )
        return

    if backend == "vivado":
        env = vivado_env(config, context)
        paths = _board_paths(context.board)
        if context.design == "blinky":
            blinky_source = paths.get("blinky_source")
            if not blinky_source:
                raise ActionError(f"no blinky source is defined for {context.board}")
            bitstream_path = repo_path(blinky_source).parent.parent / "impl" / f"blinky-{context.board}.bit"
        else:
            bitstream_rel = paths.get("bitstream")
            if not bitstream_rel:
                raise ActionError(f"no TMDS bitstream is defined for {context.board}")
            bitstream_path = repo_path(bitstream_rel)
        args = ["bash", str(repo_path("scripts/program_vivado.sh")), "--bitstream", str(bitstream_path)]
        device_pattern = _effective_toolchain_config(config, context, "vivado").get("device_pattern", "")
        if device_pattern:
            args.extend(["--device-pattern", device_pattern])
        run_command(args, env=env)
        return

    raise ActionError(f"{backend} program flow is not wired yet.")


def deploy(context: ProjectContext, config: dict, overrides: dict[str, str], load_target: str) -> None:
    build(context=context, config=config, overrides=overrides)
    program(context=context, config=config, overrides=overrides, load_target=load_target)
