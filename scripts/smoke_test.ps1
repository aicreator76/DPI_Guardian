# smoke_test.ps1
# DPI_Guardian — Automated Smoke Test
# Verifies that all required demo files and directories are present.

$ErrorCount = 0
$RootPath = Split-Path -Parent $PSScriptRoot

function Test-Item {
    param(
        [string]$RelativePath,
        [string]$Label,
        [switch]$IsDirectory
    )
    $FullPath = Join-Path $RootPath $RelativePath
    if ($IsDirectory) {
        $exists = Test-Path -Path $FullPath -PathType Container
    } else {
        $exists = Test-Path -Path $FullPath -PathType Leaf
    }
    if ($exists) {
        Write-Host "[OK]   $Label" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Label — not found: $FullPath" -ForegroundColor Red
        $script:ErrorCount++
    }
}

Write-Host ""
Write-Host "=== DPI_Guardian Smoke Test ===" -ForegroundColor Cyan
Write-Host ""

# Required files
Test-Item "demo\START_DEMO.bat"                           "demo/START_DEMO.bat exists"
Test-Item "demo\03_PRESENTAZIONE\console\index.html"      "demo/03_PRESENTAZIONE/console/index.html exists"
Test-Item "demo\04_SCRIPT\DPI_GUARDIAN_RUN.ps1"           "demo/04_SCRIPT/DPI_GUARDIAN_RUN.ps1 exists"

# At least one file in demo/01_DEMO_DATI
$DemoDataPath = Join-Path $RootPath "demo\01_DEMO_DATI"
$DemoDataFiles = @()
if (Test-Path -Path $DemoDataPath -PathType Container) {
    $DemoDataFiles = Get-ChildItem -Path $DemoDataPath -File -Recurse
}
if ($DemoDataFiles.Count -gt 0) {
    Write-Host "[OK]   demo/01_DEMO_DATI contains at least one file" -ForegroundColor Green
} else {
    Write-Host "[FAIL] demo/01_DEMO_DATI is empty or does not exist" -ForegroundColor Red
    $ErrorCount++
}

Write-Host ""
if ($ErrorCount -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$ErrorCount check(s) failed." -ForegroundColor Red
    exit 1
}
