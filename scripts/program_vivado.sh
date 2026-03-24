#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

BITSTREAM_FILE=""
HW_DEVICE_PATTERN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bitstream)
      BITSTREAM_FILE="$2"
      shift 2
      ;;
    --device-pattern)
      HW_DEVICE_PATTERN="$2"
      shift 2
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$BITSTREAM_FILE" ]] || die "--bitstream is required"
[[ -f "$BITSTREAM_FILE" ]] || die "bitstream file not found: $BITSTREAM_FILE"

VIVADO_EXE="${VIVADO_BIN:-${VIVADO_ROOT}/bin}/vivado.bat"
[[ -f "$VIVADO_EXE" ]] || die "Vivado executable not found: $VIVADO_EXE"

TMP_TCL="$(mktemp -t vivado-program-XXXXXX.tcl)"
trap 'rm -f "$TMP_TCL"' EXIT

BITSTREAM_WIN_ESCAPED="$(wslpath -m "$BITSTREAM_FILE")"

{
  printf 'set bitstream_file {%s}\n' "$BITSTREAM_WIN_ESCAPED"
  printf 'set hw_device_pattern {%s}\n' "$HW_DEVICE_PATTERN"
  cat <<'EOF'
open_hw_manager
connect_hw_server

set targets [get_hw_targets *]
if {[llength $targets] == 0} {
  error "no hardware targets found"
}

current_hw_target [lindex $targets 0]
open_hw_target [current_hw_target]

set devices [get_hw_devices]
if {[llength $devices] == 0} {
  error "no hardware devices found"
}

if {$hw_device_pattern ne ""} {
  set matched [get_hw_devices $hw_device_pattern]
  if {[llength $matched] == 0} {
    error "no hardware device matched pattern $hw_device_pattern"
  }
  set current_device [lindex $matched 0]
} else {
  set current_device [lindex $devices 0]
}

current_hw_device $current_device
refresh_hw_device [current_hw_device]
set_property PROGRAM.FILE $bitstream_file [current_hw_device]
program_hw_devices [current_hw_device]
refresh_hw_device [current_hw_device]
close_hw_manager
EOF
} >"$TMP_TCL"

VIVADO_EXE_WIN="$(to_windows_path "$VIVADO_EXE")"
VIVADO_BIN_WIN="$(to_windows_path "$(dirname "$VIVADO_EXE")")"
TMP_TCL_WIN="$(to_windows_path "$TMP_TCL")"

printf 'Using %s\n' "$VIVADO_EXE"
printf 'Bitstream: %s\n' "$BITSTREAM_FILE"
if [[ -n "$HW_DEVICE_PATTERN" ]]; then
  printf 'Device pattern: %s\n' "$HW_DEVICE_PATTERN"
fi

declare -a WIN_ARGS=("$VIVADO_EXE_WIN" "-mode" "batch" "-source" "$TMP_TCL_WIN")
run_windows_command_sync_in_dir "$VIVADO_BIN_WIN" "${WIN_ARGS[@]}"
