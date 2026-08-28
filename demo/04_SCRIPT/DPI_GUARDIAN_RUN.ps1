$ErrorActionPreference = "Stop"

# Root demo = cartella "demo" (portabile su qualunque PC)
$root = Split-Path -Parent $PSScriptRoot

$datiDir = Join-Path $root "01_DEMO_DATI"
$outputDir = Join-Path $root "02_OUTPUT"
$operatoriDir = Join-Path $datiDir "08_OPERATORI_DPI"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Write-Host ""
Write-Host "=== DPI GUARDIAN DEMO RUN ==="
Write-Host ""

Write-Host "ROOT DEMO:" $root
Write-Host ""

Write-Host "=== CONTROLLO FILE DATI ==="
Write-Host ""

$files = @()
$inputFailure = $null

if (Test-Path -LiteralPath $datiDir -PathType Container) {
    try {
        $files = @(Get-ChildItem -LiteralPath $datiDir -File -Recurse -ErrorAction Stop)
    }
    catch {
        $inputFailure = "INPUT_DISCOVERY_FAILED: $($_.Exception.Message)"
    }

    $count = $files.Count

    Write-Host "Numero file trovati:" $count
    Write-Host ""

    foreach ($f in $files) {
        Write-Host "FILE ->" $f.FullName
    }

    if (-not $inputFailure -and $count -eq 0) {
        $inputFailure = "NO_INPUT_FILES_DISCOVERED"
    }
}
else {
    $inputFailure = "INPUT_DIRECTORY_NOT_FOUND: $datiDir"
    Write-Host "Cartella dati non trovata:" $datiDir
}

if ($inputFailure) {
    $reportFile = Join-Path $outputDir "DPI_GUARDIAN_DEMO_REPORT.txt"
    $jsonPath = Join-Path $outputDir "dashboard_data.json"

    @"
DPI GUARDIAN DEMO REPORT
DATA: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

ROOT: $root
DATI: $datiDir
OUTPUT: $outputDir

ESITO:
- Esecuzione interrotta in modalità fail-closed
- Motivo: $inputFailure

==========================================
ESITO DEMO: FAIL
Dashboard collegata: NON_AUTORIZZATA
Report generato: SI
Stato demo: NON_PRESENTABILE
==========================================
"@ | Set-Content -LiteralPath $reportFile -Encoding UTF8

    [pscustomobject]@{
        generated_at  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
        final_status  = "FAIL"
        warning_count = 0
        error_count   = 1
        summary       = $inputFailure
        rows          = @()
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    Write-Error $inputFailure -ErrorAction Continue
    exit 2
}

Write-Host ""
Write-Host "=== CONTROLLO OPERATORI ==="
Write-Host ""

if (Test-Path $operatoriDir) {
    $ops = Get-ChildItem $operatoriDir -Directory

    foreach ($op in $ops) {
        $csv = Join-Path $op.FullName ($op.Name + "_DPI.csv")

        if (Test-Path $csv) {
            Write-Host "OK SCHEDA OPERATORE ->" $op.Name
        }
        else {
            Write-Host "MANCANTE SCHEDA ->" $op.Name
        }
    }
}
else {
    Write-Host "WARNING: cartella operatori non presente, controllo saltato."
}

$reportFile = Join-Path $outputDir "DPI_GUARDIAN_DEMO_REPORT.txt"

@"
DPI GUARDIAN DEMO REPORT
DATA: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

ROOT: $root
DATI: $datiDir
OUTPUT: $outputDir

ESITO:
- Demo eseguita correttamente
- Controllo file dati completato
- Controllo operatori completato o saltato con warning
"@ | Set-Content -Path $reportFile -Encoding UTF8

Write-Host ""
Write-Host "REPORT CREATO:"
Write-Host $reportFile
Write-Host ""

Write-Host "=== FINE CONTROLLO ==="
Write-Host ""
if (Test-Path $reportFile) {
    $finalEsito = "OK"
    $finalStatoDemo = "PRESENTABILE"
    $dashboardCheck = "VERIFICARE AVVIO START_DEMO.bat"

    if (-not (Test-Path $operatoriDir)) {
        $finalEsito = "ATTENZIONE"
        $finalStatoDemo = "PRESENTABILE CON WARNING"
    }

    Add-Content -Path $reportFile -Value ""
    Add-Content -Path $reportFile -Value "=========================================="
    Add-Content -Path $reportFile -Value "ESITO DEMO: $finalEsito"
    Add-Content -Path $reportFile -Value "Dashboard collegata: $dashboardCheck"
    Add-Content -Path $reportFile -Value "Report generato: SI"
    Add-Content -Path $reportFile -Value "Stato demo: $finalStatoDemo"
    Add-Content -Path $reportFile -Value "=========================================="
}
# =========================
# DASHBOARD JSON EXPORT (aligned to current old script)
# Output: ..\02_OUTPUT\dashboard_data.json
# =========================
try {
    $jsonPath = Join-Path $outputDir "dashboard_data.json"

    $dashboardRows = @()

    foreach ($file in $files) {
            $dashboardRows += [pscustomobject]@{
                dpi_id             = $null
                operatore          = $null
                dpi                = $file.BaseName
                modello            = $file.Name
                norma              = $null
                matricola          = $null
                manuale_ok         = $null
                revisione_ok       = $null
                prossima_revisione = $null
                stato_generale     = if (Test-Path $operatoriDir) { "OK" } else { "ATTENZIONE" }
            }
        }

    if ($dashboardRows.Count -eq 0) {
        throw "NO_FILES_PROCESSED"
    }

    $jsonFinalStatus = if (Test-Path $operatoriDir) { "OK" } else { "ATTENZIONE" }
    $jsonWarningCount = if (Test-Path $operatoriDir) { 0 } else { 1 }
    $jsonErrorCount = 0
    $jsonSummary = if (Test-Path $operatoriDir) {
        "Demo eseguita correttamente con struttura dati presente."
    } else {
        "Demo eseguita correttamente, ma cartella operatori assente: controllo completato con warning."
    }

    $dashboardObject = [pscustomobject]@{
        generated_at  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
        final_status  = $jsonFinalStatus
        warning_count = $jsonWarningCount
        error_count   = $jsonErrorCount
        summary       = $jsonSummary
        rows          = $dashboardRows
    }

    $dashboardObject | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8

    Write-Host ""
    Write-Host "[OK] Dashboard JSON creato: $jsonPath"
}
catch {
    Write-Error "DASHBOARD_JSON_EXPORT_FAILED: $($_.Exception.Message)" -ErrorAction Continue
    exit 3
}
# =========================
# END DASHBOARD JSON EXPORT
# =========================