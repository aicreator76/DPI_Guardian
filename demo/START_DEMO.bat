@echo off
:: DPI_Guardian — Avvio Demo
:: Eseguire da Esplora Risorse o da prompt dei comandi

setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%04_SCRIPT\DPI_GUARDIAN_RUN.ps1"
set "CONSOLE=%SCRIPT_DIR%03_PRESENTAZIONE\console\index.html"

echo.
echo =============================================
echo   DPI_Guardian - Avvio Demo
echo =============================================
echo.

:: Avvio script PowerShell
if exist "%PS_SCRIPT%" (
    echo [INFO] Avvio DPI_GUARDIAN_RUN.ps1 ...
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%PS_SCRIPT%"
) else (
    echo [WARN] Script PowerShell non trovato: %PS_SCRIPT%
)

:: Apertura dashboard nel browser predefinito
if exist "%CONSOLE%" (
    echo [INFO] Apertura dashboard nel browser ...
    start "" "%CONSOLE%"
) else (
    echo [WARN] Dashboard non trovata: %CONSOLE%
)

echo.
echo Demo avviata. Premere un tasto per chiudere questa finestra.
pause >nul

endlocal
