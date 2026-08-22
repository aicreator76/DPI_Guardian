$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$jsonPath = Join-Path $repoRoot 'demo/03_PRESENTAZIONE/console/dashboard_data.json'
$pdfDir = Join-Path $repoRoot 'demo/03_PRESENTAZIONE/console/pdf'
$failures = [System.Collections.Generic.List[string]]::new()
$observations = [System.Collections.Generic.List[string]]::new()

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $failures.Add($Message) }
}

Require (Test-Path -LiteralPath $jsonPath -PathType Leaf) 'dashboard_data.json missing'
if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf)) {
    Write-Host 'CHARACTERIZATION_V1=FAIL'
    Write-Host 'RIFERIMENTI_MANCANTI=1'
    exit 1
}

try { $data = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json }
catch {
    Write-Host 'CHARACTERIZATION_V1=FAIL'
    Write-Host 'JSON_VALID=NO'
    Write-Host "ERROR=$($_.Exception.Message)"
    exit 1
}
Write-Host 'JSON_VALID=SI'

$rootFields = @('generated_at','summary','final_status','rows')
foreach ($field in $rootFields) { Require ($null -ne $data.PSObject.Properties[$field]) "root field missing: $field" }
Require ($data.rows -is [System.Array]) 'rows is not an array'

$expectedFields = @(
'id','dpi_id','operatore','produttore','famiglia_prodotto','dpi','modello','variante','norma','seriale','matricola',
'stato_verifica_modello','manuale_famiglia','manuale','manuale_ok','scheda_prodotto_specifica','scheda_prodotto',
'revisione_specifica','revisione','revisione_ok','dichiarazione_conformita_specifica','certificato','documentazione_sessione',
'prossima_revisione','prossima_scadenza','stato_generale','file_collegati_count','file_collegati','allegati','nota_operativa'
) | Sort-Object

$rows = @($data.rows)
$colosioRows = @($rows | Where-Object { $_.operatore -eq 'Andrea Colosio' })
$rossiniRows = @($rows | Where-Object { $_.operatore -match 'Rossini' -or $_.id -match '^ROSSINI' })
Require ($rows.Count -eq 5) "baseline rows expected 5, got $($rows.Count)"
Require ($colosioRows.Count -eq 5) "baseline Andrea Colosio expected 5, got $($colosioRows.Count)"
Require ($rossiniRows.Count -eq 0) "baseline Rossini expected 0, got $($rossiniRows.Count)"
$expectedIds = 1..5 | ForEach-Object { 'COLOSIO_{0:D2}' -f $_ }
$actualIds = @($rows.id | Sort-Object)
Require ((Compare-Object $expectedIds $actualIds).Count -eq 0) "baseline IDs differ: $($actualIds -join ',')"

$pdfFieldNames = @('manuale_famiglia','manuale','scheda_prodotto_specifica','scheda_prodotto','revisione_specifica','revisione','dichiarazione_conformita_specifica','certificato','documentazione_sessione')
$missingRefs = [System.Collections.Generic.List[string]]::new()
$unlinkedPdfFields = [System.Collections.Generic.List[string]]::new()

foreach ($row in $rows) {
    $actualFields = @($row.PSObject.Properties.Name | Sort-Object)
    Require ((Compare-Object $expectedFields $actualFields).Count -eq 0) "$($row.id): field set differs"
    Require (($row.file_collegati_count -is [int]) -or ($row.file_collegati_count -is [long])) "$($row.id): file_collegati_count is not integer"
    Require ($row.file_collegati -is [System.Array]) "$($row.id): file_collegati is not array"
    Require ($row.allegati -is [System.Array]) "$($row.id): allegati is not array"
    Require ($row.file_collegati_count -eq @($row.file_collegati).Count) "$($row.id): file_collegati_count mismatch"

    foreach ($ref in @($row.file_collegati)) {
        $target = Join-Path $pdfDir $ref
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            $missingRefs.Add("$($row.id):$ref")
        } elseif ((Get-Item -LiteralPath $target).Length -le 0) {
            $failures.Add("$($row.id): referenced PDF empty: $ref")
        }
    }

    foreach ($field in $pdfFieldNames) {
        $value = $row.$field
        if ($value -is [string] -and -not [string]::IsNullOrWhiteSpace($value) -and $value -notin @($row.file_collegati)) {
            $unlinkedPdfFields.Add("$($row.id):$field=$value")
        }
    }
}

