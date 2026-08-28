$ErrorActionPreference = "Stop"

# Root demo = cartella "demo" (portabile su qualunque PC)
$root = Split-Path -Parent $PSScriptRoot

$datiDir = Join-Path $root "01_DEMO_DATI"
$outputDir = Join-Path $root "02_OUTPUT"
$operatoriDir = Join-Path $datiDir "08_OPERATORI_DPI"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# 4D is opt-in and exact: the historical 4C path remains unchanged unless this exact file exists.
$positiveChainPath = Join-Path $datiDir "DPI_4D_CHAIN.json"
if (Test-Path -LiteralPath $positiveChainPath -PathType Leaf) {
    # 4D R2 has exactly one semantic validator/decision engine, loaded only for the positive path.
    . (Join-Path $PSScriptRoot "DPI_4D_CONTRACT.ps1")

    $decisionPath = Join-Path $outputDir "DPI_4D_DECISION.json"
    $reportFile = Join-Path $outputDir "DPI_GUARDIAN_DEMO_REPORT.txt"

    $positiveFiles = @(Get-ChildItem -LiteralPath $datiDir -File -Recurse -ErrorAction Stop)
    if ($positiveFiles.Count -ne 1 -or -not ($positiveFiles[0].FullName -ceq $positiveChainPath)) {
        [pscustomobject]@{
            ENGINE = "DPI_4D_POSITIVE_CHAIN_MINIMUM"
            CONTRACT_VERSION = "DPI_4D_R2"
            DECISION = "NON_VERIFICATO"
            REASON_CODE = "CARDINALITY_UNSUPPORTED"
            REASON_TEXT_MINIMAL = "4D Minimum accetta un solo DPI_4D_CHAIN.json; nessun input viene ignorato."
            MISSING_LINKS = @("input_inventory")
            SOURCE_REFS = @()
            PROVENANCE = "FAIL"
            DOMAIN_INFERENCE = "ZERO"
            PROVENANCE_TRACE = @()
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $decisionPath -Encoding UTF8
        Write-Error "DPI_4D_CARDINALITY_UNSUPPORTED" -ErrorAction Continue
        exit 4
    }

    try {
        $inputObject = Get-Content -LiteralPath $positiveChainPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $decision = Invoke-Dpi4DDecision $inputObject
        $decision | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $decisionPath -Encoding UTF8

        @"
DPI GUARDIAN 4D R2 POSITIVE CHAIN REPORT
AS_OF_DATE: $($inputObject.as_of_date)

INPUT: $positiveChainPath
OUTPUT: $decisionPath

DECISION: $($decision.DECISION)
REASON_CODE: $($decision.REASON_CODE)
PROVENANCE: $($decision.PROVENANCE)
DOMAIN_INFERENCE: $($decision.DOMAIN_INFERENCE)

==========================================
4D R2 POSITIVE PATH: ACTIVE
STRICT_SCHEMA: ACTIVE
SOURCE_BINDING: ACTIVE
TEMPORAL_COHERENCE: ACTIVE
FAIL-CLOSED: PRESERVED
==========================================
"@ | Set-Content -LiteralPath $reportFile -Encoding UTF8

        Write-Host "DPI_4D_DECISION=$($decision.DECISION)"
        Write-Host "DPI_4D_REASON=$($decision.REASON_CODE)"
        Write-Host "DPI_4D_PROVENANCE=$($decision.PROVENANCE)"
        Write-Host "DPI_4D_DOMAIN_INFERENCE=$($decision.DOMAIN_INFERENCE)"

        if ($decision.DECISION -ceq "NON_VERIFICATO") { exit 4 }
        exit 0
    }
    catch {
        [pscustomobject]@{
            ENGINE = "DPI_4D_POSITIVE_CHAIN_MINIMUM"
            CONTRACT_VERSION = "DPI_4D_R2"
            DECISION = "NON_VERIFICATO"
            REASON_CODE = "STRUCTURED_INPUT_INVALID"
            REASON_TEXT_MINIMAL = $_.Exception.Message
            MISSING_LINKS = @("structured_input")
            SOURCE_REFS = @()
            PROVENANCE = "FAIL"
            DOMAIN_INFERENCE = "ZERO"
            PROVENANCE_TRACE = @()
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $decisionPath -Encoding UTF8

        Write-Error "DPI_4D_STRUCTURED_INPUT_INVALID: $($_.Exception.Message)" -ErrorAction Continue
        exit 3
    }
}

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

    $semanticBlockers = @()

    if (-not (Test-Path -LiteralPath $operatoriDir -PathType Container)) {
        $semanticBlockers += "OPERATOR_DIRECTORY_NOT_FOUND"
    }

    $semanticUnverifiedRows = @(
        $dashboardRows | Where-Object {
            [string]::IsNullOrWhiteSpace([string]$_.dpi_id) -or
            [string]::IsNullOrWhiteSpace([string]$_.operatore) -or
            [string]::IsNullOrWhiteSpace([string]$_.norma) -or
            [string]::IsNullOrWhiteSpace([string]$_.matricola) -or
            $null -eq $_.manuale_ok -or
            $null -eq $_.revisione_ok -or
            [string]::IsNullOrWhiteSpace([string]$_.prossima_revisione)
        }
    )

    if ($semanticUnverifiedRows.Count -gt 0) {
        $semanticBlockers += "SEMANTIC_CORE_NOT_VERIFIED:$($semanticUnverifiedRows.Count)/$($dashboardRows.Count)"
    }

    if ($semanticBlockers.Count -gt 0) {
        $semanticFailure = "SEMANTIC_PRESENTABILITY_BLOCKED: " + ($semanticBlockers -join "; ")

        [pscustomobject]@{
            generated_at  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
            final_status  = "NON_VERIFICATO"
            warning_count = 0
            error_count   = $semanticBlockers.Count
            summary       = $semanticFailure
            rows          = $dashboardRows
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

        @"
DPI GUARDIAN DEMO REPORT
DATA: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

ROOT: $root
DATI: $datiDir
OUTPUT: $outputDir

ESITO:
- File scoperti: $($files.Count)
- Righe dashboard materializzate: $($dashboardRows.Count)
- Presentabilità semantica bloccata in modalità fail-closed
- Motivo: $semanticFailure

==========================================
ESITO DEMO: NON_VERIFICATO
Dashboard collegata: NON_AUTORIZZATA
Report generato: SI
Stato demo: NON_PRESENTABILE
==========================================
"@ | Set-Content -LiteralPath $reportFile -Encoding UTF8

        Write-Error $semanticFailure -ErrorAction Continue
        exit 4
    }

    $dashboardObject = [pscustomobject]@{
        generated_at  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
        final_status  = "OK"
        warning_count = 0
        error_count   = 0
        summary       = "Demo semanticamente verificata."
        rows          = $dashboardRows
    }

    $dashboardObject | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    @"
DPI GUARDIAN DEMO REPORT
DATA: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

ROOT: $root
DATI: $datiDir
OUTPUT: $outputDir

ESITO:
- File scoperti: $($files.Count)
- Righe dashboard materializzate: $($dashboardRows.Count)
- Campi semantici core verificati: SI

==========================================
ESITO DEMO: OK
Dashboard collegata: VERIFICARE AVVIO START_DEMO.bat
Report generato: SI
Stato demo: PRESENTABILE
==========================================
"@ | Set-Content -LiteralPath $reportFile -Encoding UTF8

    Write-Host ""
    Write-Host "[OK] Dashboard JSON creato: $jsonPath"
    Write-Host "REPORT CREATO: $reportFile"
}
catch {
    Write-Error "DASHBOARD_JSON_EXPORT_FAILED: $($_.Exception.Message)" -ErrorAction Continue
    exit 3
}
# =========================
# END DASHBOARD JSON EXPORT
# =========================
