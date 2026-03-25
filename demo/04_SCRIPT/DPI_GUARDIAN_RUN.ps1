#Requires -Version 5.1
<#
.SYNOPSIS
    Script operativo principale di DPI_Guardian.

.DESCRIPTION
    Avvia il ciclo di monitoraggio e validazione dei Dispositivi di Protezione
    Individuale. Questo file è il punto di ingresso della logica CESARE.

.NOTES
    Non modificare la struttura di questo script senza aggiornare TEST_FINALE.md.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$demoRoot  = Split-Path -Parent $scriptDir
$datiDir   = Join-Path $demoRoot '01_DEMO_DATI'
$logFile   = Join-Path $scriptDir 'dpi_guardian.log'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$ts] [$Level] $Message"
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
    Write-Host $line
}

# ---------------------------------------------------------------------------
Write-Log "DPI_Guardian avviato"
Write-Log "Cartella dati: $datiDir"

if (-not (Test-Path -LiteralPath $datiDir -PathType Container)) {
    Write-Log "Cartella dati non trovata: $datiDir" 'WARN'
}
else {
    $files = Get-ChildItem -LiteralPath $datiDir -File -Recurse
    Write-Log ("File dati trovati: {0}" -f $files.Count)
    foreach ($f in $files) {
        Write-Log ("  - {0}" -f $f.Name)
    }
}

Write-Log "DPI_Guardian completato"
