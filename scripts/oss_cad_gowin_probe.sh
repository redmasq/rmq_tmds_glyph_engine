#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

YOSYS_BIN="${YOSYS_BIN:-/opt/oss-cad-suite/bin/yosys}"
NEXTPNR_BIN="${NEXTPNR_BIN:-/opt/oss-cad-suite/bin/nextpnr-himbaechel}"
GOWIN_PACK_BIN="${GOWIN_PACK_BIN:-/opt/oss-cad-suite/bin/gowin_pack}"
PROGRAM_SCRIPT="${PROGRAM_SCRIPT:-${SCRIPT_DIR}/program_gowin.sh}"

BOARD="${BOARD:-tang-primer-20k}"
VIDEO_MODE="${VIDEO_MODE:-480p}"
ENABLE_UART="${ENABLE_UART:-1}"
PROGRAM_SRAM="${PROGRAM_SRAM:-0}"
RUN_PACK="${RUN_PACK:-1}"
OUT_DIR=""

usage() {
  cat <<'EOF'
Usage: scripts/oss_cad_gowin_probe.sh [options]

Temporary OSS CAD Suite Gowin probe flow for TMDS-35.

Options:
  --board <tang-primer-20k|tang-nano-20k>
  --video-mode <480p|720p>
  --out-dir <dir>
  --no-uart
  --no-pack
  --program-sram
  --help

Notes:
  - This script uses OSS CAD Suite Yosys + nextpnr-himbaechel directly.
  - It normalizes the checked-in CST for nextpnr by splitting paired LVDS
    IO_LOC entries and dropping the current INS_LOC PLL placement line.
  - `--program-sram` chains into the existing vendor programmer helper using
    the packed .fs bitstream when packing succeeds.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --board)
      BOARD="$2"
      shift 2
      ;;
    --video-mode)
      VIDEO_MODE="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --no-uart)
      ENABLE_UART=0
      shift
      ;;
    --no-pack)
      RUN_PACK=0
      shift
      ;;
    --program-sram)
      PROGRAM_SRAM=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for tool in "$YOSYS_BIN" "$NEXTPNR_BIN"; do
  [[ -x "$tool" ]] || { printf 'error: missing executable: %s\n' "$tool" >&2; exit 1; }
done
if [[ "$RUN_PACK" == "1" ]]; then
  [[ -x "$GOWIN_PACK_BIN" ]] || { printf 'error: missing executable: %s\n' "$GOWIN_PACK_BIN" >&2; exit 1; }
fi

case "$BOARD" in
  tang-primer-20k)
    DEVICE="GW2A-LV18PG256C8/I7"
    FAMILY="GW2A-18"
    PROGRAM_DEVICE="GW2A-18C"
    BOARD_DIR="platform/gowin/boards/tang-primer-20k"
    TOP_FILE="${BOARD_DIR}/top.v"
    CST_FILE="${BOARD_DIR}/tang-primer-20k.cst"
    JSON_BASENAME="tang-primer"
    ;;
  tang-nano-20k)
    DEVICE="GW2AR-LV18QN88C8/I7"
    FAMILY="GW2A-18C"
    PROGRAM_DEVICE="GW2AR-18C"
    BOARD_DIR="platform/gowin/boards/tang-nano-20k"
    TOP_FILE="${BOARD_DIR}/top.v"
    CST_FILE="${BOARD_DIR}/tang-nano-20k.cst"
    JSON_BASENAME="tang-nano"
    ;;
  *)
    printf 'error: unsupported board: %s\n' "$BOARD" >&2
    exit 2
    ;;
esac

case "$VIDEO_MODE" in
  480p)
    VIDEO_DEFINE='`define VIDEO_MODE 0'
    VIDEO_ARGS=()
    ;;
  720p)
    VIDEO_DEFINE='`define VIDEO_MODE 1'
    VIDEO_ARGS=(-D VIDEO_MODE_720P)
    ;;
  *)
    printf 'error: unsupported video mode: %s\n' "$VIDEO_MODE" >&2
    exit 2
    ;;
esac

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="${REPO_ROOT}/build/oss-cad/${BOARD}"
fi

mkdir -p "${OUT_DIR}" "${REPO_ROOT}/platform/gowin/generated"
printf '%s\n' "$VIDEO_DEFINE" > "${REPO_ROOT}/platform/gowin/generated/video_mode_config.vh"
if [[ "$ENABLE_UART" == "1" ]]; then
  printf '%s\n' '`define ENABLE_UART_TEXT_CURSOR_CONSOLE' > "${REPO_ROOT}/platform/gowin/generated/feature_config.vh"
else
  : > "${REPO_ROOT}/platform/gowin/generated/feature_config.vh"
fi

