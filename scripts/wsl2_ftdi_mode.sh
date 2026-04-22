#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PYTHONPATH_ROOT="${REPO_ROOT}/build_system/python/src"

usage() {
  cat <<'EOF'
Usage: wsl2_ftdi_mode.sh <program|uart|status>

Modes:
  program  Release FTDI serial drivers so vendor programmers can own shared FTDI bridges.
  uart     Rebind FTDI serial drivers so WSL exposes ttyUSB devices for debug UART capture.
  status   Show current FTDI-related drivers, serial device nodes, and manifest-backed board matches.

Notes:
  - resources/boards.local.json is auto-created from known board FTDI defaults if missing.
  - This script manages WSL2 FTDI driver ownership; it does not auto-select a target board.
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

MODE="$1"

python_manifest() {
  PYTHONPATH="${PYTHONPATH_ROOT}${PYTHONPATH:+:${PYTHONPATH}}" python3 -m rmq_tmds_build.wsl2_ftdi "$@"
}

ensure_local_manifest() {
  python_manifest ensure-local >/dev/null
}

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

show_status() {
  echo "WSL2 FTDI mode status"
  echo
  echo "FTDI-related modules:"
  grep -iE 'ftdi_sio|usbserial' /proc/modules || true
  echo
  echo "Serial devices:"
  ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true
  echo
  PYTHONPATH="${PYTHONPATH_ROOT}${PYTHONPATH:+:${PYTHONPATH}}" python3 -m rmq_tmds_build.wsl2_ftdi status
  echo
  echo "Recent FTDI/tty messages:"
  dmesg | tail -n 80 | grep -iE 'ftdi|usbserial|ttyUSB|FTDI USB Serial' || true
}

ensure_local_manifest

case "${MODE}" in
  program)
    echo "Switching WSL2 FTDI bridges to program mode..."
    run_root modprobe -r ftdi_sio usbserial
    show_status
    ;;
  uart)
    echo "Switching WSL2 FTDI bridges to uart mode..."
    run_root modprobe usbserial
    run_root modprobe ftdi_sio
    show_status
    ;;
  status)
    show_status
    ;;
  *)
    usage
    exit 2
    ;;
esac
