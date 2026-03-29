$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Ensure-CsvHeader {
    param(
        [string]$Path,
        [string[]]$Headers
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        $line = ($Headers -join ",")
        Set-Content -Path $Path -Value $line -Encoding UTF8
    }
}

function Import-CsvSafe {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    try {
        return @(Import-Csv -LiteralPath $Path)
    }
    catch {
        return @()
    }
}

function Sanitize-FileComponent {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "SCONOSCIUTO"
    }

    $value = $Text.Trim()
    $value = $value -replace '[\\\/:\*\?"<>\|]', '_'
    $value = $value -replace '\s+', '_'
    $value = $value -replace '_+', '_'
    $value = $value.Trim('_')

    if ([string]::IsNullOrWhiteSpace($value)) {
        return "SCONOSCIUTO"
    }

    return $value
}

function Get-NormalizedText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $normalized = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    $builder = New-Object System.Text.StringBuilder

    foreach ($char in $normalized.ToCharArray()) {
        $unicodeCategory = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
        if ($unicodeCategory -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($char)
        }
    }

    $value = $builder.ToString().Normalize([System.Text.NormalizationForm]::FormC).ToLowerInvariant()
    $value = $value -replace 'ß', 'ss'
    $value = $value -replace '[\._]', ' '
    $value = $value -replace '-', ' '
    $value = $value -replace '\s+', ' '
    return $value.Trim()
}

function Initialize-V2Paths {
    param(
        [string]$Root,
        [string]$OutputDir
    )

    $supportDir = Join-Path $Root "05_SUPPORTO"
    $sessionId = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $sessionDir = Join-Path $supportDir ("SESSIONE_CLASSIFICAZIONE_" + $sessionId)
    $sessionCopiesDir = Join-Path $sessionDir "COPIE"
    $sessionReportDir = Join-Path $sessionDir "REPORT"

    Ensure-Directory -Path $supportDir
    Ensure-Directory -Path $sessionDir
    Ensure-Directory -Path $sessionCopiesDir
    Ensure-Directory -Path $sessionReportDir

    $trainingCsv = Join-Path $supportDir "TRAINING_INIZIALE_CESARI.csv"
    $masterCsv = Join-Path $supportDir "CATALOGO_DOCUMENTI_MASTER.csv"
    $queueCsv = Join-Path $supportDir "DASHBOARD_QUEUE.csv"
    $sessionCsv = Join-Path $sessionReportDir "CATALOGO_SESSIONE.csv"
    $evidenzeCsv = Join-Path $sessionReportDir "EVIDENZE_OPERATIVE.csv"

    Ensure-CsvHeader -Path $trainingCsv -Headers @(
        "FileOriginale","CategoriaArchivistica","PrioritaDashboard","Soggetto",
        "SerialeMatricola","DataVerifica","ProssimaScadenza","DecisioneUmana","Note"
    )

    Ensure-CsvHeader -Path $masterCsv -Headers @(
        "FileOriginale","NomeCopiaSessione","CategoriaArchivistica","PrioritaDashboard",
        "ContieneDatiOperativi","Soggetto","Dispositivo","SerialeMatricola",
        "DataVerifica","ProssimaScadenza","PercorsoOriginale","PercorsoCopiaLocale",
        "FonteDecisione","ConfidenceArchivio","ConfidenceDashboard","NoteMotore"
    )

    Ensure-CsvHeader -Path $queueCsv -Headers @(
        "FileOriginale","CategoriaArchivistica","PrioritaDashboard","Soggetto",
        "Dispositivo","SerialeMatricola","DataVerifica","ProssimaScadenza",
        "PercorsoOriginale","PercorsoCopiaLocale","NoteMotore"
    )

    Ensure-CsvHeader -Path $sessionCsv -Headers @(
        "FileOriginale","NomeCopiaSessione","CategoriaArchivistica","PrioritaDashboard",
        "ContieneDatiOperativi","Soggetto","Dispositivo","SerialeMatricola",
        "DataVerifica","ProssimaScadenza","PercorsoOriginale","PercorsoCopiaLocale",
        "FonteDecisione","ConfidenceArchivio","ConfidenceDashboard","NoteMotore"
    )

    Ensure-CsvHeader -Path $evidenzeCsv -Headers @(
        "FileOriginale","ContieneDatiOperativi","Segnali","Soggetto",
        "SerialeMatricola","DataVerifica","ProssimaScadenza","NoteMotore"
    )

    return [pscustomobject]@{
        SupportDir      = $supportDir
        SessionDir      = $sessionDir
        SessionCopiesDir = $sessionCopiesDir
        SessionReportDir = $sessionReportDir
        TrainingCsv     = $trainingCsv
        MasterCsv       = $masterCsv
        QueueCsv        = $queueCsv
        SessionCsv      = $sessionCsv
        EvidenzeCsv     = $evidenzeCsv
        SessionId       = $sessionId
    }
}

