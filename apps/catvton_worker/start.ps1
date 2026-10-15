$ErrorActionPreference = 'Stop'

$workerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $workerDir '..\..')).Path
$pythonExe = Join-Path $workerDir '.venv\Scripts\python.exe'

if (-not (Test-Path -LiteralPath $pythonExe)) {
    throw 'CatVTON is not installed. Run apps/catvton_worker/setup.ps1 first.'
}

$env:CATVTON_REPO = Join-Path $repoRoot 'third_party\CatVTON'
$env:HF_HUB_ENABLE_HF_TRANSFER = '1'
$env:HF_HUB_DOWNLOAD_TIMEOUT = '120'
$env:HF_HUB_ETAG_TIMEOUT = '30'
Set-Location $workerDir
& $pythonExe -m uvicorn worker:app --host 127.0.0.1 --port 8001
