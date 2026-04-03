#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$REPO_ROOT"

command -v verilator >/dev/null 2>&1 || {
  printf 'error: verilator is not installed.\n' >&2
  exit 1
}

python3 "$REPO_ROOT/scripts/gen_font_module.py" \
  --format gowin \
  --input "$REPO_ROOT/resources/cp437_8x16.mem" \
  --output "$REPO_ROOT/platform/gowin/gowin_prom_cp437_8x16/gowin_prom_cp437_8x16.v" \
  --module-name Gowin_pROM_cp437_8x16

mkdir -p "$REPO_ROOT/platform/gowin/generated"
printf '\140define VIDEO_MODE 0\n' > "$REPO_ROOT/platform/gowin/generated/video_mode_config.vh"

verilator \
  --lint-only \
  --top-module top \
  --Wall \
  --timing \
  -Wno-fatal \
  -Wno-DECLFILENAME \
  -Wno-UNUSEDSIGNAL \
  -Wno-UNDRIVEN \
  -Iplatform/gowin \
  -Iplatform/gowin/generated \
  -Iplatform/gowin/boards/tang-nano-20k \
  "$SCRIPT_DIR/verilator_gowin_prims.v" \
  platform/gowin/gowin_rpll/gowin_rpll_480p.v \
  platform/gowin/gowin_rpll/gowin_rpll_720p.v \
  platform/gowin/gowin_prom_cp437_8x16/gowin_prom_cp437_8x16.v \
  core/cp437_font_rom.v \
  core/display_signal.v \
  core/tmds_encoder.v \
  core/text_cell_bram.v \
  core/text_frame_ctrl.v \
  core/text_init_writer.v \
  core/text_mode_source.v \
  core/text_plane.v \
  core/text_snapshot_loader.v \
  core/vga16_palette.v \
  platform/gowin/gowin_hdmi_phy.v \
  platform/gowin/gowin_video_pll.v \
  platform/gowin/boards/tang-nano-20k/top.v
