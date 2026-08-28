$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'dpi-4d-r2-contract-hardening.ps1') -Mode OriginalRegression
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