function Initialize-TrainingInizialeCesari {
    param([string]$TrainingCsv)

    $rows = Import-CsvSafe -Path $TrainingCsv
    $realRows = @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace($_.FileOriginale) })

    if ($realRows.Count -eq 0) {
        Write-Host "[INFO] Training iniziale CESARI predisposto ma non ancora compilato."
    }
    else {
        Write-Host "[OK] Training iniziale CESARI presente: $($realRows.Count) righe."
    }
}

function Import-OperatorAssignmentsMap {
    param([string]$OperatoriDir)

    $map = @()

    if (-not (Test-Path -LiteralPath $OperatoriDir)) {
        return $map
    }

    $ops = Get-ChildItem -LiteralPath $OperatoriDir -Directory -ErrorAction SilentlyContinue
    foreach ($op in $ops) {
        $map += [pscustomobject]@{
            Operatore = $op.Name
            Chiave    = (Get-NormalizedText -Text $op.Name)
        }
    }

    return $map
}

function Get-CategoriaArchivistica {
    param([string]$FileName)

    $name = Get-NormalizedText -Text $FileName

    if ($name -match 'konformitaetserklarung|konformitatserklarung|declaration of conformity|dichiarazione ue|dichiarazione ce|certificate|certificato') {
        return [pscustomobject]@{
            Categoria = "CERTIFICATI"
            Fonte     = "AUTOMATICA"
            Confidence = 95
        }
    }

    if ($name -match 'prufbuch|pruefbuch|inspection|periodic examination|revisione|verifica|maintenance|kontrollbuch') {
        return [pscustomobject]@{
            Categoria = "REVISIONI"
            Fonte     = "AUTOMATICA"
            Confidence = 90
        }
    }

    if ($name -match 'manuale|manual|istruzioni|gebrauchsanleitung|user guide|operating instructions|uso e manutenzione') {
        return [pscustomobject]@{
            Categoria = "MANUALI"
            Fonte     = "AUTOMATICA"
            Confidence = 85
        }
    }

    if ($name -match 'datenblatt|datasheet|scheda tecnica|documentazione tecnica|registro dpi|scadenziario|inventario|matricola|operatore|cliente|dpi') {
        return [pscustomobject]@{
            Categoria = "DOCUMENTI_CLIENTE"
            Fonte     = "AUTOMATICA"
            Confidence = 80
        }
    }

    return [pscustomobject]@{
        Categoria = "DA_VALIDARE"
        Fonte     = "AUTOMATICA"
        Confidence = 40
    }
}

function Get-EvidenzeOperative {
    param(
        [string]$FileName,
        [object[]]$OperatorMap
    )

    $name = Get-NormalizedText -Text $FileName
    $signals = New-Object System.Collections.Generic.List[string]

    if ($name -match 'serial|matricola|seriale') { $signals.Add("SERIALE") }
    if ($name -match 'verifica|revisione|inspection|periodic examination|maintenance') { $signals.Add("VERIFICA") }
    if ($name -match 'prossima|next') { $signals.Add("PROSSIMA_SCADENZA") }
    if ($name -match 'firma|checker|signed') { $signals.Add("FIRMA") }
    if ($name -match 'record|equipment record|storico') { $signals.Add("STORICO") }

    $subject = ""
    foreach ($op in $OperatorMap) {
        if (-not [string]::IsNullOrWhiteSpace($op.Chiave) -and $name -like ("*" + $op.Chiave + "*")) {
            $subject = $op.Operatore
            $signals.Add("OPERATORE")
            break
        }
    }

    $containsOperationalData = $false

    if ($signals.Count -ge 2) {
        $containsOperationalData = $true
    }

    if (($signals -contains "SERIALE") -and ($signals -contains "VERIFICA")) {
        $containsOperationalData = $true
    }

    if (($signals -contains "OPERATORE") -and ($signals -contains "VERIFICA")) {
        $containsOperationalData = $true
    }

    return [pscustomobject]@{
        ContieneDatiOperativi = $containsOperationalData
        Segnali               = ($signals -join "|")
        Soggetto              = $subject
        SerialeMatricola      = "-"
        DataVerifica          = "-"
        ProssimaScadenza      = "-"
        NoteMotore            = if ($containsOperationalData) { "Evidenze operative trovate" } else { "Nessuna evidenza forte" }
        SignalCount           = $signals.Count
    }
}

