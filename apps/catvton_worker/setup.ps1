$ErrorActionPreference = 'Stop'

$workerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $workerDir '..\..')).Path
$catVtonDir = Join-Path $repoRoot 'third_party\CatVTON'
$venvDir = Join-Path $workerDir '.venv'
$pythonExe = Join-Path $venvDir 'Scripts\python.exe'

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw 'uv is required. Install it from https://docs.astral.sh/uv/ first.'
}

if (-not (Test-Path -LiteralPath $catVtonDir)) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $catVtonDir) | Out-Null
    git clone --branch edited --depth 1 https://github.com/Zheng-Chong/CatVTON.git $catVtonDir
}

uv python install 3.9
if (-not (Test-Path -LiteralPath $pythonExe)) {
    uv venv $venvDir --python 3.9
}
uv pip install --python $pythonExe --index-url https://download.pytorch.org/whl/cu121 torch==2.1.2+cu121 torchvision==0.16.2+cu121
uv pip install --python $pythonExe -r (Join-Path $workerDir 'requirements.txt')

& $pythonExe -c "import torch; print('PyTorch:', torch.__version__); print('CUDA:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'none'); assert torch.cuda.is_available(), 'CUDA-enabled PyTorch was not installed'"

Write-Host 'CatVTON worker setup complete.'
