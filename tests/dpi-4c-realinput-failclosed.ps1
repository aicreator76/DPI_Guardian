$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceScript = Join-Path $RepoRoot "demo\04_SCRIPT\DPI_GUARDIAN_RUN.ps1"
$SemanticParentCommit = "2ff81477e938a9853047f2a619661855c80322f1"
$Shell = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $Shell) {
    $Shell = (Get-Command powershell -ErrorAction Stop).Source
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if (-not $Condition) { throw "$Name=FAIL" }
    Write-Host "$Name=PASS"
}

function New-Fixture {
    param([string]$Name)
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("dpi4c_semantic_" + $Name + "_" + [guid]::NewGuid().ToString("N"))
    $demo = Join-Path $root "demo"
    $scriptDir = Join-Path $demo "04_SCRIPT"
    New-Item -ItemType Directory -Force -Path $scriptDir | Out-Null
    Copy-Item -LiteralPath $SourceScript -Destination (Join-Path $scriptDir "DPI_GUARDIAN_RUN.ps1")
    return $demo
}

function Invoke-Fixture {
    param([string]$Demo)
    $script = Join-Path $Demo "04_SCRIPT\DPI_GUARDIAN_RUN.ps1"
    $stdout = Join-Path $Demo "stdout.txt"
    $stderr = Join-Path $Demo "stderr.txt"
    $process = Start-Process -FilePath $Shell -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $script
    ) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = if (Test-Path $stdout) { Get-Content -LiteralPath $stdout -Raw } else { "" }
        Stderr = if (Test-Path $stderr) { Get-Content -LiteralPath $stderr -Raw } else { "" }
        JsonPath = Join-Path $Demo "02_OUTPUT\dashboard_data.json"
        ReportPath = Join-Path $Demo "02_OUTPUT\DPI_GUARDIAN_DEMO_REPORT.txt"
    }
}

$ParentSource = git -C $RepoRoot show "$($SemanticParentCommit):demo/04_SCRIPT/DPI_GUARDIAN_RUN.ps1"
$ParentText = $ParentSource -join [Environment]::NewLine
Assert-True ($ParentText -match 'PRESENTABILE CON WARNING') "S00_PARENT_PRESENTABILITY_OVERCLAIM_REPRODUCED"
Assert-True ($ParentText -match 'dpi_id\s+= \$null') "S01_PARENT_NULL_SEMANTIC_FIELDS_REPRODUCED"
Assert-True ($ParentText -notmatch 'SEMANTIC_PRESENTABILITY_BLOCKED') "S02_PARENT_HAS_NO_SEMANTIC_FAIL_CLOSED"

$SourceText = Get-Content -LiteralPath $SourceScript -Raw
Assert-True ($SourceText -notmatch 'PRESENTABILE CON WARNING') "S03_FALSE_PRESENTABILITY_LABEL_RETIRED"
Assert-True ($SourceText -match 'SEMANTIC_PRESENTABILITY_BLOCKED') "S04_SEMANTIC_FAIL_CLOSED_PRESENT"

$SourceHashBefore = (Get-FileHash -LiteralPath $SourceScript -Algorithm SHA256).Hash

