$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceScript = Join-Path $RepoRoot "demo\04_SCRIPT\DPI_GUARDIAN_RUN.ps1"
$Shell = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $Shell) { $Shell = (Get-Command powershell -ErrorAction Stop).Source }

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if (-not $Condition) { throw "$Name=FAIL" }
    Write-Host "$Name=PASS"
}

function New-Node {
    param([string]$Value, [string]$SourceRef, [string]$AuthorityRef = "AUTH_SYNTHETIC")
    return [ordered]@{
        value = $Value
        source_ref = $SourceRef
        source_version = "v1"
        valid_from = "2026-01-01"
        valid_to = ""
        authority_ref = $AuthorityRef
    }
}

function New-Relation {
    param([string]$From, [string]$To, [string]$SourceRef, [string]$Status = "")
    $relation = [ordered]@{
        from = $From
        to = $To
        source_ref = $SourceRef
        source_version = "v1"
        valid_from = "2026-01-01"
        valid_to = ""
        authority_ref = "AUTH_SYNTHETIC"
    }
    if (-not [string]::IsNullOrWhiteSpace($Status)) { $relation["status"] = $Status }
    return $relation
}

function New-CoveredCase {
    $worker = "WORKER_SYN_001"
    $role = "JOB_ROLE_SYN_001"
    $risk = "RISK_SYN_001"
    $requirement = "REQ_SYN_001"
    $ppe = "PPE_TYPE_SYN_001"
    $evidence = "EVIDENCE_SYN_001"

    return [ordered]@{
        case_id = "CASE_A_POSITIVE_COVERED"
        synthetic_fixture = $true
        source_ref = "SYNTHETIC_DATASET_V1"
        worker_ref = New-Node $worker "SRC_WORKER_SYN"
        job_role_id = New-Node $role "SRC_JOB_ROLE_SYN"
        risk_id = New-Node $risk "SRC_RISK_SYN"
        requirement_id = New-Node $requirement "SRC_REQUIREMENT_SYN"
        ppe_type_id = New-Node $ppe "SRC_PPE_TYPE_SYN"
        assigned_ppe = New-Node "ASSIGNED" "SRC_ASSIGNMENT_SYN"
        evidence_ref = New-Node $evidence "SRC_EVIDENCE_SYN"
        validity = New-Node "VALID" "SRC_VALIDITY_SYN"
        relations = [ordered]@{
            worker_job_role = New-Relation $worker $role "SRC_LINK_WORKER_ROLE_SYN"
            job_role_risk = New-Relation $role $risk "SRC_LINK_ROLE_RISK_SYN"
            risk_requirement = New-Relation $risk $requirement "SRC_LINK_RISK_REQ_SYN"
            requirement_ppe = New-Relation $requirement $ppe "SRC_LINK_REQ_PPE_SYN"
            worker_ppe_assignment = New-Relation $worker $ppe "SRC_LINK_ASSIGN_SYN" "ASSIGNED"
            assignment_evidence = New-Relation $ppe $evidence "SRC_LINK_EVIDENCE_SYN" "PRESENT"
        }
    }
}

function Invoke-Case {
    param($Case, [string]$Name)

    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("dpi4d_" + $Name + "_" + [guid]::NewGuid().ToString("N"))
    $demo = Join-Path $sandbox "demo"
    $scriptDir = Join-Path $demo "04_SCRIPT"
    $inputDir = Join-Path $demo "01_DEMO_DATI"
    New-Item -ItemType Directory -Force -Path $scriptDir, $inputDir | Out-Null
    Copy-Item -LiteralPath $SourceScript -Destination (Join-Path $scriptDir "DPI_GUARDIAN_RUN.ps1")

    $Case["case_id"] = $Name
    $Case | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $inputDir "DPI_4D_CHAIN.json") -Encoding UTF8

    $stdout = Join-Path $sandbox "stdout.txt"
    $stderr = Join-Path $sandbox "stderr.txt"
    $process = Start-Process -FilePath $Shell -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $scriptDir "DPI_GUARDIAN_RUN.ps1")
    ) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr

    $decisionPath = Join-Path $demo "02_OUTPUT\DPI_4D_DECISION.json"
    $decision = if (Test-Path $decisionPath) { Get-Content -LiteralPath $decisionPath -Raw | ConvertFrom-Json } else { $null }

    return [pscustomobject]@{
        Root = $sandbox
        ExitCode = $process.ExitCode
        Decision = $decision
        Stdout = if (Test-Path $stdout) { Get-Content -LiteralPath $stdout -Raw } else { "" }
        Stderr = if (Test-Path $stderr) { Get-Content -LiteralPath $stderr -Raw } else { "" }
    }
}

function Remove-Case {
    param($Result)
    if ($null -ne $Result -and (Test-Path $Result.Root)) { Remove-Item -LiteralPath $Result.Root -Recurse -Force }
}

