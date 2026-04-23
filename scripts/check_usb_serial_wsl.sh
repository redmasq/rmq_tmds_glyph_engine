#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: check_usb_serial_wsl.sh <board> [status|load|release]

Boards:
  puhzi-pa200-fl-kfb

Actions:
  status   Show usbipd state, visible tty devices, and recent serial dmesg lines.
  load     Run the WSL-side modprobe steps needed for the CH340 UART path.
  release  Remove the CH340 and generic usbserial modules from WSL.

This helper summarizes or performs the likely next recovery steps when a USB
UART adapter is visible from Windows via usbipd but the expected /dev/ttyUSB*
node is missing in WSL.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

BOARD="$1"
ACTION="${2:-status}"

windows_shell() {
  if command -v pwsh.exe >/dev/null 2>&1; then
    printf '%s' "pwsh.exe"
  elif command -v powershell.exe >/dev/null 2>&1; then
    printf '%s' "powershell.exe"
  else
    printf '%s' ""
  fi
}

show_usbipd_status() {
  local shell
  shell="$(windows_shell)"
  if [[ -z "$shell" ]]; then
    printf 'Windows PowerShell bridge: not available from WSL\n'
    return
  fi
  printf 'usbipd status:\n'
  "$shell" -NoProfile -Command "usbipd list" || true
}

show_local_ttys() {
  printf '\nWSL serial devices:\n'
  ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || printf '  (none)\n'
}

show_driver_hint() {
  printf '\nRecent serial-related dmesg lines:\n'
  dmesg | tail -n 120 | grep -iE 'ch340|ch341|ttyUSB|usbserial' || printf '  (none)\n'
  printf '\nIf the device is already attached but no tty is present, try:\n'
  printf '  sudo modprobe usbserial\n'
  printf '  sudo modprobe ch341\n'
  printf '  ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null\n'
}

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

load_uart_modules() {
  printf '\nLoading WSL serial driver modules for CH340...\n'
  run_root modprobe usbserial
  run_root modprobe ch341
  show_local_ttys
}

release_uart_modules() {
  printf '\nReleasing WSL serial driver modules for CH340...\n'
  run_root modprobe -r ch341 usbserial || true
  show_local_ttys
}

case "$BOARD" in
  puhzi-pa200-fl-kfb)
    printf 'Checking USB UART recovery hints for %s\n' "$BOARD"
    printf 'Expected UART adapter: CH340 (VID:PID 1a86:7523)\n'
    printf 'Artix JTAG note: busid 15-3 is the separate JTAG adapter and is not needed for UART-only testing.\n\n'
    show_usbipd_status
    case "$ACTION" in
      status)
        show_local_ttys
        show_driver_hint
        ;;
      load)
        load_uart_modules
        show_driver_hint
        ;;
      release)
        release_uart_modules
        ;;
      *)
        usage
        exit 2
        ;;
    esac
    printf '\nIf a tty appears, rerun for example:\n'
    printf '  make puhzi-uart-reset-test TEST_TTY=/dev/ttyUSB0\n'
    ;;
  *)
    printf 'error: no USB-serial WSL helper is defined yet for board %s\n' "$BOARD" >&2
    exit 1
    ;;
esac
