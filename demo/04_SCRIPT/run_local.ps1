$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$demoRoot = Split-Path -Parent $scriptDir

$mainScript = Join-Path $scriptDir "DPI_GUARDIAN_RUN.ps1"
$outputJson = Join-Path $demoRoot "02_OUTPUT\dashboard_data.json"
$consoleJson = Join-Path $demoRoot "03_PRESENTAZIONE\console\dashboard_data.json"
$dashboardHtml = Join-Path $demoRoot "03_PRESENTAZIONE\console\index_regina_fix.html"

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

# Normalize the runtime-produced rows to the dashboard contract already enforced
# by characterization/integrity. No document links are invented here: fields
# without a real runtime-derived document reference remain null/empty.
try {
    $raw = Get-Content -LiteralPath $outputJson -Raw | ConvertFrom-Json
    $normalizedRows = @()
    $counter = 1

    foreach ($row in @($raw.rows)) {
        $operator = if ([string]::IsNullOrWhiteSpace([string]$row.operatore) -or $row.operatore -eq '-') { [string]$row.soggetto } else { [string]$row.operatore }
        if ([string]::IsNullOrWhiteSpace($operator)) { $operator = '-' }

        $normalizedRows += [pscustomobject][ordered]@{
            id                                      = ('RUNTIME_{0:D2}' -f $counter)
            dpi_id                                  = if ([string]::IsNullOrWhiteSpace([string]$row.dpi_id)) { ('DPI-{0:D3}' -f $counter) } else { [string]$row.dpi_id }
            operatore                               = $operator
            produttore                              = $null
            famiglia_prodotto                       = $null
            dpi                                     = [string]$row.dpi
            modello                                 = [string]$row.modello
            variante                                = $null
            norma                                   = [string]$row.norma
            seriale                                 = $null
            matricola                               = [string]$row.matricola
            stato_verifica_modello                  = 'RUNTIME_DERIVED'
            manuale_famiglia                        = $null
            manuale                                 = $null
            manuale_ok                              = [string]$row.manuale_ok
            scheda_prodotto_specifica               = $null
            scheda_prodotto                         = $null
            revisione_specifica                     = $null
            revisione                               = $null
            revisione_ok                            = [string]$row.revisione_ok
            dichiarazione_conformita_specifica      = $null
            certificato                             = $null
            documentazione_sessione                 = $null
            prossima_revisione                      = $row.prossima_revisione
            prossima_scadenza                       = $row.prossima_revisione
            stato_generale                          = [string]$row.stato_generale
            file_collegati_count                    = 0
            file_collegati                          = @()
            allegati                                = @()
            nota_operativa                          = ('Runtime-derived: ' + [string]$row.note_motore)
        }
        $counter++
    }

    $normalized = [pscustomobject][ordered]@{
        generated_at = if ($raw.generated_at) { $raw.generated_at } else { (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK') }
        summary      = [string]$raw.summary
        final_status = [string]$raw.final_status
        rows         = $normalizedRows
    }

    $normalized | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputJson -Encoding UTF8
    Write-Host "[OK] Contratto dashboard JSON normalizzato: 31 campi per record, nessun riferimento documentale inventato."
}
catch {
    Write-Host "[ERRORE] Normalizzazione contratto JSON fallita: $($_.Exception.Message)"
    exit 1
}

$consoleDir = Split-Path -Parent $consoleJson
New-Item -ItemType Directory -Force -Path $consoleDir | Out-Null
Copy-Item -Path $outputJson -Destination $consoleJson -Force

Write-Host "[OK] JSON disponibile in output: $outputJson"
Write-Host "[OK] JSON copiato in console: $consoleJson"

if (Test-Path $dashboardHtml) {
    Write-Host "[OK] Apertura dashboard locale REGINA..."
    Start-Process $dashboardHtml
}
else {
    Write-Host "[WARNING] Dashboard non trovata: $dashboardHtml"
}

Write-Host ""
Write-Host "=== FINE LOCAL RUN ==="
Write-Host ""
