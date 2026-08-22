$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$jsonPath = Join-Path $repoRoot 'demo/03_PRESENTAZIONE/console/dashboard_data.json'
$pdfDir = (Resolve-Path (Join-Path $repoRoot 'demo/03_PRESENTAZIONE/console/pdf')).Path
$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
function Require([bool]$ok,[string]$message) { if (-not $ok) { $failures.Add($message) } }

Require (Test-Path -LiteralPath $jsonPath -PathType Leaf) 'dashboard_data.json missing'
try { $data = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json }
catch { $failures.Add("invalid JSON: $($_.Exception.Message)"); $data = $null }

$required = @('id','dpi_id','operatore','dpi','modello','file_collegati_count','file_collegati','allegati','stato_generale')
$pdfFields = @('manuale_famiglia','manuale','scheda_prodotto_specifica','scheda_prodotto','revisione_specifica','revisione','dichiarazione_conformita_specifica','certificato','documentazione_sessione')
$missingRefs = [System.Collections.Generic.List[string]]::new()
$pathTraversal = [System.Collections.Generic.List[string]]::new()
$emptyReferenced = [System.Collections.Generic.List[string]]::new()
$unlinkedFields = [System.Collections.Generic.List[string]]::new()
$allRefs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$rows = if ($null -ne $data -and $data.rows -is [System.Array]) { @($data.rows) } else { @() }
Require ($null -ne $data) 'JSON object unavailable'
Require ($data.rows -is [System.Array]) 'rows is not array'

$ids = @($rows.id); $dpiIds = @($rows.dpi_id)
Require ((@($ids | Group-Object | Where-Object Count -gt 1)).Count -eq 0) 'duplicate id detected'
Require ((@($dpiIds | Group-Object | Where-Object Count -gt 1)).Count -eq 0) 'duplicate dpi_id detected'

foreach ($row in $rows) {
  foreach ($f in $required) { Require ($null -ne $row.PSObject.Properties[$f]) "$($row.id): missing required field $f" }
  Require (($row.file_collegati_count -is [int]) -or ($row.file_collegati_count -is [long])) "$($row.id): file_collegati_count not integer"
  Require ($row.file_collegati -is [System.Array]) "$($row.id): file_collegati not array"
  Require ($row.allegati -is [System.Array]) "$($row.id): allegati not array"
  $refs = @($row.file_collegati)
  Require ($row.file_collegati_count -eq $refs.Count) "$($row.id): file_collegati_count mismatch"
  Require ((@($refs | Group-Object | Where-Object Count -gt 1)).Count -eq 0) "$($row.id): duplicate inside file_collegati"
  foreach ($ref in $refs) {
    if (-not ($ref -is [string]) -or [string]::IsNullOrWhiteSpace($ref)) { $failures.Add("$($row.id): invalid PDF reference type"); continue }
    [void]$allRefs.Add($ref)
    $candidate = [IO.Path]::GetFullPath((Join-Path $pdfDir $ref))
    $inside = $candidate.StartsWith($pdfDir + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
    if ([IO.Path]::IsPathRooted($ref) -or $ref -match '(^|[\\/])\.\.([\\/]|$)' -or -not $inside) { $pathTraversal.Add("$($row.id):$ref"); continue }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { $missingRefs.Add("$($row.id):$ref"); continue }
    if ((Get-Item -LiteralPath $candidate).Length -le 0) { $emptyReferenced.Add("$($row.id):$ref") }
  }
  foreach ($field in $pdfFields) {
    $v = $row.$field
    if ($v -is [string] -and -not [string]::IsNullOrWhiteSpace($v) -and $v -notin $refs) { $unlinkedFields.Add("$($row.id):$field=$v") }
  }
}

$pdfFiles = @(Get-ChildItem -LiteralPath $pdfDir -File -Filter '*.pdf')
$emptyPdfs = @($pdfFiles | Where-Object Length -eq 0)
$unreferenced = @($pdfFiles | Where-Object { -not $allRefs.Contains($_.Name) })
$hashRows = foreach ($pdf in @($pdfFiles | Where-Object Length -gt 0)) { [pscustomobject]@{Name=$pdf.Name;Hash=(Get-FileHash -LiteralPath $pdf.FullName -Algorithm SHA256).Hash} }
$duplicateGroups = @($hashRows | Group-Object Hash | Where-Object Count -gt 1)
$colosioJson = @($rows | Where-Object { $_.operatore -eq 'Andrea Colosio' -or $_.id -match '^COLOSIO' }).Count
$rossiniJson = @($rows | Where-Object { $_.operatore -match 'Rossini' -or $_.id -match '^ROSSINI' }).Count
$colosioPdf = @($pdfFiles | Where-Object Name -like 'Colosio_*').Count
$rossiniPdf = @($pdfFiles | Where-Object { $_.Name -match 'Rossini' }).Count

Require ($missingRefs.Count -eq 0) 'missing PDF references detected'
Require ($pathTraversal.Count -eq 0) 'path traversal detected'
Require ($emptyReferenced.Count -eq 0) 'empty referenced PDFs detected'
Require ($emptyPdfs.Count -eq 0) 'empty PDFs present in real-document directory'
Require ($duplicateGroups.Count -eq 0) 'duplicate PDF content detected under different names'
Require ($unlinkedFields.Count -eq 0) 'populated PDF fields absent from file_collegati'

$result = [ordered]@{
  mode='INTEGRITY'; json_valid=($null -ne $data); records=$rows.Count; colosio_json=$colosioJson; rossini_json=$rossiniJson;
  colosio_pdf=$colosioPdf; rossini_pdf=$rossiniPdf; pdf_total=$pdfFiles.Count; pdf_vuoti=$emptyPdfs.Count;
  riferimenti_mancanti=$missingRefs.Count; path_traversal=$pathTraversal.Count; pdf_non_referenziati=$unreferenced.Count;
  duplicati_contenuto=$duplicateGroups.Count; duplicati_fuorvianti=$duplicateGroups.Count; campi_pdf_non_collegati=$unlinkedFields.Count;
  failures=$failures.Count
}
Write-Host "MODE=INTEGRITY"
foreach ($k in $result.Keys) { Write-Host "$($k.ToString().ToUpper())=$($result[$k])" }
foreach ($p in $unreferenced) { Write-Host "PDF_NON_REFERENZIATO=$($p.Name)" }
foreach ($g in $duplicateGroups) { Write-Host "DUPLICATO_SHA256=$($g.Name);FILES=$(@($g.Group.Name) -join '|')" }
foreach ($x in $unlinkedFields) { Write-Host "CAMPO_PDF_NON_COLLEGATO=$x" }
foreach ($x in $failures) { Write-Host "INTEGRITY_FAIL=$x" }
Write-Host ('INTEGRITY_JSON=' + ($result | ConvertTo-Json -Compress))
if ($failures.Count -gt 0) { Write-Host 'INTEGRITY_V1=FAIL'; exit 1 }
Write-Host 'INTEGRITY_V1=PASS'
exit 0
