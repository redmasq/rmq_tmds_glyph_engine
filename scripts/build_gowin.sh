#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

PROJECT_FILE="${PROJECT_FILE:-${REPO_ROOT}/platform/gowin/boards/tang-nano-20k/tang-nano-20k.gprj}"
MODE="batch"
ACTION="build"
RUN_PROCESS="${RUN_PROCESS:-all}"
declare -a EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gui|--open)
      MODE="gui"
      shift
      ;;
    --batch)
      MODE="batch"
      shift
      ;;
    --project)
      PROJECT_FILE="$2"
      shift 2
      ;;
    --process)
      RUN_PROCESS="$2"
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

[[ -f "$PROJECT_FILE" ]] || die "project file not found: $PROJECT_FILE"

if [[ "$MODE" == "gui" ]]; then
  if [[ -f "${GOWIN_IDE_BIN}/gw_ide" ]]; then
    GOWIN_EXE="${GOWIN_IDE_BIN}/gw_ide"
  else
    GOWIN_EXE="${GOWIN_IDE_BIN}/gw_ide.exe"
  fi
else
  if [[ -f "${GOWIN_IDE_BIN}/gw_sh" ]]; then
    GOWIN_EXE="${GOWIN_IDE_BIN}/gw_sh"
  else
    GOWIN_EXE="${GOWIN_IDE_BIN}/gw_sh.exe"
  fi
fi

[[ -f "$GOWIN_EXE" ]] || die "Gowin executable not found: $GOWIN_EXE"

printf 'Using %s\n' "$GOWIN_EXE"
printf 'Project: %s\n' "$PROJECT_FILE"

if is_windows_binary "$GOWIN_EXE"; then
  PROJECT_WIN="$(to_windows_path "$PROJECT_FILE")"
  GOWIN_EXE_WIN="$(to_windows_path "$GOWIN_EXE")"

  if [[ "$MODE" == "gui" ]]; then
    declare -a WIN_ARGS=("$GOWIN_EXE_WIN" "$PROJECT_WIN")
    run_windows_command_async "${WIN_ARGS[@]}"
  else
    TMP_TCL="$(mktemp -t gowin-batch-XXXXXX.tcl)"
    trap 'rm -f "$TMP_TCL"' EXIT

    cat >"$TMP_TCL" <<'EOF'
proc log {msg} {
    puts $msg
    flush stdout
}

proc try_script {label body} {
    log ">>> $label"
    if {[catch {uplevel #0 $body} result opts]} {
        log "FAIL: $label -> $result"
        return 0
    }
    if {$result ne ""} {
        log "OK: $label -> $result"
    } else {
        log "OK: $label"
    }
    return 1
}

proc maybe_apply_project_option_overrides {project_path} {
    set project_name [file tail $project_path]
    if {$project_name eq "tang-primer-20k.gprj"} {
        log "Applying Tang Primer dual-purpose pin overrides"
        if {![try_script "set_option -use_sspi_as_gpio 1" {set_option -use_sspi_as_gpio 1}]} {
            exit 4
        }
        if {![try_script "set_option -use_mspi_as_gpio 1" {set_option -use_mspi_as_gpio 1}]} {
            exit 4
        }
        if {![try_script "set_option -use_done_as_gpio 1" {set_option -use_done_as_gpio 1}]} {
            exit 4
        }
        if {![try_script "set_option -use_ready_as_gpio 1" {set_option -use_ready_as_gpio 1}]} {
            exit 4
        }
    }
}

set project_path [lindex $argv 0]
set action [lindex $argv 1]
set run_process [lindex $argv 2]
if {$run_process eq ""} {
    set run_process "all"
}
set extra_args [lrange $argv 3 end]

log "cwd=[pwd]"
log "project_path=$project_path"
log "action=$action"
log "run_process=$run_process"
if {[llength $extra_args] > 0} {
    log "extra_args=$extra_args"
}

set opened [try_script "open_project" [list open_project $project_path]]
if {!$opened} {
    log "open_project failed; stopping."
    exit 2
}

maybe_apply_project_option_overrides $project_path

if {![try_script "run $run_process" [list run $run_process]]} {
    log "run $run_process failed after opening the project."
    exit 3
}

if {[llength [info commands close_project]] > 0} {
    catch {close_project}
}
exit 0
EOF

    TMP_TCL_WIN="$(to_windows_path "$TMP_TCL")"
    declare -a WIN_ARGS=("$GOWIN_EXE_WIN" "$TMP_TCL_WIN" "$PROJECT_WIN" "$ACTION" "$RUN_PROCESS")
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
      WIN_ARGS+=("${EXTRA_ARGS[@]}")
    fi
    run_windows_command_sync "${WIN_ARGS[@]}"
  fi
else
  if [[ "$MODE" == "gui" ]]; then
    run_local_command_async "$GOWIN_EXE" "$PROJECT_FILE"
  else
    TMP_TCL="$(mktemp -t gowin-batch-XXXXXX.tcl)"
    trap 'rm -f "$TMP_TCL"' EXIT

    cat >"$TMP_TCL" <<'EOF'
proc log {msg} {
    puts $msg
    flush stdout
}

proc try_script {label body} {
    log ">>> $label"
    if {[catch {uplevel #0 $body} result opts]} {
        log "FAIL: $label -> $result"
        return 0
    }
    if {$result ne ""} {
        log "OK: $label -> $result"
    } else {
        log "OK: $label"
    }
    return 1
}

proc maybe_apply_project_option_overrides {project_path} {
    set project_name [file tail $project_path]
    if {$project_name eq "tang-primer-20k.gprj"} {
        log "Applying Tang Primer dual-purpose pin overrides"
        if {![try_script "set_option -use_sspi_as_gpio 1" {set_option -use_sspi_as_gpio 1}]} {
            exit 4
        }
        if {![try_script "set_option -use_mspi_as_gpio 1" {set_option -use_mspi_as_gpio 1}]} {
            exit 4
        }
        if {![try_script "set_option -use_done_as_gpio 1" {set_option -use_done_as_gpio 1}]} {
            exit 4
        }
        if {![try_script "set_option -use_ready_as_gpio 1" {set_option -use_ready_as_gpio 1}]} {
            exit 4
        }
    }
}

set project_path [lindex $argv 0]
set action [lindex $argv 1]
set run_process [lindex $argv 2]
if {$run_process eq ""} {
    set run_process "all"
}
set extra_args [lrange $argv 3 end]

log "cwd=[pwd]"
log "project_path=$project_path"
log "action=$action"
log "run_process=$run_process"
if {[llength $extra_args] > 0} {
    log "extra_args=$extra_args"
}

set opened [try_script "open_project" [list open_project $project_path]]
if {!$opened} {
    log "open_project failed; stopping."
    exit 2
}

maybe_apply_project_option_overrides $project_path

if {![try_script "run $run_process" [list run $run_process]]} {
    log "run $run_process failed after opening the project."
    exit 3
}

if {[llength [info commands close_project]] > 0} {
    catch {close_project}
}
exit 0
EOF

    declare -a LOCAL_ARGS=("$TMP_TCL" "$PROJECT_FILE" "$ACTION" "$RUN_PROCESS")
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
      LOCAL_ARGS+=("${EXTRA_ARGS[@]}")
    fi
    "$GOWIN_EXE" "${LOCAL_ARGS[@]}"
  fi
fi
