$ErrorActionPreference = 'Stop'

$workerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $workerDir '..\..')).Path
$fashnDir = Join-Path $repoRoot 'third_party\fashn-vton-1.5'
$venvDir = Join-Path $workerDir '.venv'
$pythonExe = Join-Path $venvDir 'Scripts\python.exe'
$weightsDir = Join-Path $fashnDir 'weights'
$env:PYTHONUTF8 = '1'

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw 'uv is required. Install it from https://docs.astral.sh/uv/ first.'
}

if (-not (Test-Path -LiteralPath $fashnDir)) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fashnDir) | Out-Null
    git clone --depth 1 https://github.com/fashn-AI/fashn-vton-1.5.git $fashnDir
}

uv python install 3.11
if (-not (Test-Path -LiteralPath $pythonExe)) {
    uv venv $venvDir --python 3.11
}

# CUDA 12.8 wheels support both the current RTX 3050 and RTX 50-series GPUs.
uv pip install --python $pythonExe --index-url https://download.pytorch.org/whl/cu128 torch==2.7.1 torchvision==0.22.1
uv pip install --python $pythonExe -e $fashnDir
uv pip install --python $pythonExe -r (Join-Path $workerDir 'requirements.txt')

& $pythonExe (Join-Path $fashnDir 'scripts\download_weights.py') --weights-dir $weightsDir
& $pythonExe -c "import torch; print('PyTorch:', torch.__version__); print('CUDA:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'none'); assert torch.cuda.is_available(), 'CUDA-enabled PyTorch was not installed'"

Write-Host 'FASHN VTON worker setup complete.'
