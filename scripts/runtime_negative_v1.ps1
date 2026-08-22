$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceDemo = Join-Path $repoRoot 'demo'
$sourceScripts = Join-Path $repoRoot 'scripts'

function Invoke-NegativeFixture([string]$Name, [scriptblock]$Mutate) {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("DPI_GUARDIAN_TEST_FIXTURE_" + $Name + '_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root | Out-Null
    Copy-Item $sourceDemo (Join-Path $root 'demo') -Recurse
    Copy-Item $sourceScripts (Join-Path $root 'scripts') -Recurse
    try {
        & $Mutate $root
        & pwsh -NoProfile -File (Join-Path $root 'scripts/integrity_v1.ps1') *> (Join-Path $root 'negative.log')
        if ($LASTEXITCODE -eq 0) { throw "NEGATIVE_TEST_DID_NOT_FAIL=$Name" }
        Write-Host "NEGATIVE_TEST_PASS=$Name"
    } finally {
        Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-NegativeFixture 'MISSING_DASHBOARD_JSON' { param($r) Remove-Item (Join-Path $r 'demo/03_PRESENTAZIONE/console/dashboard_data.json') -Force }
Invoke-NegativeFixture 'INVALID_JSON' { param($r) Set-Content (Join-Path $r 'demo/03_PRESENTAZIONE/console/dashboard_data.json') '{INVALID' }
Invoke-NegativeFixture 'MISSING_REFERENCED_PDF' {
    param($r)
    $j=Get-Content (Join-Path $r 'demo/03_PRESENTAZIONE/console/dashboard_data.json') -Raw | ConvertFrom-Json
    $name=@($j.rows[0].file_collegati)[0]
    Remove-Item (Join-Path $r ('demo/03_PRESENTAZIONE/console/pdf/' + $name)) -Force
}
Invoke-NegativeFixture 'EMPTY_REFERENCED_PDF' {
    param($r)
    $j=Get-Content (Join-Path $r 'demo/03_PRESENTAZIONE/console/dashboard_data.json') -Raw | ConvertFrom-Json
    $name=@($j.rows[0].file_collegati)[0]
    Set-Content (Join-Path $r ('demo/03_PRESENTAZIONE/console/pdf/' + $name)) -Value $null -NoNewline
}
Write-Host 'NEGATIVE_FIXTURES=PASS'