$nested = New-Fixture "nested_unverified"
try {
    $nestedInput = Join-Path $nested "01_DEMO_DATI\cliente\lotto"
    New-Item -ItemType Directory -Force -Path $nestedInput | Out-Null
    Set-Content -LiteralPath (Join-Path $nestedInput "input_nested.csv") -Value @("id,value", "1,test") -Encoding UTF8

    $r = Invoke-Fixture $nested
    $j = Get-Content -LiteralPath $r.JsonPath -Raw | ConvertFrom-Json
    $report = Get-Content -LiteralPath $r.ReportPath -Raw
    $row = @($j.rows)[0]

    Assert-True ($r.ExitCode -eq 4) "S05_UNVERIFIED_NESTED_INPUT_NONZERO_EXIT"
    Assert-True ($r.Stdout -match 'Numero file trovati:\s+1') "S06_RECURSIVE_DISCOVERY_RETAINED"
    Assert-True (@($j.rows).Count -eq 1) "S07_DISCOVERED_ROW_RETAINED_AS_EVIDENCE"
    Assert-True ($j.final_status -eq "NON_VERIFICATO" -and $j.error_count -ge 1) "S08_UNVERIFIED_JSON_FAIL_CLOSED"
    Assert-True ($j.summary -match 'OPERATOR_DIRECTORY_NOT_FOUND') "S09_MISSING_OPERATOR_DIRECTORY_BLOCKS"
    Assert-True ($j.summary -match 'SEMANTIC_CORE_NOT_VERIFIED:1/1') "S10_NULL_SEMANTIC_CORE_BLOCKS"
    Assert-True ($report -match 'Stato demo: NON_PRESENTABILE') "S11_UNVERIFIED_REPORT_NON_PRESENTABLE"
    Assert-True ($report -notmatch 'Demo eseguita correttamente') "S12_UNVERIFIED_REPORT_NO_FALSE_SUCCESS"
    Assert-True (
        $null -eq $row.dpi_id -and
        $null -eq $row.operatore -and
        $null -eq $row.norma -and
        $null -eq $row.matricola -and
        $null -eq $row.manuale_ok -and
        $null -eq $row.revisione_ok -and
        $null -eq $row.prossima_revisione
    ) "S13_NULL_CORE_FIELDS_EXPLICITLY_DETECTED"
}
finally {
    Remove-Item -LiteralPath (Split-Path -Parent $nested) -Recurse -Force
}

$operatorDirectoryPresent = New-Fixture "operator_dir_present"
try {
    $input = Join-Path $operatorDirectoryPresent "01_DEMO_DATI\cliente"
    $operators = Join-Path $operatorDirectoryPresent "01_DEMO_DATI\08_OPERATORI_DPI"
    New-Item -ItemType Directory -Force -Path $input, $operators | Out-Null
    Set-Content -LiteralPath (Join-Path $input "input.csv") -Value @("id,value", "1,test") -Encoding UTF8

    $r = Invoke-Fixture $operatorDirectoryPresent
    $j = Get-Content -LiteralPath $r.JsonPath -Raw | ConvertFrom-Json

    Assert-True ($r.ExitCode -eq 4) "S14_OPERATOR_DIRECTORY_ALONE_CANNOT_AUTHORIZE_PRESENTABILITY"
    Assert-True ($j.summary -notmatch 'OPERATOR_DIRECTORY_NOT_FOUND') "S15_OPERATOR_DIRECTORY_PRESENCE_RECOGNIZED"
    Assert-True ($j.summary -match 'SEMANTIC_CORE_NOT_VERIFIED:1/1') "S16_NULL_FIELDS_REMAIN_BLOCKING_WITH_OPERATOR_DIRECTORY"
}
finally {
    Remove-Item -LiteralPath (Split-Path -Parent $operatorDirectoryPresent) -Recurse -Force
}

$empty = New-Fixture "empty"
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $empty "01_DEMO_DATI\annidato") | Out-Null
    $r = Invoke-Fixture $empty
    $j = Get-Content -LiteralPath $r.JsonPath -Raw | ConvertFrom-Json
    $report = Get-Content -LiteralPath $r.ReportPath -Raw

    Assert-True ($r.ExitCode -eq 2) "S17_ZERO_INPUT_REMAINS_FAIL_CLOSED"
    Assert-True ($j.final_status -eq "FAIL" -and $report -match 'Stato demo: NON_PRESENTABILE') "S18_ZERO_INPUT_CONTRACT_RETAINED"
}
finally {
    Remove-Item -LiteralPath (Split-Path -Parent $empty) -Recurse -Force
}

$missing = New-Fixture "missing"
try {
    $r = Invoke-Fixture $missing
    $j = Get-Content -LiteralPath $r.JsonPath -Raw | ConvertFrom-Json

    Assert-True ($r.ExitCode -eq 2) "S19_MISSING_INPUT_REMAINS_FAIL_CLOSED"
    Assert-True ($j.summary -match '^INPUT_DIRECTORY_NOT_FOUND:') "S20_MISSING_INPUT_REASON_RETAINED"
}
finally {
    Remove-Item -LiteralPath (Split-Path -Parent $missing) -Recurse -Force
}

$SourceHashAfter = (Get-FileHash -LiteralPath $SourceScript -Algorithm SHA256).Hash
Assert-True ($SourceHashBefore -eq $SourceHashAfter) "S21_SOURCE_UNCHANGED_BY_TESTS"

Write-Host "DPI_4C_SEMANTIC_FAIL_CLOSED_TESTS=22/22_PASS"
