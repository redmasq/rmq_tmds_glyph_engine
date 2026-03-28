@echo off
setlocal

set "BASE_DIR=%~dp0"
set "PY_DIR=%BASE_DIR%python"
set "VENV_DIR=%PY_DIR%\.venv"

py -3 -m venv "%VENV_DIR%"
"%VENV_DIR%\Scripts\python.exe" -m pip install --upgrade pip
"%VENV_DIR%\Scripts\python.exe" -m pip install -e "%PY_DIR%[tui]"

echo Created venv at %VENV_DIR%
