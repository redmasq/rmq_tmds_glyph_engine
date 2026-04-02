$ErrorActionPreference = "Stop"

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PyDir = Join-Path $BaseDir "python"
$VenvDir = Join-Path $PyDir ".venv"

if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 -m venv $VenvDir
    & (Join-Path $VenvDir "Scripts\python.exe") -m pip install --upgrade pip
    & (Join-Path $VenvDir "Scripts\python.exe") -m pip install -e "$PyDir[tui]"
} else {
    & python -m venv $VenvDir
    & (Join-Path $VenvDir "Scripts\python.exe") -m pip install --upgrade pip
    & (Join-Path $VenvDir "Scripts\python.exe") -m pip install -e "$PyDir[tui]"
}

Write-Host "Created venv at $VenvDir"