function Get-DispositivoFromFile {
    param([string]$FileName)

    $name = Get-NormalizedText -Text $FileName

    if ($name -match 'abs 3a') { return 'ABS 3A' }
    if ($name -match '\bhra\b') { return 'HRA' }
    if ($name -match '\bhws\b') { return 'HWS' }
    if ($name -match '\bhwb\b') { return 'HWB' }
    if ($name -match '\bhas\b') { return 'HAS' }
    if ($name -match '\bhps\b') { return 'HPS' }
    if ($name -match '\bacb\b') { return 'ACB' }
    if ($name -match 'db a3r|db-a3r') { return 'DB-A3R' }
    if ($name -match 'db a3|db-a3') { return 'DB-A3' }
    if ($name -match 'db a2|db-a2') { return 'DB-A2' }
    if ($name -match 'ikar') { return 'IKAR' }

    return [System.IO.Path]::GetFileNameWithoutExtension($FileName)
}

function Get-PrioritaDashboard {
    param(
        [string]$CategoriaArchivistica,
        [bool]$ContieneDatiOperativi,
        [int]$SignalCount
    )

    if ($ContieneDatiOperativi) {
        return [pscustomobject]@{
            Priorita   = "DASHBOARD_IMMEDIATA"
            Confidence = 95
        }
    }

    if ($CategoriaArchivistica -eq "REVISIONI") {
        return [pscustomobject]@{
            Priorita   = "DASHBOARD_IMMEDIATA"
            Confidence = 90
        }
    }

    if ($CategoriaArchivistica -eq "DOCUMENTI_CLIENTE" -or $CategoriaArchivistica -eq "CERTIFICATI") {
        return [pscustomobject]@{
            Priorita   = "DASHBOARD_STANDARD"
            Confidence = 75
        }
    }

    return [pscustomobject]@{
        Priorita   = "SOLO_ARCHIVIO"
        Confidence = 60
    }
}

