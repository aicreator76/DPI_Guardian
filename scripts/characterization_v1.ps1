$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$jsonPath = Join-Path $repoRoot 'demo/03_PRESENTAZIONE/console/dashboard_data.json'
$pdfDir = Join-Path $repoRoot 'demo/03_PRESENTAZIONE/console/pdf'
$failures = [System.Collections.Generic.List[string]]::new()
function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { $failures.Add($Message) } }
Require (Test-Path -LiteralPath $jsonPath -PathType Leaf) 'dashboard_data.json missing'
if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf)) { Write-Host 'CHARACTERIZATION_V1=FAIL'; exit 1 }
try { $data = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json } catch { Write-Host 'JSON_VALID=NO'; Write-Host 'CHARACTERIZATION_V1=FAIL'; exit 1 }
Write-Host 'MODE=CHARACTERIZATION'
Write-Host 'JSON_VALID=SI'
$rootFields=@('generated_at','summary','final_status','rows'); foreach($f in $rootFields){Require ($null -ne $data.PSObject.Properties[$f]) "root field missing: $f"}
Require ($data.rows -is [System.Array]) 'rows is not array'
$expectedFields=@('id','dpi_id','operatore','produttore','famiglia_prodotto','dpi','modello','variante','norma','seriale','matricola','stato_verifica_modello','manuale_famiglia','manuale','manuale_ok','scheda_prodotto_specifica','scheda_prodotto','revisione_specifica','revisione','revisione_ok','dichiarazione_conformita_specifica','certificato','documentazione_sessione','prossima_revisione','prossima_scadenza','stato_generale','file_collegati_count','file_collegati','allegati','nota_operativa')|Sort-Object
$rows=@($data.rows); $colosioRows=@($rows|Where-Object{$_.operatore -eq 'Andrea Colosio'}); $rossiniRows=@($rows|Where-Object{$_.operatore -match 'Rossini' -or $_.id -match '^ROSSINI'})
$missingRefs=[System.Collections.Generic.List[string]]::new(); $unlinked=[System.Collections.Generic.List[string]]::new(); $pdfFields=@('manuale_famiglia','manuale','scheda_prodotto_specifica','scheda_prodotto','revisione_specifica','revisione','dichiarazione_conformita_specifica','certificato','documentazione_sessione')
foreach($row in $rows){
 $actual=@($row.PSObject.Properties.Name|Sort-Object); Require ((Compare-Object $expectedFields $actual).Count -eq 0) "$($row.id): field set differs"
 Require (($row.file_collegati_count -is [int])-or($row.file_collegati_count -is [long])) "$($row.id): count not integer"; Require ($row.file_collegati -is [System.Array]) "$($row.id): file_collegati not array"; Require ($row.allegati -is [System.Array]) "$($row.id): allegati not array"
 foreach($ref in @($row.file_collegati)){if(-not(Test-Path -LiteralPath (Join-Path $pdfDir $ref) -PathType Leaf)){$missingRefs.Add("$($row.id):$ref")}}
 foreach($field in $pdfFields){$v=$row.$field;if($v -is [string] -and -not [string]::IsNullOrWhiteSpace($v) -and $v -notin @($row.file_collegati)){$unlinked.Add("$($row.id):$field=$v")}}
}
$pdfFiles=@(Get-ChildItem -LiteralPath $pdfDir -File -Filter '*.pdf');$empty=@($pdfFiles|Where-Object Length -eq 0);$nonEmpty=@($pdfFiles|Where-Object Length -gt 0);$colosioPdf=@($pdfFiles|Where-Object Name -like 'Colosio_*');$rossiniPdf=@($pdfFiles|Where-Object{$_.Name -match 'Rossini'})
$hashRows=foreach($p in $nonEmpty){[pscustomobject]@{Name=$p.Name;Hash=(Get-FileHash -LiteralPath $p.FullName -Algorithm SHA256).Hash}};$dups=@($hashRows|Group-Object Hash|Where-Object Count -gt 1)
$result=[ordered]@{mode='CHARACTERIZATION';colosio_json=$colosioRows.Count;rossini_json=$rossiniRows.Count;colosio_pdf=$colosioPdf.Count;rossini_pdf=$rossiniPdf.Count;pdf_non_vuoti=$nonEmpty.Count;pdf_vuoti=$empty.Count;duplicati_contenuto=$dups.Count;riferimenti_mancanti=$missingRefs.Count;campi_pdf_non_collegati=$unlinked.Count}
foreach($k in $result.Keys){Write-Host "$($k.ToString().ToUpper())=$($result[$k])"};foreach($p in $empty){Write-Host "PDF_VUOTO=$($p.Name)"};foreach($g in $dups){Write-Host "DUPLICATO_SHA256=$($g.Name);FILES=$(@($g.Group.Name)-join '|')"};foreach($x in $unlinked){Write-Host "CAMPO_PDF_NON_COLLEGATO=$x"}
Write-Host ('CHARACTERIZATION_JSON='+($result|ConvertTo-Json -Compress))
if($failures.Count -gt 0){foreach($x in $failures){Write-Host "CHARACTERIZATION_FAIL=$x"};Write-Host 'CHARACTERIZATION_V1=FAIL';exit 1}
Write-Host 'CHARACTERIZATION_V1=PASS';exit 0
