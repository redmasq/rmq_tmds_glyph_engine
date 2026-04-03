#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_GOWIN_ROOT_WINDOWS="/mnt/x/Gowin/Gowin_V1.9.11.03_Education_x64"
DEFAULT_GOWIN_ROOT_LOCAL="/opt/gowin"

if [[ -z "${GOWIN_ROOT:-}" ]]; then
  if [[ -d "${DEFAULT_GOWIN_ROOT_LOCAL}/IDE/bin" ]]; then
    GOWIN_ROOT="$DEFAULT_GOWIN_ROOT_LOCAL"
  else
    GOWIN_ROOT="$DEFAULT_GOWIN_ROOT_WINDOWS"
  fi
fi

GOWIN_IDE_BIN="${GOWIN_IDE_BIN:-${GOWIN_ROOT}/IDE/bin}"
GOWIN_PROGRAMMER_BIN="${GOWIN_PROGRAMMER_BIN:-${GOWIN_ROOT}/Programmer/bin}"
DEFAULT_VIVADO_ROOT="/mnt/y/AMDDesignTools/2025.2.1/Vivado"
VIVADO_ROOT="${VIVADO_ROOT:-$DEFAULT_VIVADO_ROOT}"
VIVADO_BIN="${VIVADO_BIN:-${VIVADO_ROOT}/bin}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "required tool not found: $1"
}

to_windows_path() {
  require_tool wslpath
  wslpath -w "$1"
}

windows_shell() {
  if command -v pwsh.exe >/dev/null 2>&1; then
    printf '%s' "pwsh.exe"
  elif command -v powershell.exe >/dev/null 2>&1; then
    printf '%s' "powershell.exe"
  else
    die "neither pwsh.exe nor powershell.exe is available from WSL"
  fi
}

powershell_quote() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf "'%s'" "$value"
}

run_windows_command_sync() {
  local shell
  shell="$(windows_shell)"

  local file_path="$1"
  shift

  local arg_list=""
  local arg
  for arg in "$@"; do
    if [[ -n "$arg_list" ]]; then
      arg_list+=", "
    fi
    arg_list+="$(powershell_quote "$arg")"
  done

  "$shell" -NoProfile -Command "& $(powershell_quote "$file_path") @($arg_list)"
}

run_windows_command_async() {
  local shell
  shell="$(windows_shell)"

  local file_path="$1"
  shift

  local arg_list=""
  local arg
  for arg in "$@"; do
    if [[ -n "$arg_list" ]]; then
      arg_list+=", "
    fi
    arg_list+="$(powershell_quote "$arg")"
  done

  "$shell" -NoProfile -Command "Start-Process -FilePath $(powershell_quote "$file_path") -ArgumentList @($arg_list)"
}

run_windows_command_sync_in_dir() {
  local shell
  shell="$(windows_shell)"

  local workdir="$1"
  shift
  local file_path="$1"
  shift

  local arg_list=""
  local arg
  for arg in "$@"; do
    if [[ -n "$arg_list" ]]; then
      arg_list+=", "
    fi
    arg_list+="$(powershell_quote "$arg")"
  done

  "$shell" -NoProfile -Command "Set-Location $(powershell_quote "$workdir"); & $(powershell_quote "$file_path") @($arg_list)"
}

is_windows_binary() {
  local file_path="$1"
  [[ "$file_path" == *.exe || "$file_path" == *.bat || "$file_path" == *.cmd ]]
}

run_local_command_async() {
  nohup "$@" >/dev/null 2>&1 &
}
