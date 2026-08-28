$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceScript = Join-Path $RepoRoot "demo\04_SCRIPT\DPI_GUARDIAN_RUN.ps1"
$ParentCommit = "e2faacdfc1d61b07942e941d075d6c3bb5ab4c99"
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
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("dpi4c_" + $Name + "_" + [guid]::NewGuid().ToString("N"))
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

$ParentSource = git -C $RepoRoot show "$($ParentCommit):demo/04_SCRIPT/DPI_GUARDIAN_RUN.ps1"
$ParentText = $ParentSource -join [Environment]::NewLine
Assert-True ($ParentText -match 'Get-ChildItem \$datiDir -File(\r?\n|$)') "D00_PARENT_NON_RECURSIVE_REPRODUCED"
Assert-True ($ParentText -match 'PRESENTABILE CON WARNING') "D01_PARENT_FALSE_STATUS_REPRODUCED"

$SourceHashBefore = (Get-FileHash -LiteralPath $SourceScript -Algorithm SHA256).Hash

$nested = New-Fixture "nested"
try {
    $nestedInput = Join-Path $nested "01_DEMO_DATI\cliente\lotto"
    New-Item -ItemType Directory -Force -Path $nestedInput | Out-Null
    Set-Content -LiteralPath (Join-Path $nestedInput "input_nested.csv") -Value @("id,value","1,test") -Encoding UTF8
    $r = Invoke-Fixture $nested
    $j = Get-Content -LiteralPath $r.JsonPath -Raw | ConvertFrom-Json
    Assert-True ($r.ExitCode -eq 0) "D02_NESTED_INPUT_EXIT_ZERO"
    Assert-True ($r.Stdout -match 'Numero file trovati:\s+1') "D03_NESTED_INPUT_DISCOVERED"
    Assert-True (@($j.rows).Count -eq 1) "D04_NESTED_INPUT_PROCESSED"
}
finally {
    Remove-Item -LiteralPath (Split-Path -Parent $nested) -Recurse -Force
}

$top = New-Fixture "top"
try {
    $topInput = Join-Path $top "01_DEMO_DATI"
    New-Item -ItemType Directory -Force -Path $topInput | Out-Null
    Set-Content -LiteralPath (Join-Path $topInput "input_top.csv") -Value @("id,value","1,test") -Encoding UTF8
    $r = Invoke-Fixture $top
    $j = Get-Content -LiteralPath $r.JsonPath -Raw | ConvertFrom-Json
    Assert-True ($r.ExitCode -eq 0) "D05_TOP_LEVEL_REGRESSION_EXIT_ZERO"
    Assert-True (@($j.rows).Count -eq 1) "D06_TOP_LEVEL_REGRESSION_PROCESSED"
}
finally {
    Remove-Item -LiteralPath (Split-Path -Parent $top) -Recurse -Force
}

$empty = New-Fixture "empty"
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $empty "01_DEMO_DATI\annidato") | Out-Null
    $r = Invoke-Fixture $empty
    $j = Get-Content -LiteralPath $r.JsonPath -Raw | ConvertFrom-Json
    $report = Get-Content -LiteralPath $r.ReportPath -Raw
    Assert-True ($r.ExitCode -eq 2) "D07_EMPTY_INPUT_NONZERO_EXIT"
    Assert-True ($j.final_status -eq "FAIL" -and $j.error_count -eq 1) "D08_EMPTY_INPUT_FAIL_JSON"
    Assert-True ($report -match 'Stato demo: NON_PRESENTABILE') "D09_EMPTY_INPUT_NON_PRESENTABLE"
    Assert-True ($report -notmatch 'Demo eseguita correttamente') "D10_EMPTY_INPUT_NO_FALSE_GREEN"
}
finally {
    Remove-Item -LiteralPath (Split-Path -Parent $empty) -Recurse -Force
}

$missing = New-Fixture "missing"
try {
    $r = Invoke-Fixture $missing
    $j = Get-Content -LiteralPath $r.JsonPath -Raw | ConvertFrom-Json
    Assert-True ($r.ExitCode -eq 2) "D11_MISSING_INPUT_NONZERO_EXIT"
    Assert-True ($j.summary -match '^INPUT_DIRECTORY_NOT_FOUND:') "D12_MISSING_INPUT_FAIL_REASON"
}
finally {
    Remove-Item -LiteralPath (Split-Path -Parent $missing) -Recurse -Force
}

$SourceHashAfter = (Get-FileHash -LiteralPath $SourceScript -Algorithm SHA256).Hash
Assert-True ($SourceHashBefore -eq $SourceHashAfter) "D13_SOURCE_UNCHANGED_BY_TESTS"

Write-Host "DPI_4C_MINIMAL_FIX_TESTS=14/14_PASS"
