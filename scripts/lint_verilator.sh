#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$REPO_ROOT"

command -v verilator >/dev/null 2>&1 || {
  printf 'error: verilator is not installed.\n' >&2
  exit 1
}

verilator \
  --lint-only \
  --top-module top \
  --Wall \
  --timing \
  -Wno-fatal \
  -Wno-DECLFILENAME \
  -Wno-UNUSEDSIGNAL \
  -Wno-UNDRIVEN \
  "$SCRIPT_DIR/verilator_gowin_prims.v" \
  platform/gowin/gowin_rpll/gowin_rpll_480p.v \
  platform/gowin/gowin_rpll/gowin_rpll_720p.v \
  platform/gowin/gowin_prom/gowin_prom.v \
  core/cp437_font_rom.v \
  core/display_signal.v \
  core/tmds_encoder.v \
  core/text_cell_bram.v \
  core/text_init_writer.v \
  core/text_mode_source.v \
  core/text_plane.v \
  core/text_snapshot_loader.v \
  core/vga16_palette.v \
  platform/gowin/hdmi_phy.v \
  platform/gowin/video_pll.v \
  platform/gowin/boards/tang-nano-20k/top.v