python3 "${REPO_ROOT}/scripts/gen_font_module.py" \
  --format gowin \
  --input "${REPO_ROOT}/resources/cp437_8x16.mem" \
  --output "${REPO_ROOT}/platform/gowin/gowin_prom_cp437_8x16/gowin_prom_cp437_8x16.v" \
  --module-name Gowin_pROM_cp437_8x16

NORMALIZED_CST="${OUT_DIR}/$(basename "$CST_FILE" .cst).nextpnr.cst"
python3 - "$REPO_ROOT/$CST_FILE" "$NORMALIZED_CST" <<'PY'
import re
import sys
from pathlib import Path

src = Path(sys.argv[1]).read_text().splitlines()
dst_path = Path(sys.argv[2])
out = []
loc_re = re.compile(r'^IO_LOC\s+"([^"]+)"\s+([^;]+);$')
for line in src:
    stripped = line.strip()
    if stripped.startswith("INS_LOC "):
        out.append("// dropped for nextpnr probe: " + stripped)
        continue
    match = loc_re.match(stripped)
    if match and "," in match.group(2):
        signal = match.group(1)
        lhs, rhs = [token.strip() for token in match.group(2).split(",", 1)]
        if signal.endswith("_p[0]") or signal.endswith("_p[1]") or signal.endswith("_p[2]") or signal.endswith("_p[3]"):
            neg_signal = signal.replace("_p[", "_n[")
            out.append(f'IO_LOC "{signal}" {lhs};')
            out.append(f'IO_LOC "{neg_signal}" {rhs};')
            continue
    out.append(line)
dst_path.write_text("\n".join(out) + "\n")
PY

YOSYS_JSON="${OUT_DIR}/${JSON_BASENAME}-yosys.json"
NEXTPNR_JSON="${OUT_DIR}/${JSON_BASENAME}-nextpnr.json"
FS_FILE="${OUT_DIR}/${JSON_BASENAME}.fs"

cd "$REPO_ROOT"

read -r -d '' YOSYS_SCRIPT <<EOF || true
read_verilog -sv ${VIDEO_ARGS[*]} \
  ${TOP_FILE} \
  aux/active_low_button_pulse.v \
  aux/text_mode_status_tracker.v \
  aux/text_mode_uart_debug_dump.v \
  aux/uart_text_cursor_console.v \
  aux/uart_rx.v \
  aux/uart_tx.v \
  core/cp437_font_rom.v \
  core/display_signal.v \
  platform/gowin/gowin_prom_cp437_8x16/gowin_prom_cp437_8x16.v \
  platform/gowin/gowin_rpll/gowin_rpll_480p.v \
  platform/gowin/gowin_rpll/gowin_rpll_720p.v \
  core/tmds_encoder.v \
  platform/gowin/gowin_hdmi_phy.v \
  core/text_cell_bram.v \
  core/text_frame_ctrl.v \
  core/text_init_writer.v \
  core/text_mode_source.v \
  core/text_plane.v \
  core/text_snapshot_loader.v \
  core/vga16_palette.v \
  platform/gowin/gowin_video_pll.v
synth_gowin -family gw2a -top top -json ${YOSYS_JSON}
EOF

printf 'Using board: %s\n' "$BOARD"
printf 'Device: %s\n' "$DEVICE"
printf 'Family override: %s\n' "$FAMILY"
printf 'Normalized CST: %s\n' "$NORMALIZED_CST"
printf 'Output dir: %s\n' "$OUT_DIR"

"$YOSYS_BIN" -Q -p "$YOSYS_SCRIPT"

"$NEXTPNR_BIN" \
  --device "$DEVICE" \
  --json "$YOSYS_JSON" \
  --write "$NEXTPNR_JSON" \
  --top top \
  --vopt "family=${FAMILY}" \
  --vopt "cst=${NORMALIZED_CST}" \
  --timing-allow-fail

if [[ "$RUN_PACK" == "1" ]]; then
  "$GOWIN_PACK_BIN" -d "$DEVICE" -o "$FS_FILE" "$NEXTPNR_JSON"
  printf 'Packed bitstream: %s\n' "$FS_FILE"
fi

if [[ "$PROGRAM_SRAM" == "1" ]]; then
  [[ -x "$PROGRAM_SCRIPT" ]] || { printf 'error: missing programmer helper: %s\n' "$PROGRAM_SCRIPT" >&2; exit 1; }
  [[ -f "$FS_FILE" ]] || { printf 'error: expected packed bitstream not found: %s\n' "$FS_FILE" >&2; exit 1; }
  BITSTREAM_FILE="$FS_FILE" DEVICE="$PROGRAM_DEVICE" "$PROGRAM_SCRIPT" --cli --sram
fi