$pdfFiles = @(Get-ChildItem -LiteralPath $pdfDir -File -Filter '*.pdf')
$emptyPdfs = @($pdfFiles | Where-Object Length -eq 0)
$nonEmptyPdfs = @($pdfFiles | Where-Object Length -gt 0)
$colosioPdfs = @($pdfFiles | Where-Object Name -like 'Colosio_*')
$rossiniPdfs = @($pdfFiles | Where-Object { $_.Name -match 'Rossini_Davide' })

$hashRows = foreach ($pdf in $nonEmptyPdfs) {
    [pscustomobject]@{ Name = $pdf.Name; Hash = (Get-FileHash -LiteralPath $pdf.FullName -Algorithm SHA256).Hash }
}
$duplicateGroups = @($hashRows | Group-Object Hash | Where-Object Count -gt 1)

Write-Host "COLOSIO_JSON=$($colosioRows.Count)"
Write-Host "ROSSINI_JSON=$($rossiniRows.Count)"
Write-Host "COLOSIO_PDF=$($colosioPdfs.Count)"
Write-Host "ROSSINI_PDF=$($rossiniPdfs.Count)"
Write-Host "PDF_NON_VUOTI=$($nonEmptyPdfs.Count)"
Write-Host "PDF_VUOTI=$($emptyPdfs.Count)"
Write-Host "DUPLICATI_CONTENUTO=$($duplicateGroups.Count)"
Write-Host "RIFERIMENTI_MANCANTI=$($missingRefs.Count)"
Write-Host "CAMPI_PDF_VALORIZZATI_NON_COLLEGATI=$($unlinkedPdfFields.Count)"

foreach ($pdf in $emptyPdfs | Sort-Object Name) { Write-Host "PDF_VUOTO=$($pdf.Name)" }
foreach ($group in $duplicateGroups) {
    $names = @($group.Group.Name | Sort-Object)
    Write-Host "DUPLICATO_SHA256=$($group.Name);FILES=$($names -join '|')"
}
foreach ($item in $missingRefs) { Write-Host "RIFERIMENTO_MANCANTE=$item" }
foreach ($item in $unlinkedPdfFields) { Write-Host "CAMPO_PDF_NON_COLLEGATO=$item" }

# Baseline anomalies are expected characterization observations, not suite failures.
Require ($colosioPdfs.Count -eq 7) "baseline Colosio PDFs expected 7, got $($colosioPdfs.Count)"
Require ($rossiniPdfs.Count -eq 12) "baseline Rossini PDFs expected 12, got $($rossiniPdfs.Count)"
Require ($nonEmptyPdfs.Count -eq 7) "baseline non-empty PDFs expected 7, got $($nonEmptyPdfs.Count)"
Require ($emptyPdfs.Count -eq 12) "baseline empty PDFs expected 12, got $($emptyPdfs.Count)"
Require ($duplicateGroups.Count -eq 2) "baseline duplicate content groups expected 2, got $($duplicateGroups.Count)"
Require ($missingRefs.Count -eq 0) "baseline missing references expected 0, got $($missingRefs.Count)"
Require ($unlinkedPdfFields.Count -eq 4) "baseline populated PDF fields outside file_collegati expected 4, got $($unlinkedPdfFields.Count)"

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host "ASSERTION_FAIL=$failure" }
    Write-Host 'CHARACTERIZATION_V1=FAIL'
    exit 1
}

Write-Host 'BASELINE_ANOMALIES_DETECTED=SI'
Write-Host 'CHARACTERIZATION_V1=PASS'
exit 0
