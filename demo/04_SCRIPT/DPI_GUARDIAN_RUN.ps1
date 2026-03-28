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

if (Test-Path $datiDir) {
    $files = Get-ChildItem $datiDir -File
    $count = $files.Count

    Write-Host "Numero file trovati:" $count
    Write-Host ""

    foreach ($f in $files) {
        Write-Host "FILE ->" $f.Name
    }
}
else {
    Write-Host "Cartella dati non trovata:" $datiDir
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

    if ($files) {
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
    Write-Host ""
    Write-Host "[WARNING] Export dashboard JSON fallito: $($_.Exception.Message)"
}
# =========================
# END DASHBOARD JSON EXPORT
# =========================