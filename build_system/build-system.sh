#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_DIR="${BASE_DIR}/python"
SRC_DIR="${PY_DIR}/src"
VENV_PYTHON="${PY_DIR}/.venv/bin/python"

if [[ -x "${VENV_PYTHON}" ]]; then
  PYTHON_BIN="${VENV_PYTHON}"
else
  PYTHON_BIN="${PYTHON_BIN:-python3}"
fi

export PYTHONPATH="${SRC_DIR}${PYTHONPATH:+:${PYTHONPATH}}"

exec "${PYTHON_BIN}" -m rmq_tmds_build.cli "$@"