function New-NomeCopiaSessione {
    param(
        [string]$PrioritaDashboard,
        [string]$CategoriaArchivistica,
        [string]$Soggetto,
        [string]$SerialeMatricola,
        [string]$DataVerifica,
        [string]$OriginalName
    )

    $subjectPart = Sanitize-FileComponent -Text $Soggetto
    $serialPart = Sanitize-FileComponent -Text $SerialeMatricola
    $datePart = Sanitize-FileComponent -Text $DataVerifica

    if ($subjectPart -eq "SCONOSCIUTO") { $subjectPart = "SCONOSCIUTO" }
    if ($serialPart -eq "SCONOSCIUTO" -or $serialPart -eq "-") { $serialPart = "NOSERIALE" }
    if ($datePart -eq "SCONOSCIUTO" -or $datePart -eq "-") { $datePart = (Get-Date -Format "yyyy-MM-dd") }

    $baseOriginal = [System.IO.Path]::GetFileNameWithoutExtension($OriginalName)
    $ext = [System.IO.Path]::GetExtension($OriginalName)
    $safeOriginal = Sanitize-FileComponent -Text $baseOriginal

    return ("[{0}]_[{1}]_[{2}]_[{3}]_[{4}]__{5}{6}" -f `
        (Sanitize-FileComponent -Text $PrioritaDashboard), `
        (Sanitize-FileComponent -Text $CategoriaArchivistica), `
        $subjectPart, `
        $serialPart, `
        $datePart, `
        $safeOriginal, `
        $ext)
}

function Export-DashboardJsonCompat {
    param(
        [string]$JsonPath,
        [object[]]$Rows,
        [bool]$OperatorFolderExists
    )

    $warningCount = @($Rows | Where-Object { $_.stato_generale -eq "ATTENZIONE" }).Count
    $errorCount = @($Rows | Where-Object { $_.stato_generale -eq "CRITICO" }).Count

    if ($errorCount -gt 0 -or -not $OperatorFolderExists) {
        $finalStatus = "ATTENZIONE"
    }
    else {
        $finalStatus = "OK"
    }

    $summary = "Demo aggiornata. Record dashboard: $($Rows.Count). Warning: $warningCount. Errori: $errorCount."

    $dashboardObject = [pscustomobject]@{
        generated_at  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
        final_status  = $finalStatus
        warning_count = $warningCount
        error_count   = $errorCount
        summary       = $summary
        rows          = $Rows
    }

    $dashboardObject | ConvertTo-Json -Depth 8 | Set-Content -Path $JsonPath -Encoding UTF8
}

# Root demo = cartella "demo" (portabile su qualunque PC)
$root = Split-Path -Parent $PSScriptRoot

$datiDir = Join-Path $root "01_DEMO_DATI"
$outputDir = Join-Path $root "02_OUTPUT"
$operatoriDir = Join-Path $datiDir "08_OPERATORI_DPI"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$v2 = Initialize-V2Paths -Root $root -OutputDir $outputDir
Initialize-TrainingInizialeCesari -TrainingCsv $v2.TrainingCsv
$operatorMap = Import-OperatorAssignmentsMap -OperatoriDir $operatoriDir

Write-Host ""
Write-Host "=== DPI GUARDIAN DEMO RUN ==="
Write-Host ""

Write-Host "ROOT DEMO:" $root
Write-Host ""

Write-Host "=== CONTROLLO FILE DATI ==="
Write-Host ""

$files = @()

if (Test-Path $datiDir) {
    $files = @(Get-ChildItem $datiDir -Recurse -File | Where-Object { $_.FullName -notlike "*\08_OPERATORI_DPI\*" })
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

$masterRows = @()
$queueRows = @()
$evidenzeRows = @()
$dashboardRows = @()
$counter = 1

foreach ($file in $files) {
    $arch = Get-CategoriaArchivistica -FileName $file.Name
    $evid = Get-EvidenzeOperative -FileName $file.Name -OperatorMap $operatorMap
    $device = Get-DispositivoFromFile -FileName $file.Name
    $prio = Get-PrioritaDashboard -CategoriaArchivistica $arch.Categoria -ContieneDatiOperativi $evid.ContieneDatiOperativi -SignalCount $evid.SignalCount

    $copyName = New-NomeCopiaSessione `
        -PrioritaDashboard $prio.Priorita `
        -CategoriaArchivistica $arch.Categoria `
        -Soggetto $evid.Soggetto `
        -SerialeMatricola $evid.SerialeMatricola `
        -DataVerifica $evid.DataVerifica `
        -OriginalName $file.Name

    $copyPath = Join-Path $v2.SessionCopiesDir $copyName
    Copy-Item -LiteralPath $file.FullName -Destination $copyPath -Force

    $sourceDecision = if ($evid.ContieneDatiOperativi) { "AUTOMATICA_OPERATIVA" } else { $arch.Fonte }

    $row = [pscustomobject]@{
        FileOriginale          = $file.Name
        NomeCopiaSessione      = $copyName
        CategoriaArchivistica  = $arch.Categoria
        PrioritaDashboard      = $prio.Priorita
        ContieneDatiOperativi  = if ($evid.ContieneDatiOperativi) { "SI" } else { "NO" }
        Soggetto               = if ([string]::IsNullOrWhiteSpace($evid.Soggetto)) { "-" } else { $evid.Soggetto }
        Dispositivo            = $device
        SerialeMatricola       = $evid.SerialeMatricola
        DataVerifica           = $evid.DataVerifica
        ProssimaScadenza       = $evid.ProssimaScadenza
        PercorsoOriginale      = $file.FullName
        PercorsoCopiaLocale    = $copyPath
        FonteDecisione         = $sourceDecision
        ConfidenceArchivio     = $arch.Confidence
        ConfidenceDashboard    = $prio.Confidence
        NoteMotore             = $evid.NoteMotore
    }

    $masterRows += $row
    $queueRows += $row

    $evidenzeRows += [pscustomobject]@{
        FileOriginale         = $file.Name
        ContieneDatiOperativi = if ($evid.ContieneDatiOperativi) { "SI" } else { "NO" }
        Segnali               = $evid.Segnali
        Soggetto              = if ([string]::IsNullOrWhiteSpace($evid.Soggetto)) { "-" } else { $evid.Soggetto }
        SerialeMatricola      = $evid.SerialeMatricola
        DataVerifica          = $evid.DataVerifica
        ProssimaScadenza      = $evid.ProssimaScadenza
        NoteMotore            = $evid.NoteMotore
    }

    if ($prio.Priorita -eq "DASHBOARD_IMMEDIATA") {
        $status = "OK"
    }
    elseif ($prio.Priorita -eq "DASHBOARD_STANDARD") {
        $status = "ATTENZIONE"
    }
    else {
        $status = "ATTENZIONE"
    }

    $dashboardRows += [pscustomobject]@{
        dpi_id                  = ("DPI-{0:D3}" -f $counter)
        operatore               = if ([string]::IsNullOrWhiteSpace($evid.Soggetto)) { "-" } else { $evid.Soggetto }
        dpi                     = $device
        modello                 = $file.Name
        norma                   = if ($arch.Categoria -eq "CERTIFICATI") { "Conformita presente" } else { "-" }
        matricola               = $evid.SerialeMatricola
        manuale                 = if ($arch.Categoria -eq "MANUALI") { "SI" } else { "NO" }
        manuale_ok              = if ($arch.Categoria -eq "MANUALI" -or $arch.Categoria -eq "DOCUMENTI_CLIENTE") { "SI" } else { "NO" }
        revisione               = if ($arch.Categoria -eq "REVISIONI") { "SI" } else { "NO" }
        revisione_ok            = if ($arch.Categoria -eq "REVISIONI") { "SI" } else { "NO" }
        prossima_revisione      = if ($evid.ProssimaScadenza -eq "-") { $null } else { $evid.ProssimaScadenza }
        stato_generale          = $status
        categoria_archivistica  = $arch.Categoria
        priorita_dashboard      = $prio.Priorita
        soggetto                = if ([string]::IsNullOrWhiteSpace($evid.Soggetto)) { "-" } else { $evid.Soggetto }
        dispositivo             = $device
        data_verifica           = $evid.DataVerifica
        percorso_originale      = $file.FullName
        percorso_copia_locale   = $copyPath
        nome_file_originale     = $file.Name
        nome_copia_sessione     = $copyName
        contiene_dati_operativi = if ($evid.ContieneDatiOperativi) { "SI" } else { "NO" }
        confidence_archivio     = $arch.Confidence
        confidence_dashboard    = $prio.Confidence
        note_motore             = $evid.NoteMotore
    }

    $counter++
}

$masterRows | Export-Csv -Path $v2.MasterCsv -NoTypeInformation -Encoding UTF8
$queueRows | Export-Csv -Path $v2.QueueCsv -NoTypeInformation -Encoding UTF8
$masterRows | Export-Csv -Path $v2.SessionCsv -NoTypeInformation -Encoding UTF8
$evidenzeRows | Export-Csv -Path $v2.EvidenzeCsv -NoTypeInformation -Encoding UTF8

$reportFile = Join-Path $outputDir "DPI_GUARDIAN_DEMO_REPORT.txt"

$totManuali = @($masterRows | Where-Object { $_.CategoriaArchivistica -eq "MANUALI" }).Count
$totRevisioni = @($masterRows | Where-Object { $_.CategoriaArchivistica -eq "REVISIONI" }).Count
$totCertificati = @($masterRows | Where-Object { $_.CategoriaArchivistica -eq "CERTIFICATI" }).Count
$totDocumenti = @($masterRows | Where-Object { $_.CategoriaArchivistica -eq "DOCUMENTI_CLIENTE" }).Count
$totDaValidare = @($masterRows | Where-Object { $_.CategoriaArchivistica -eq "DA_VALIDARE" }).Count

$dashImmediata = @($masterRows | Where-Object { $_.PrioritaDashboard -eq "DASHBOARD_IMMEDIATA" }).Count
$dashStandard = @($masterRows | Where-Object { $_.PrioritaDashboard -eq "DASHBOARD_STANDARD" }).Count
$soloArchivio = @($masterRows | Where-Object { $_.PrioritaDashboard -eq "SOLO_ARCHIVIO" }).Count

$totOperativi = @($masterRows | Where-Object { $_.ContieneDatiOperativi -eq "SI" }).Count

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

RIEPILOGO V2
- File processati: $($masterRows.Count)
- Manuali: $totManuali
- Revisioni: $totRevisioni
- Certificati: $totCertificati
- Documenti cliente: $totDocumenti
- Da validare: $totDaValidare

PRIORITA DASHBOARD
- Dashboard immediata: $dashImmediata
- Dashboard standard: $dashStandard
- Solo archivio: $soloArchivio

DATI OPERATIVI
- File con dati operativi: $totOperativi

CATALOGHI
- Master: $($v2.MasterCsv)
- Queue: $($v2.QueueCsv)
- Sessione: $($v2.SessionCsv)
- Evidenze: $($v2.EvidenzeCsv)
- Training iniziale: $($v2.TrainingCsv)
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

    if (-not (Test-Path $operatoriDir) -or $totDaValidare -gt 0) {
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

try {
    $jsonPath = Join-Path $outputDir "dashboard_data.json"
    Export-DashboardJsonCompat -JsonPath $jsonPath -Rows $dashboardRows -OperatorFolderExists:(Test-Path $operatoriDir)

    Write-Host ""
    Write-Host "[OK] Dashboard JSON creato: $jsonPath"
}
catch {
    Write-Host ""
    Write-Host "[WARNING] Export dashboard JSON fallito: $($_.Exception.Message)"
}