$ErrorActionPreference = "Stop"

function Get-Dpi4DProperty {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Test-Dpi4DText {
    param($Value)
    return -not [string]::IsNullOrWhiteSpace([string]$Value)
}

function Get-Dpi4DNodeValue {
    param($InputObject, [string]$Name)
    $node = Get-Dpi4DProperty $InputObject $Name
    return Get-Dpi4DProperty $node "value"
}

function Test-Dpi4DProvenance {
    param($Object, [bool]$AuthorityRequired = $false)
    if ($null -eq $Object) { return $false }
    if (-not (Test-Dpi4DText (Get-Dpi4DProperty $Object "source_ref"))) { return $false }
    if (-not (Test-Dpi4DText (Get-Dpi4DProperty $Object "source_version"))) { return $false }
    if ($AuthorityRequired -and -not (Test-Dpi4DText (Get-Dpi4DProperty $Object "authority_ref"))) { return $false }
    return $true
}

function Test-Dpi4DRelation {
    param(
        $Relation,
        [string]$ExpectedFrom,
        [string]$ExpectedTo,
        [string]$ExpectedStatus = "",
        [bool]$AuthorityRequired = $true
    )

    if ($null -eq $Relation) { return $false }
    if (-not (Test-Dpi4DProvenance $Relation $AuthorityRequired)) { return $false }

    $actualFrom = [string](Get-Dpi4DProperty $Relation "from")
    $actualTo = [string](Get-Dpi4DProperty $Relation "to")
    if (-not ($actualFrom -ceq $ExpectedFrom)) { return $false }
    if (-not ($actualTo -ceq $ExpectedTo)) { return $false }

    if (Test-Dpi4DText $ExpectedStatus) {
        $actualStatus = [string](Get-Dpi4DProperty $Relation "status")
        if (-not ($actualStatus -ceq $ExpectedStatus)) { return $false }
    }

    return $true
}

function Get-Dpi4DSourceRefs {
    param($InputObject)

    $refs = @()
    $topSource = Get-Dpi4DProperty $InputObject "source_ref"
    if (Test-Dpi4DText $topSource) { $refs += [string]$topSource }

    foreach ($name in @("worker_ref", "job_role_id", "risk_id", "requirement_id", "ppe_type_id", "assigned_ppe", "evidence_ref", "validity")) {
        $node = Get-Dpi4DProperty $InputObject $name
        $ref = Get-Dpi4DProperty $node "source_ref"
        if (Test-Dpi4DText $ref) { $refs += [string]$ref }
    }

    $relations = Get-Dpi4DProperty $InputObject "relations"
    foreach ($name in @("worker_job_role", "job_role_risk", "risk_requirement", "requirement_ppe", "worker_ppe_assignment", "assignment_evidence")) {
        $relation = Get-Dpi4DProperty $relations $name
        $ref = Get-Dpi4DProperty $relation "source_ref"
        if (Test-Dpi4DText $ref) { $refs += [string]$ref }
    }

    return @($refs | Sort-Object -Unique)
}

function Get-Dpi4DProvenanceTrace {
    param($InputObject)

    $trace = @()
    foreach ($name in @("worker_ref", "job_role_id", "risk_id", "requirement_id", "ppe_type_id", "assigned_ppe", "evidence_ref", "validity")) {
        $node = Get-Dpi4DProperty $InputObject $name
        if ($null -ne $node) {
            $trace += [pscustomobject]@{
                LINK = $name
                VALUE = Get-Dpi4DProperty $node "value"
                SOURCE_REF = Get-Dpi4DProperty $node "source_ref"
                SOURCE_VERSION = Get-Dpi4DProperty $node "source_version"
                VALID_FROM = Get-Dpi4DProperty $node "valid_from"
                VALID_TO = Get-Dpi4DProperty $node "valid_to"
                AUTHORITY_REF = Get-Dpi4DProperty $node "authority_ref"
            }
        }
    }

    $relations = Get-Dpi4DProperty $InputObject "relations"
    foreach ($name in @("worker_job_role", "job_role_risk", "risk_requirement", "requirement_ppe", "worker_ppe_assignment", "assignment_evidence")) {
        $relation = Get-Dpi4DProperty $relations $name
        if ($null -ne $relation) {
            $value = "{0}->{1}" -f (Get-Dpi4DProperty $relation "from"), (Get-Dpi4DProperty $relation "to")
            $status = Get-Dpi4DProperty $relation "status"
            if (Test-Dpi4DText $status) { $value = "$value [$status]" }
            $trace += [pscustomobject]@{
                LINK = $name
                VALUE = $value
                SOURCE_REF = Get-Dpi4DProperty $relation "source_ref"
                SOURCE_VERSION = Get-Dpi4DProperty $relation "source_version"
                VALID_FROM = Get-Dpi4DProperty $relation "valid_from"
                VALID_TO = Get-Dpi4DProperty $relation "valid_to"
                AUTHORITY_REF = Get-Dpi4DProperty $relation "authority_ref"
            }
        }
    }

    return @($trace)
}

function New-Dpi4DDecision {
    param(
        $InputObject,
        [string]$Decision,
        [string]$ReasonCode,
        [string]$ReasonText,
        [string[]]$MissingLinks = @(),
        [string]$Provenance = "PARTIAL"
    )

    return [pscustomobject]@{
        ENGINE = "DPI_4D_POSITIVE_CHAIN_MINIMUM"
        CONTRACT_VERSION = "DPI_4D_V1"
        CASE_ID = Get-Dpi4DProperty $InputObject "case_id"
        DECISION = $Decision
        REASON_CODE = $ReasonCode
        REASON_TEXT_MINIMAL = $ReasonText
        MISSING_LINKS = @($MissingLinks)
        SOURCE_REFS = @(Get-Dpi4DSourceRefs $InputObject)
        PROVENANCE = $Provenance
        DOMAIN_INFERENCE = "ZERO"
        PROVENANCE_TRACE = @(Get-Dpi4DProvenanceTrace $InputObject)
    }
}

function Invoke-Dpi4DDecision {
    param($InputObject)

    if (-not (Test-Dpi4DText (Get-Dpi4DProperty $InputObject "source_ref"))) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "SOURCE_REF_NOT_PROVEN" "Top-level source_ref mancante." @("source_ref") "FAIL"
    }

    $workerNode = Get-Dpi4DProperty $InputObject "worker_ref"
    $roleNode = Get-Dpi4DProperty $InputObject "job_role_id"
    $riskNode = Get-Dpi4DProperty $InputObject "risk_id"
    $requirementNode = Get-Dpi4DProperty $InputObject "requirement_id"
    $ppeNode = Get-Dpi4DProperty $InputObject "ppe_type_id"
    $assignmentNode = Get-Dpi4DProperty $InputObject "assigned_ppe"
    $evidenceNode = Get-Dpi4DProperty $InputObject "evidence_ref"
    $validityNode = Get-Dpi4DProperty $InputObject "validity"
    $relations = Get-Dpi4DProperty $InputObject "relations"

    $worker = [string](Get-Dpi4DProperty $workerNode "value")
    $role = [string](Get-Dpi4DProperty $roleNode "value")
    $risk = [string](Get-Dpi4DProperty $riskNode "value")
    $requirement = [string](Get-Dpi4DProperty $requirementNode "value")
    $ppeType = [string](Get-Dpi4DProperty $ppeNode "value")

    if (-not (Test-Dpi4DText $worker) -or -not (Test-Dpi4DProvenance $workerNode $true)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "WORKER_NOT_PROVEN" "Worker non provato con provenienza." @("worker_ref") "FAIL"
    }
    if (-not (Test-Dpi4DText $role) -or -not (Test-Dpi4DProvenance $roleNode $true)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "WORKER_JOB_ROLE_NOT_PROVEN" "Job role non provato; nessuna sostituzione da department." @("job_role_id") "FAIL"
    }
    if (-not (Test-Dpi4DRelation (Get-Dpi4DProperty $relations "worker_job_role") $worker $role "" $true)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "WORKER_JOB_ROLE_NOT_PROVEN" "Relazione worker-job_role non provata esattamente." @("worker_job_role") "PARTIAL"
    }

    if (-not (Test-Dpi4DText $risk) -or -not (Test-Dpi4DProvenance $riskNode $true)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "JOB_ROLE_RISK_NOT_PROVEN" "Risk non provato con provenienza." @("risk_id") "PARTIAL"
    }
    if (-not (Test-Dpi4DRelation (Get-Dpi4DProperty $relations "job_role_risk") $role $risk "" $true)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "JOB_ROLE_RISK_NOT_PROVEN" "Relazione job_role-risk non provata esattamente." @("job_role_risk") "PARTIAL"
    }

    if (-not (Test-Dpi4DText $requirement) -or -not (Test-Dpi4DProvenance $requirementNode $true)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "RISK_REQUIREMENT_NOT_PROVEN" "Requirement non provato o non autoritativo." @("requirement_id") "PARTIAL"
    }
    if (-not (Test-Dpi4DRelation (Get-Dpi4DProperty $relations "risk_requirement") $risk $requirement "" $true)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "RISK_REQUIREMENT_NOT_PROVEN" "Relazione risk-requirement non provata esattamente." @("risk_requirement") "PARTIAL"
    }

    if (-not (Test-Dpi4DText $ppeType) -or -not (Test-Dpi4DProvenance $ppeNode $false)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "REQUIREMENT_PPE_NOT_PROVEN" "Tipo DPI richiesto non provato." @("ppe_type_id") "PARTIAL"
    }
    if (-not (Test-Dpi4DRelation (Get-Dpi4DProperty $relations "requirement_ppe") $requirement $ppeType "" $true)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "REQUIREMENT_PPE_NOT_PROVEN" "Relazione requirement-ppe_type non provata esattamente." @("requirement_ppe") "PARTIAL"
    }

    $assignmentState = [string](Get-Dpi4DProperty $assignmentNode "value")
    if (-not (Test-Dpi4DProvenance $assignmentNode $true) -or -not (($assignmentState -ceq "ASSIGNED") -or ($assignmentState -ceq "NOT_ASSIGNED"))) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "ASSIGNMENT_NOT_PROVEN" "Assegnazione non provata; UNKNOWN non diventa GAP." @("assigned_ppe") "PARTIAL"
    }
    if (-not (Test-Dpi4DRelation (Get-Dpi4DProperty $relations "worker_ppe_assignment") $worker $ppeType $assignmentState $true)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "ASSIGNMENT_NOT_PROVEN" "Relazione worker-ppe assignment non provata esattamente." @("worker_ppe_assignment") "PARTIAL"
    }

    if ($assignmentState -ceq "NOT_ASSIGNED") {
        return New-Dpi4DDecision $InputObject "GAP" "REQUIRED_PPE_NOT_ASSIGNED" "Requirement provato; DPI richiesto esplicitamente non assegnato." @() "PASS"
    }

    $evidence = [string](Get-Dpi4DProperty $evidenceNode "value")
    if (-not (Test-Dpi4DText $evidence) -or -not (Test-Dpi4DProvenance $evidenceNode $true)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "EVIDENCE_NOT_PROVEN" "Assegnazione presente ma evidenza non provata." @("evidence_ref") "PARTIAL"
    }
    if (-not (Test-Dpi4DRelation (Get-Dpi4DProperty $relations "assignment_evidence") $ppeType $evidence "PRESENT" $true)) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "EVIDENCE_NOT_PROVEN" "Relazione assignment-evidence non provata esattamente." @("assignment_evidence") "PARTIAL"
    }

    $validityState = [string](Get-Dpi4DProperty $validityNode "value")
    if (-not (Test-Dpi4DProvenance $validityNode $true) -or -not (($validityState -ceq "VALID") -or ($validityState -ceq "INVALID") -or ($validityState -ceq "EXPIRED"))) {
        return New-Dpi4DDecision $InputObject "NON_VERIFICATO" "VALIDITY_NOT_PROVEN" "Validita non provata; nessuna inferenza temporale." @("validity") "PARTIAL"
    }

    if (($validityState -ceq "INVALID") -or ($validityState -ceq "EXPIRED")) {
        return New-Dpi4DDecision $InputObject "GAP" "ASSIGNED_PPE_INVALID_OR_EXPIRED" "Requirement e assegnazione provati; copertura esplicitamente invalida o scaduta." @() "PASS"
    }

    return New-Dpi4DDecision $InputObject "COVERED" "COVERED_COMPLETE_CHAIN" "Catena completa, coerente, valida e tracciabile." @() "PASS"
}

