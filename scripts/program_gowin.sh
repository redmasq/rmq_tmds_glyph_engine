#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

BITSTREAM_FILE="${BITSTREAM_FILE:-${REPO_ROOT}/impl/pnr/rmq_tmds_glyph_engine.fs}"
MODE="gui"
ACTION="run"
DEVICE="${DEVICE:-GW2AR-18C}"
declare -a EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gui|--open)
      MODE="gui"
      shift
      ;;
    --cli)
      MODE="cli"
      shift
      ;;
    --probe)
      MODE="cli"
      ACTION="probe"
      shift
      ;;
    --scan-cables)
      MODE="cli"
      ACTION="scan-cables"
      shift
      ;;
    --scan-device)
      MODE="cli"
      ACTION="scan-device"
      shift
      ;;
    --sram)
      MODE="cli"
      ACTION="program-sram"
      shift
      ;;
    --flash)
      MODE="cli"
      ACTION="program-flash"
      shift
      ;;
    --bitstream)
      BITSTREAM_FILE="$2"
      shift 2
      ;;
    --device)
      DEVICE="$2"
      shift 2
      ;;
    --)
      shift
      EXTRA_ARGS+=("$@")
      break
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ "$MODE" == "gui" ]]; then
  PROGRAM_EXE="${GOWIN_PROGRAMMER_BIN}/programmer.exe"
else
  PROGRAM_EXE="${GOWIN_PROGRAMMER_BIN}/programmer_cli.exe"
fi

[[ -f "$PROGRAM_EXE" ]] || die "Gowin programmer executable not found: $PROGRAM_EXE"

PROGRAM_EXE_WIN="$(to_windows_path "$PROGRAM_EXE")"
PROGRAM_DIR_WIN="$(to_windows_path "$(dirname "$PROGRAM_EXE")")"
BITSTREAM_FILE_WIN=""
if [[ -f "$BITSTREAM_FILE" ]]; then
  BITSTREAM_FILE_WIN="$(to_windows_path "$BITSTREAM_FILE")"
fi

declare -a WIN_ARGS=("$PROGRAM_EXE_WIN")

if [[ "$MODE" == "cli" ]]; then
  printf 'Programmer mode: %s\n' "$ACTION"
  printf 'Device: %s\n' "$DEVICE"
  if [[ -f "$BITSTREAM_FILE" ]]; then
    printf 'Bitstream: %s\n' "$BITSTREAM_FILE"
  else
    printf 'note: bitstream not found at %s\n' "$BITSTREAM_FILE" >&2
  fi

  if [[ "$ACTION" == "probe" ]]; then
    WIN_ARGS+=("--help")
  elif [[ "$ACTION" == "scan-cables" ]]; then
    WIN_ARGS+=("--scan-cables")
  elif [[ "$ACTION" == "scan-device" ]]; then
    WIN_ARGS+=("--device" "$DEVICE" "--scan")
  elif [[ "$ACTION" == "program-sram" ]]; then
    [[ -n "$BITSTREAM_FILE_WIN" ]] || die "bitstream file not found: $BITSTREAM_FILE"
    WIN_ARGS+=("--device" "$DEVICE" "--run" "2" "--fsFile" "$BITSTREAM_FILE_WIN")
  elif [[ "$ACTION" == "program-flash" ]]; then
    [[ -n "$BITSTREAM_FILE_WIN" ]] || die "bitstream file not found: $BITSTREAM_FILE"
    WIN_ARGS+=("--device" "$DEVICE" "--run" "9" "--fsFile" "$BITSTREAM_FILE_WIN")
  elif [[ ${#EXTRA_ARGS[@]} -eq 0 ]]; then
    printf 'note: no programmer_cli.exe arguments were provided.\n' >&2
    printf 'note: pass board/programming flags after -- once you know the exact CLI you want to use.\n' >&2
  fi
fi

if [[ "$ACTION" == "run" && ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  WIN_ARGS+=("${EXTRA_ARGS[@]}")
fi

if [[ "$MODE" == "gui" ]]; then
  run_windows_command_async "${WIN_ARGS[@]}"
else
  run_windows_command_sync_in_dir "$PROGRAM_DIR_WIN" "${WIN_ARGS[@]}"
fi
