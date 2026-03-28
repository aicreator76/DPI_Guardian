@echo off
setlocal EnableExtensions

title DPI Guardian Demo
cd /d "%~dp0"

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "LOCAL_RUN=%ROOT%\04_SCRIPT\run_local.ps1"
set "REPORT=%ROOT%\02_OUTPUT\DPI_GUARDIAN_DEMO_REPORT.txt"

echo ==========================================
echo         DPI GUARDIAN DEMO AVVIO
echo ==========================================
echo ROOT: %ROOT%
echo.

if not exist "%LOCAL_RUN%" (
    echo [ERRORE] Script local run non trovato:
    echo %LOCAL_RUN%
    echo.
    pause
    exit /b 1
)

echo [OK] Avvio flusso demo completo...
powershell -ExecutionPolicy Bypass -NoProfile -File "%LOCAL_RUN%"
if errorlevel 1 (
    echo.
    echo [ERRORE] Esecuzione demo fallita.
    echo.
    pause
    exit /b 1
)

echo.
if exist "%REPORT%" (
    echo [OK] Apertura report...
    start "" notepad "%REPORT%"
) else (
    echo [WARNING] Report non trovato:
    echo %REPORT%
)

echo.
echo ==========================================
echo DPI GUARDIAN DEMO COMPLETATA
echo Dashboard aggiornata - Report disponibile
echo ==========================================
echo.
pause
endlocal
exit /b 0