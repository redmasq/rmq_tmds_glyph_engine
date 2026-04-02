@echo off
setlocal

set "BASE_DIR=%~dp0"
set "PY_DIR=%BASE_DIR%python"
set "SRC_DIR=%PY_DIR%\src"
set "VENV_PYTHON=%PY_DIR%\.venv\Scripts\python.exe"
set "PYTHONPATH=%SRC_DIR%;%PYTHONPATH%"

if exist "%VENV_PYTHON%" (
  "%VENV_PYTHON%" -m rmq_tmds_build.cli %*
) else (
  py -3 -m rmq_tmds_build.cli %*
)
