@echo off
setlocal

title DPI Guardian Demo
cd /d "%~dp0"

set "ROOT=%~dp0"
set "DASHBOARD=%ROOT%03_PRESENTAZIONE\console\index.html"
set "REPORT=%ROOT%02_OUTPUT\DPI_GUARDIAN_DEMO_REPORT.txt"
set "DEMO_PS1=%ROOT%04_SCRIPT\DPI_GUARDIAN_RUN.ps1"

echo ==========================================
echo         DPI GUARDIAN DEMO AVVIO
echo ==========================================
echo ROOT: %ROOT%
echo.

if exist "%DASHBOARD%" (
    echo [OK] Avvio dashboard...
    start "" "%DASHBOARD%"
) else (
    echo [WARNING] Dashboard non trovata:
    echo %DASHBOARD%
    echo.
)

if exist "%DEMO_PS1%" (
    echo [OK] Avvio script demo...
    powershell -ExecutionPolicy Bypass -NoProfile -File "%DEMO_PS1%"
) else (
    echo [ERRORE] Script demo non trovato:
    echo %DEMO_PS1%
    echo.
    pause
    exit /b 1
)

echo.
if exist "%REPORT%" (
    echo [OK] Apertura report...
    start "" notepad "%REPORT%"
) else (
    echo [ERRORE] Report non trovato:
    echo %REPORT%
    echo.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo DPI GUARDIAN DEMO COMPLETATA
echo Dashboard aperta - Report generato
echo ==========================================
echo.
pause
endlocal