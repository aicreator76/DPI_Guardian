$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$demoRoot = Split-Path -Parent $scriptDir

$mainScript = Join-Path $scriptDir "DPI_GUARDIAN_RUN.ps1"
$outputJson = Join-Path $demoRoot "02_OUTPUT\dashboard_data.json"
$consoleJson = Join-Path $demoRoot "03_PRESENTAZIONE\console\dashboard_data.json"
$dashboardHtml = Join-Path $demoRoot "03_PRESENTAZIONE\console\index.html"

Write-Host ""
Write-Host "=== DPI GUARDIAN LOCAL RUN ==="
Write-Host ""

if (-not (Test-Path $mainScript)) {
    Write-Host "[ERRORE] Script principale non trovato: $mainScript"
    exit 1
}

Write-Host "[OK] Avvio script principale..."
& $mainScript

if (-not (Test-Path $outputJson)) {
    Write-Host "[ERRORE] JSON output non trovato: $outputJson"
    exit 1
}

$consoleDir = Split-Path -Parent $consoleJson
New-Item -ItemType Directory -Force -Path $consoleDir | Out-Null
Copy-Item -Path $outputJson -Destination $consoleJson -Force

Write-Host "[OK] JSON disponibile in output: $outputJson"
Write-Host "[OK] JSON copiato in console: $consoleJson"

if (Test-Path $dashboardHtml) {
    Write-Host "[OK] Apertura dashboard locale..."
    Start-Process $dashboardHtml
}
else {
    Write-Host "[WARNING] Dashboard non trovata: $dashboardHtml"
}

Write-Host ""
Write-Host "=== FINE LOCAL RUN ==="
Write-Host ""