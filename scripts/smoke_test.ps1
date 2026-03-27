$root = Join-Path $PSScriptRoot "..\demo"
$root = (Resolve-Path $root).Path

$checks = @(
    (Join-Path $root "START_DEMO.bat"),
    (Join-Path $root "03_PRESENTAZIONE\console\index.html"),
    (Join-Path $root "04_SCRIPT\DPI_GUARDIAN_RUN.ps1")
)

$ok = $true

foreach ($c in $checks) {
    if (-not (Test-Path $c)) {
        Write-Host "[MISSING] $c"
        $ok = $false
    }
    else {
        Write-Host "[OK] $c"
    }
}

$dataFiles = Get-ChildItem (Join-Path $root "01_DEMO_DATI") -File -ErrorAction SilentlyContinue
if (-not $dataFiles -or $dataFiles.Count -eq 0) {
    Write-Host "[MISSING] Nessun file demo in 01_DEMO_DATI"
    $ok = $false
}
else {
    Write-Host "[OK] File demo trovati: $($dataFiles.Count)"
}

if ($ok) {
    Write-Host ""
    Write-Host "SMOKE TEST: OK"
    exit 0
}
else {
    Write-Host ""
    Write-Host "SMOKE TEST: FAILED"
    exit 1
}
