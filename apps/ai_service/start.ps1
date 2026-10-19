param(
    [string]$BindAddress = '0.0.0.0',
    [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'
$serviceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$keyFile = Join-Path $serviceDir '.env'

# Read only the supported secret, never execute the file as PowerShell.
# An explicitly supplied environment variable takes precedence.
if (-not $env:FASHN_API_KEY -and (Test-Path -LiteralPath $keyFile)) {
    foreach ($line in Get-Content -LiteralPath $keyFile) {
        if ($line -match '^\s*FASHN_API_KEY\s*=\s*(.*?)\s*$') {
            $env:FASHN_API_KEY = $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
}

if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) {
    throw "Port $Port is already in use. Stop the existing StyleSync API before starting another."
}

if (-not $env:FASHN_API_KEY) {
    Write-Warning 'FASHN_API_KEY is missing. Hosted Inspo Mirror and shoe generation will be unavailable.'
}

Set-Location -LiteralPath $serviceDir
& python -m uvicorn app.main:app --host $BindAddress --port $Port
exit $LASTEXITCODE