# Root demo = cartella "demo" (portabile su qualunque PC)
$root = Split-Path -Parent $PSScriptRoot

$datiDir = Join-Path $root "01_DEMO_DATI"
$outputDir = Join-Path $root "02_OUTPUT"
$operatoriDir = Join-Path $datiDir "08_OPERATORI_DPI"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# 4D is opt-in and exact: the historical 4C path remains unchanged unless this exact file exists.
$positiveChainPath = Join-Path $datiDir "DPI_4D_CHAIN.json"
if (Test-Path -LiteralPath $positiveChainPath -PathType Leaf) {
    $decisionPath = Join-Path $outputDir "DPI_4D_DECISION.json"
    $reportFile = Join-Path $outputDir "DPI_GUARDIAN_DEMO_REPORT.txt"

    $positiveFiles = @(Get-ChildItem -LiteralPath $datiDir -File -Recurse -ErrorAction Stop)
    if ($positiveFiles.Count -ne 1 -or -not ($positiveFiles[0].FullName -ceq $positiveChainPath)) {
        [pscustomobject]@{
            ENGINE = "DPI_4D_POSITIVE_CHAIN_MINIMUM"
            DECISION = "NON_VERIFICATO"
            REASON_CODE = "UNEXPECTED_INPUT_FILES"
            REASON_TEXT_MINIMAL = "4D accetta un solo DPI_4D_CHAIN.json; nessun input viene ignorato."
            MISSING_LINKS = @("input_inventory")
            SOURCE_REFS = @()
            PROVENANCE = "FAIL"
            DOMAIN_INFERENCE = "ZERO"
            PROVENANCE_TRACE = @()
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $decisionPath -Encoding UTF8
        Write-Error "DPI_4D_UNEXPECTED_INPUT_FILES" -ErrorAction Continue
        exit 4
    }

    try {
        $inputObject = Get-Content -LiteralPath $positiveChainPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $decision = Invoke-Dpi4DDecision $inputObject
        $decision | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $decisionPath -Encoding UTF8

        @"
DPI GUARDIAN 4D POSITIVE CHAIN REPORT
DATA: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

INPUT: $positiveChainPath
OUTPUT: $decisionPath

DECISION: $($decision.DECISION)
REASON_CODE: $($decision.REASON_CODE)
PROVENANCE: $($decision.PROVENANCE)
DOMAIN_INFERENCE: $($decision.DOMAIN_INFERENCE)

==========================================
4D POSITIVE PATH: ACTIVE
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
