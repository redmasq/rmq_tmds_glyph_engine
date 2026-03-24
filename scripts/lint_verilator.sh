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
  src/gowin_rpll/gowin_rpll_480p.v \
  src/gowin_rpll/gowin_rpll_720p.v \
  src/gowin_prom/gowin_prom.v \
  src/cp437_font_rom.v \
  src/display_signal.v \
  src/hdmi.v \
  src/text_cell_bram.v \
  src/text_init_writer.v \
  src/text_mode_source.v \
  src/text_plane.v \
  src/text_snapshot_loader.v \
  src/top.v \
  src/vga16_palette.v \
  src/video_pll.v