# T01 - complete chain => COVERED
$r = Invoke-Case (New-CoveredCase) "CASE_A_POSITIVE_COVERED"
try {
    Assert-True ($r.ExitCode -eq 0 -and $r.Decision.DECISION -eq "COVERED") "T01_HAPPY_PATH_COVERED"
    Assert-True ($r.Decision.REASON_CODE -eq "COVERED_COMPLETE_CHAIN") "T01_REASON_COMPLETE_CHAIN"
    Assert-True ($r.Decision.PROVENANCE -eq "PASS" -and $r.Decision.DOMAIN_INFERENCE -eq "ZERO") "T01_PROVENANCE_AND_ZERO_INFERENCE"
    Assert-True (@($r.Decision.PROVENANCE_TRACE).Count -eq 14) "T01_FULL_TRACE_14_LINKS"
} finally { Remove-Case $r }

# T02 - requirement proven, explicit assignment absence => GAP
$c = New-CoveredCase
$c["assigned_ppe"]["value"] = "NOT_ASSIGNED"
$c["relations"]["worker_ppe_assignment"]["status"] = "NOT_ASSIGNED"
$r = Invoke-Case $c "CASE_B_TRUE_GAP"
try {
    Assert-True ($r.ExitCode -eq 0 -and $r.Decision.DECISION -eq "GAP") "T02_REQUIRED_PPE_NOT_ASSIGNED_GAP"
    Assert-True ($r.Decision.REASON_CODE -eq "REQUIRED_PPE_NOT_ASSIGNED") "T02_TRUE_GAP_REASON"
} finally { Remove-Case $r }

# T03 - job_role -> risk missing => NON_VERIFICATO
$c = New-CoveredCase
$c["relations"]["job_role_risk"] = $null
$r = Invoke-Case $c "CASE_C_UNVERIFIED_MAPPING"
try {
    Assert-True ($r.ExitCode -eq 4 -and $r.Decision.DECISION -eq "NON_VERIFICATO") "T03_JOB_ROLE_RISK_MISSING_NON_VERIFICATO"
    Assert-True ($r.Decision.REASON_CODE -eq "JOB_ROLE_RISK_NOT_PROVEN") "T03_MAPPING_REASON"
} finally { Remove-Case $r }

# T04 - requirement missing => NON_VERIFICATO, never GAP
$c = New-CoveredCase
$c["requirement_id"] = $null
$r = Invoke-Case $c "CASE_REQUIREMENT_MISSING"
try {
    Assert-True ($r.ExitCode -eq 4 -and $r.Decision.DECISION -eq "NON_VERIFICATO") "T04_REQUIREMENT_MISSING_NON_VERIFICATO"
    Assert-True ($r.Decision.REASON_CODE -eq "RISK_REQUIREMENT_NOT_PROVEN") "T04_REQUIREMENT_REASON"
} finally { Remove-Case $r }

# T05 - assignment present, evidence missing => NON_VERIFICATO
$c = New-CoveredCase
$c["evidence_ref"]["value"] = ""
$r = Invoke-Case $c "CASE_D_EVIDENCE_MISSING"
try {
    Assert-True ($r.ExitCode -eq 4 -and $r.Decision.DECISION -eq "NON_VERIFICATO") "T05_EVIDENCE_MISSING_NON_VERIFICATO"
    Assert-True ($r.Decision.REASON_CODE -eq "EVIDENCE_NOT_PROVEN") "T05_EVIDENCE_REASON"
} finally { Remove-Case $r }

# T06 - explicit proven expiry => GAP, not inferred from dates
$c = New-CoveredCase
$c["validity"]["value"] = "EXPIRED"
$r = Invoke-Case $c "CASE_E_EXPIRED_OR_INVALID"
try {
    Assert-True ($r.ExitCode -eq 0 -and $r.Decision.DECISION -eq "GAP") "T06_EXPIRED_PROVEN_GAP"
    Assert-True ($r.Decision.REASON_CODE -eq "ASSIGNED_PPE_INVALID_OR_EXPIRED") "T06_VALIDITY_REASON"
} finally { Remove-Case $r }

# T07 - unknown department cannot complete missing job_role
$c = New-CoveredCase
$c["job_role_id"] = $null
$c["department"] = New-Node "JOB_ROLE_SYN_001" "SRC_DEPARTMENT_SYN"
$r = Invoke-Case $c "CASE_UNKNOWN_FIELD"
try {
    Assert-True ($r.ExitCode -eq 4 -and $r.Decision.DECISION -eq "NON_VERIFICATO") "T07_UNKNOWN_FIELD_NO_AUTOCOMPLETE"
    Assert-True ($r.Decision.REASON_CODE -eq "WORKER_JOB_ROLE_NOT_PROVEN") "T07_DEPARTMENT_NOT_JOB_ROLE"
} finally { Remove-Case $r }

# T08 - partial lower chain cannot become COVERED/GAP
$c = New-CoveredCase
$c["ppe_type_id"] = $null
$r = Invoke-Case $c "CASE_PARTIAL_CHAIN"
try {
    Assert-True ($r.ExitCode -eq 4 -and $r.Decision.DECISION -eq "NON_VERIFICATO") "T08_PARTIAL_CHAIN_NON_VERIFICATO"
} finally { Remove-Case $r }

