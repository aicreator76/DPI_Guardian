#Requires -Version 5.1
<#
.SYNOPSIS
    Smoke test per la verifica dell'integrità della struttura del repository DPI_Guardian.

.DESCRIPTION
    Controlla la presenza dei file e delle cartelle essenziali per il corretto
    funzionamento della demo. Da eseguire prima di ogni presentazione.

.EXAMPLE
    .\scripts\smoke_test.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

$passed  = 0
$failed  = 0
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

function Test-FileExists {
    param(
        [string]$RelativePath,
        [string]$Description
    )
    $fullPath = Join-Path $repoRoot $RelativePath
    if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
        $script:passed++
        $results.Add([PSCustomObject]@{ Stato = 'OK'; Controllo = $Description; Percorso = $RelativePath })
    }
    else {
        $script:failed++
        $results.Add([PSCustomObject]@{ Stato = 'FAIL'; Controllo = $Description; Percorso = $RelativePath })
    }
}

function Test-DirectoryHasFiles {
    param(
        [string]$RelativePath,
        [string]$Description
    )
    $fullPath = Join-Path $repoRoot $RelativePath
    $count = 0
    if (Test-Path -LiteralPath $fullPath -PathType Container) {
        $count = @(Get-ChildItem -LiteralPath $fullPath -File -Recurse).Count
    }
    if ($count -gt 0) {
        $script:passed++
        $results.Add([PSCustomObject]@{ Stato = 'OK'; Controllo = $Description; Percorso = $RelativePath })
    }
    else {
        $script:failed++
        $results.Add([PSCustomObject]@{ Stato = 'FAIL'; Controllo = $Description; Percorso = $RelativePath })
    }
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  DPI_Guardian — Smoke Test Struttura Repository" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

Test-FileExists      'demo\START_DEMO.bat'                          'START_DEMO.bat presente'
Test-FileExists      'demo\03_PRESENTAZIONE\console\index.html'     'Console index.html presente'
Test-FileExists      'demo\04_SCRIPT\DPI_GUARDIAN_RUN.ps1'          'DPI_GUARDIAN_RUN.ps1 presente'
Test-DirectoryHasFiles 'demo\01_DEMO_DATI'                          'Dati demo presenti in 01_DEMO_DATI'

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Risultati:" -ForegroundColor White

foreach ($r in $results) {
    $color = if ($r.Stato -eq 'OK') { 'Green' } else { 'Red' }
    $icon  = if ($r.Stato -eq 'OK') { '[OK]  ' } else { '[FAIL]' }
    Write-Host ("  {0} {1}" -f $icon, $r.Controllo) -ForegroundColor $color
    if ($r.Stato -eq 'FAIL') {
        Write-Host ("         Percorso atteso: {0}" -f $r.Percorso) -ForegroundColor DarkRed
    }
}

Write-Host ""
Write-Host ("Totale: {0} superati, {1} falliti" -f $passed, $failed) -ForegroundColor White

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "SMOKE TEST FALLITO — correggere le criticità prima della presentazione." -ForegroundColor Red
    Write-Host ""
    exit 1
}
else {
    Write-Host ""
    Write-Host "SMOKE TEST SUPERATO — struttura repository valida." -ForegroundColor Green
    Write-Host ""
    exit 0
}
