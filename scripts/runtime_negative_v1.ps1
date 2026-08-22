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

function Set-ReferencedPdfFixture([string]$Root, [bool]$Empty) {
    $jsonPath = Join-Path $Root 'demo/03_PRESENTAZIONE/console/dashboard_data.json'
    $pdfDir = Join-Path $Root 'demo/03_PRESENTAZIONE/console/pdf'
    $j = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
    if (@($j.rows).Count -lt 1) { throw 'negative fixture requires at least one row' }

    $name = 'TEST_FIXTURE_REFERENCED.pdf'
    $path = Join-Path $pdfDir $name
    if ($Empty) {
        [IO.File]::WriteAllBytes($path, [byte[]]@())
    } else {
        Set-Content -LiteralPath $path -Value 'TEST_FIXTURE synthetic non-empty PDF placeholder for negative integrity test' -Encoding UTF8
    }

    $j.rows[0].file_collegati = @($name)
    $j.rows[0].allegati = @($name)
    $j.rows[0].file_collegati_count = 1
    $j | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    return $path
}

Invoke-NegativeFixture 'MISSING_DASHBOARD_JSON' { param($r) Remove-Item (Join-Path $r 'demo/03_PRESENTAZIONE/console/dashboard_data.json') -Force }
Invoke-NegativeFixture 'INVALID_JSON' { param($r) Set-Content (Join-Path $r 'demo/03_PRESENTAZIONE/console/dashboard_data.json') '{INVALID' }
Invoke-NegativeFixture 'MISSING_REFERENCED_PDF' {
    param($r)
    $path = Set-ReferencedPdfFixture -Root $r -Empty $false
    Remove-Item -LiteralPath $path -Force
}
Invoke-NegativeFixture 'EMPTY_REFERENCED_PDF' {
    param($r)
    [void](Set-ReferencedPdfFixture -Root $r -Empty $true)
}
Write-Host 'NEGATIVE_FIXTURES=PASS'
