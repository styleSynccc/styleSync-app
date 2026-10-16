$ErrorActionPreference = 'Stop'

$workerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $workerDir '..\..')).Path
$pythonExe = Join-Path $workerDir '.venv\Scripts\python.exe'

if (-not (Test-Path -LiteralPath $pythonExe)) {
    throw 'FASHN VTON is not installed. Run apps/fashn_vton_worker/setup.ps1 first.'
}

$env:FASHN_VTON_REPO = Join-Path $repoRoot 'third_party\fashn-vton-1.5'
$env:FASHN_VTON_WEIGHTS = Join-Path $env:FASHN_VTON_REPO 'weights'
$env:HF_HUB_DOWNLOAD_TIMEOUT = '120'
$env:HF_HUB_ETAG_TIMEOUT = '30'
$env:PYTHONUTF8 = '1'
Set-Location $workerDir
& $pythonExe -m uvicorn worker:app --host 127.0.0.1 --port 8002
