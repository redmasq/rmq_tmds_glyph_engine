#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

MODE="batch"
TOP_MODULE=""
PART_NAME=""
PROJECT_NAME=""
OUT_DIR=""
declare -a SOURCE_FILES=()
declare -a XDC_FILES=()
declare -a VERILOG_DEFINES=()
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
    --top)
      TOP_MODULE="$2"
      shift 2
      ;;
    --part)
      PART_NAME="$2"
      shift 2
      ;;
    --name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --out-dir|--project-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --source)
      SOURCE_FILES+=("$2")
      shift 2
      ;;
    --xdc)
      XDC_FILES+=("$2")
      shift 2
      ;;
    --define)
      VERILOG_DEFINES+=("$2")
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

[[ -n "$TOP_MODULE" ]] || die "--top is required"
[[ -n "$PART_NAME" ]] || die "--part is required"
[[ ${#SOURCE_FILES[@]} -gt 0 ]] || die "at least one --source file is required"

for src in "${SOURCE_FILES[@]}"; do
  [[ -f "$src" ]] || die "source file not found: $src"
done
for xdc in "${XDC_FILES[@]}"; do
  [[ -f "$xdc" ]] || die "constraint file not found: $xdc"
done

PROJECT_NAME="${PROJECT_NAME:-$TOP_MODULE}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/impl/vivado/${PROJECT_NAME}}"
VIVADO_JOBS="${VIVADO_JOBS:-8}"

VIVADO_EXE="${VIVADO_BIN:-${VIVADO_ROOT}/bin}/vivado.bat"
[[ -f "$VIVADO_EXE" ]] || die "Vivado executable not found: $VIVADO_EXE"

mkdir -p "$OUT_DIR"

TMP_TCL="$(mktemp -t vivado-build-XXXXXX.tcl)"
trap 'rm -f "$TMP_TCL"' EXIT

vivado_quote_path() {
  printf '{%s}' "$(wslpath -m "$1")"
}

OUT_DIR_WIN_ESCAPED="$(wslpath -m "$OUT_DIR")"

{
  printf 'set project_name {%s}\n' "$PROJECT_NAME"
  printf 'set top_module {%s}\n' "$TOP_MODULE"
  printf 'set part_name {%s}\n' "$PART_NAME"
  printf 'set out_dir {%s}\n' "$OUT_DIR_WIN_ESCAPED"
  printf 'set vivado_jobs {%s}\n' "$VIVADO_JOBS"
  printf 'set verilog_defines [list'
  for def in "${VERILOG_DEFINES[@]}"; do
    printf ' {%s}' "$def"
  done
  printf ']\n'

  if [[ "$MODE" == "gui" ]]; then
    cat <<'EOF'
create_project -force $project_name $out_dir -part $part_name
set_property target_language Verilog [current_project]
EOF
    for src in "${SOURCE_FILES[@]}"; do
      printf 'add_files -fileset sources_1 %s\n' "$(vivado_quote_path "$src")"
    done
    for xdc in "${XDC_FILES[@]}"; do
      printf 'add_files -fileset constrs_1 %s\n' "$(vivado_quote_path "$xdc")"
    done
    cat <<'EOF'
set_property top $top_module [get_filesets sources_1]
if {[llength $verilog_defines] > 0} {
  set_property verilog_define $verilog_defines [get_filesets sources_1]
}
update_compile_order -fileset sources_1
start_gui
EOF
  else
    for src in "${SOURCE_FILES[@]}"; do
      printf 'read_verilog %s\n' "$(vivado_quote_path "$src")"
    done
    for xdc in "${XDC_FILES[@]}"; do
      printf 'read_xdc %s\n' "$(vivado_quote_path "$xdc")"
    done
    cat <<'EOF'
set_param general.maxThreads $vivado_jobs
if {[llength $verilog_defines] > 0} {
  synth_design -top $top_module -part $part_name -verilog_define $verilog_defines
} else {
  synth_design -top $top_module -part $part_name
}
opt_design
place_design
route_design
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
write_bitstream -force [file join $out_dir ${project_name}.bit]
EOF
  fi
} >"$TMP_TCL"

VIVADO_EXE_WIN="$(to_windows_path "$VIVADO_EXE")"
VIVADO_BIN_WIN="$(to_windows_path "$(dirname "$VIVADO_EXE")")"
TMP_TCL_WIN="$(to_windows_path "$TMP_TCL")"

printf 'Using %s\n' "$VIVADO_EXE"
printf 'Mode: %s\n' "$MODE"
printf 'Part: %s\n' "$PART_NAME"
printf 'Top: %s\n' "$TOP_MODULE"
printf 'Output: %s\n' "$OUT_DIR"
printf 'Vivado jobs: %s\n' "$VIVADO_JOBS"

declare -a WIN_ARGS=("$VIVADO_EXE_WIN")
if [[ "$MODE" == "gui" ]]; then
  WIN_ARGS+=("-mode" "tcl" "-source" "$TMP_TCL_WIN")
  if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    WIN_ARGS+=("${EXTRA_ARGS[@]}")
  fi
  run_windows_command_async "${WIN_ARGS[@]}"
else
  WIN_ARGS+=("-mode" "batch" "-source" "$TMP_TCL_WIN")
  if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    WIN_ARGS+=("${EXTRA_ARGS[@]}")
  fi
  run_windows_command_sync_in_dir "$VIVADO_BIN_WIN" "${WIN_ARGS[@]}"
fi
