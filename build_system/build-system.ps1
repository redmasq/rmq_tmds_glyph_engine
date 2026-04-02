$ErrorActionPreference = "Stop"

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PyDir = Join-Path $BaseDir "python"
$SrcDir = Join-Path $PyDir "src"
$VenvPython = Join-Path $PyDir ".venv\Scripts\python.exe"
$env:PYTHONPATH = if ($env:PYTHONPATH) { "$SrcDir;$env:PYTHONPATH" } else { $SrcDir }

if (Test-Path $VenvPython) {
    $PythonBin = $VenvPython
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonBin = "py"
    $PythonArgs = @("-3", "-m", "rmq_tmds_build.cli")
} else {
    $PythonBin = "python"
    $PythonArgs = @("-m", "rmq_tmds_build.cli")
}

if (-not $PythonArgs) {
    $PythonArgs = @("-m", "rmq_tmds_build.cli")
}

& $PythonBin @PythonArgs @args