# T09 - top-level source_ref mandatory
$c = New-CoveredCase
$c["source_ref"] = ""
$r = Invoke-Case $c "CASE_SOURCE_REF_MISSING"
try {
    Assert-True ($r.ExitCode -eq 4 -and $r.Decision.DECISION -eq "NON_VERIFICATO") "T09_SOURCE_REF_MISSING_NON_VERIFICATO"
    Assert-True ($r.Decision.REASON_CODE -eq "SOURCE_REF_NOT_PROVEN") "T09_SOURCE_REF_REASON"
} finally { Remove-Case $r }

# CLAUDE-style adversarial contract attacks
$c = New-CoveredCase
$c["relations"]["assignment_evidence"] = $null
$r = Invoke-Case $c "ATTACK_COVERED_WITH_MISSING_LINK"
try { Assert-True ($r.Decision.DECISION -ne "COVERED") "A01_COVERED_WITH_MISSING_LINK_BLOCKED" } finally { Remove-Case $r }

$c = New-CoveredCase
$c["assigned_ppe"]["value"] = "UNKNOWN"
$c["relations"]["worker_ppe_assignment"]["status"] = "UNKNOWN"
$r = Invoke-Case $c "ATTACK_UNKNOWN_TO_GAP"
try { Assert-True ($r.Decision.DECISION -eq "NON_VERIFICATO") "A02_UNKNOWN_NOT_TRANSFORMED_TO_GAP" } finally { Remove-Case $r }

$c = New-CoveredCase
$c["requirement_id"]["authority_ref"] = ""
$r = Invoke-Case $c "ATTACK_NON_AUTHORITATIVE_REQUIREMENT"
try { Assert-True ($r.Decision.DECISION -eq "NON_VERIFICATO") "A03_NON_AUTHORITATIVE_REQUIREMENT_BLOCKED" } finally { Remove-Case $r }

$c = New-CoveredCase
$c["relations"]["job_role_risk"]["from"] = "JOB_ROLE_SYN_001_SIMILAR"
$r = Invoke-Case $c "ATTACK_STRING_SIMILARITY_JOIN"
try { Assert-True ($r.Decision.DECISION -eq "NON_VERIFICATO") "A04_STRING_SIMILARITY_JOIN_BLOCKED" } finally { Remove-Case $r }

$c = New-CoveredCase
$c["relations"]["worker_job_role"]["source_ref"] = ""
$r = Invoke-Case $c "ATTACK_OMIT_PROVENANCE"
try { Assert-True ($r.Decision.DECISION -eq "NON_VERIFICATO") "A05_OMITTED_PROVENANCE_BLOCKED" } finally { Remove-Case $r }

$c = New-CoveredCase
$c["job_role_id"] = $null
$c["department"] = New-Node "JOB_ROLE_SYN_001" "SRC_DEPARTMENT_SYN"
$r = Invoke-Case $c "ATTACK_DEPARTMENT_AS_JOB_ROLE"
try { Assert-True ($r.Decision.DECISION -eq "NON_VERIFICATO") "A06_DEPARTMENT_AS_JOB_ROLE_BLOCKED" } finally { Remove-Case $r }

$c = New-CoveredCase
$c["requirement_id"] = $null
$c["ppe_category"] = New-Node "REQ_SYN_001" "SRC_PPE_CATEGORY_SYN"
$r = Invoke-Case $c "ATTACK_PPE_CATEGORY_AS_REQUIREMENT"
try { Assert-True ($r.Decision.DECISION -eq "NON_VERIFICATO") "A07_PPE_CATEGORY_AS_REQUIREMENT_BLOCKED" } finally { Remove-Case $r }

# T10 - execute the complete 4C fail-closed regression suite unchanged
$regressionStdout = Join-Path ([System.IO.Path]::GetTempPath()) ("dpi4c_regression_stdout_" + [guid]::NewGuid().ToString("N") + ".txt")
$regressionStderr = Join-Path ([System.IO.Path]::GetTempPath()) ("dpi4c_regression_stderr_" + [guid]::NewGuid().ToString("N") + ".txt")
try {
    $regression = Start-Process -FilePath $Shell -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "tests\dpi-4c-realinput-failclosed.ps1")
    ) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $regressionStdout -RedirectStandardError $regressionStderr
    Assert-True ($regression.ExitCode -eq 0) "T10_4C_REGRESSION_PRESERVED"
} finally {
    Remove-Item -LiteralPath $regressionStdout, $regressionStderr -Force -ErrorAction SilentlyContinue
}

Write-Host "DPI_4D_REQUIRED_TESTS=10/10_PASS"
Write-Host "DPI_4D_ADVERSARIAL_ATTACKS=7/7_BLOCKED"
Write-Host "DPI_4D_DOMAIN_INFERENCE=ZERO"
