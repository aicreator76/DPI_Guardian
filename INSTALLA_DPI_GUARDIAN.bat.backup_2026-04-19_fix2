@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Installazione DPI Guardian Demo
cd /d "%~dp0"

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "SOURCE_DEMO=%ROOT%\demo"
set "DEFAULT_DEST=C:\DPI_GUARDIAN_DEMO"
set "DEST=%~1"

echo ==========================================
echo     INSTALLAZIONE DPI GUARDIAN DEMO
echo ==========================================
echo.

if not exist "%SOURCE_DEMO%" (
    echo [ERRORE] Cartella demo non trovata:
    echo %SOURCE_DEMO%
    echo.
    pause
    exit /b 1
)

echo Inserisci i riferimenti cliente se vuoi salvarli in questa installazione.
echo Premi INVIO per saltare qualsiasi campo.
echo.

set "CLIENT_EMAIL="
set /p "CLIENT_EMAIL=Mail cliente: "

if defined CLIENT_EMAIL (
    set "CLIENT_EMAIL=%CLIENT_EMAIL:"=%"
    echo [OK] Mail cliente registrata.
) else (
    echo [INFO] Mail cliente non inserita.
)

echo.
set "CLIENT_EMAIL_2="
set /p "CLIENT_EMAIL_2=Mail tecnica/commerciale: "

if defined CLIENT_EMAIL_2 (
    set "CLIENT_EMAIL_2=%CLIENT_EMAIL_2:"=%"
    echo [OK] Mail tecnica/commerciale registrata.
) else (
    echo [INFO] Mail tecnica/commerciale non inserita.
)

echo.
set "CLIENT_REFERENTE="
set /p "CLIENT_REFERENTE=Nome azienda o referente: "

if defined CLIENT_REFERENTE (
    set "CLIENT_REFERENTE=%CLIENT_REFERENTE:"=%"
    echo [OK] Referente registrato.
) else (
    echo [INFO] Referente non inserito.
)

if not defined DEST (
    echo.
    echo Destinazione predefinita:
    echo %DEFAULT_DEST%
    echo.
    set /p "DEST=Premi INVIO per confermare o scrivi un altro percorso: "
    if not defined DEST set "DEST=%DEFAULT_DEST%"
)

set "DEST=%DEST:"=%"

echo.
echo [OK] Destinazione scelta:
echo %DEST%
echo.

if not exist "%DEST%" (
    mkdir "%DEST%" >nul 2>&1
    if errorlevel 1 (
        echo [ERRORE] Impossibile creare la cartella destinazione:
        echo %DEST%
        echo.
        pause
        exit /b 1
    )
    echo [OK] Cartella destinazione creata.
) else (
    echo [OK] Cartella destinazione gia presente.
)

(
    echo DPI GUARDIAN - DATI INSTALLAZIONE
    echo.
    echo Referente:
    if defined CLIENT_REFERENTE (
        echo %CLIENT_REFERENTE%
    ) else (
        echo [non inserito]
    )
    echo.
    echo Mail cliente:
    if defined CLIENT_EMAIL (
        echo %CLIENT_EMAIL%
    ) else (
        echo [non inserita]
    )
    echo.
    echo Mail tecnica/commerciale:
    if defined CLIENT_EMAIL_2 (
        echo %CLIENT_EMAIL_2%
    ) else (
        echo [non inserita]
    )
    echo.
    echo Data installazione:
    echo %date% %time%
) > "%DEST%\CLIENTE_INSTALLAZIONE.txt"

echo [OK] File cliente creato:
echo %DEST%\CLIENTE_INSTALLAZIONE.txt

echo.
echo [OK] Copia file demo in corso...
robocopy "%SOURCE_DEMO%" "%DEST%" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NC /NS >nul
set "ROBOCODE=%ERRORLEVEL%"
if %ROBOCODE% GEQ 8 (
    echo [ERRORE] Copia fallita. Codice robocopy: %ROBOCODE%
    echo.
    pause
    exit /b %ROBOCODE%
)
echo [OK] Copia completata.

if not exist "%DEST%\02_OUTPUT" (
    mkdir "%DEST%\02_OUTPUT" >nul 2>&1
    if errorlevel 1 (
        echo [ERRORE] Impossibile creare la cartella 02_OUTPUT
        echo.
        pause
        exit /b 1
    )
)
echo [OK] Cartella 02_OUTPUT pronta.

if not exist "%DEST%\05_SUPPORTO" (
    mkdir "%DEST%\05_SUPPORTO" >nul 2>&1
)
echo [OK] Cartella 05_SUPPORTO pronta.

echo.
echo Dove tiene i documenti relativi a DPI, manuali, revisioni o file collegati?
echo Se vuole, mi indichi una cartella cosi preparo gia l'area di lavoro.
echo Premi INVIO per saltare questo passaggio.
echo.

set "DOCS_SOURCE="
set /p "DOCS_SOURCE=Cartella documenti cliente: "

if defined DOCS_SOURCE (
    set "DOCS_SOURCE=%DOCS_SOURCE:"=%"

    if exist "%DOCS_SOURCE%" (
        set "WORKAREA=%DEST%\AREA_LAVORO_DOCUMENTI"

        if not exist "!WORKAREA!" (
            mkdir "!WORKAREA!" >nul 2>&1
        )

        echo [OK] Cartella documenti cliente rilevata:
        echo %DOCS_SOURCE%
        echo [OK] Area di lavoro pronta:
        echo !WORKAREA!

        > "!WORKAREA!\README_AREA_LAVORO.txt" echo AREA DI LAVORO DPI GUARDIAN
        >> "!WORKAREA!\README_AREA_LAVORO.txt" echo.
        >> "!WORKAREA!\README_AREA_LAVORO.txt" echo Cartella documenti cliente indicata:
        >> "!WORKAREA!\README_AREA_LAVORO.txt" echo %DOCS_SOURCE%
        >> "!WORKAREA!\README_AREA_LAVORO.txt" echo.
        >> "!WORKAREA!\README_AREA_LAVORO.txt" echo Questa area e stata preparata per i prossimi passaggi di analisi, ordine e lavoro documentale.
    ) else (
        set "WORKAREA=%DEST%\AREA_LAVORO_DOCUMENTI_TEST"

        if not exist "!WORKAREA!" (
            mkdir "!WORKAREA!" >nul 2>&1
        )

        echo [WARNING] La cartella indicata non esiste. Creo una cartella di test locale.
        echo [OK] Area di lavoro di test creata:
        echo !WORKAREA!

        > "!WORKAREA!\README_AREA_LAVORO.txt" echo AREA DI LAVORO DPI GUARDIAN - TEST
        >> "!WORKAREA!\README_AREA_LAVORO.txt" echo.
        >> "!WORKAREA!\README_AREA_LAVORO.txt" echo La cartella indicata dal cliente non e stata trovata.
        >> "!WORKAREA!\README_AREA_LAVORO.txt" echo E stata quindi creata un'area di lavoro di test.
        >> "!WORKAREA!\README_AREA_LAVORO.txt" echo.
        >> "!WORKAREA!\README_AREA_LAVORO.txt" echo Valore inserito:
        >> "!WORKAREA!\README_AREA_LAVORO.txt" echo %DOCS_SOURCE%
    )
) else (
    echo [INFO] Passaggio cartella documenti saltato.
)

set "SUPPORTDIR=%DEST%\05_SUPPORTO"
set "TRAININGCSV=%SUPPORTDIR%\TRAINING_INIZIALE_CESARI.csv"
set "OPCSV=%SUPPORTDIR%\OPERATORI_CAMPIONE.csv"
set "CASICSV=%SUPPORTDIR%\CASI_VERIFICA_INIZIALI.csv"

(
    echo FileOriginale,CategoriaArchivistica,PrioritaDashboard,Soggetto,SerialeMatricola,DataVerifica,ProssimaScadenza,DecisioneUmana,Note
) > "%TRAININGCSV%"

(
    echo Ordine,NomeCognome,RepartoFunzione,IdInterno,Dispositivo1,Dispositivo2,SerialeMatricola,UltimaVerifica,ProssimaScadenza
) > "%OPCSV%"

(
    echo Ordine,TipoCaso,FileRiferimento,DecisioneAttesa,Note
    echo 1,CERTIFICATO_PULITO,,CERTIFICATI,
    echo 2,MANUALE_PULITO,,MANUALI,
    echo 3,REVISIONE_COMPILATA,,REVISIONI,
    echo 4,DOCUMENTO_CLIENTE,,DOCUMENTI_CLIENTE,
    echo 5,SCANSIONE_MISTA,,DA_VALUTARE_CON_PRIORITA,
) > "%CASICSV%"

echo.
echo ==========================================
echo FORMAZIONE INIZIALE CESARI
echo ==========================================
echo.
echo Consigliato: inserire ora 2 utilizzatori campione completi.
echo Questo aiuta i CESARI a partire gia formati.
echo Premi INVIO su Nome utilizzatore 1 per saltare questa fase.
echo.

set "OP1_NOME="
set /p "OP1_NOME=Utilizzatore 1 - Nome e cognome: "

if defined OP1_NOME (
    set "OP1_NOME=%OP1_NOME:"=%"

    set "OP1_REPARTO="
    set /p "OP1_REPARTO=Utilizzatore 1 - Reparto/Funzione: "
    set "OP1_REPARTO=%OP1_REPARTO:"=%"

    set "OP1_ID="
    set /p "OP1_ID=Utilizzatore 1 - ID interno: "
    set "OP1_ID=%OP1_ID:"=%"

    set "OP1_D1="
    set /p "OP1_D1=Utilizzatore 1 - Dispositivo 1: "
    set "OP1_D1=%OP1_D1:"=%"

    set "OP1_D2="
    set /p "OP1_D2=Utilizzatore 1 - Dispositivo 2: "
    set "OP1_D2=%OP1_D2:"=%"

    set "OP1_SERIALE="
    set /p "OP1_SERIALE=Utilizzatore 1 - Seriale/Matricola: "
    set "OP1_SERIALE=%OP1_SERIALE:"=%"

    set "OP1_ULTIMA="
    set /p "OP1_ULTIMA=Utilizzatore 1 - Ultima verifica: "
    set "OP1_ULTIMA=%OP1_ULTIMA:"=%"

    set "OP1_PROSSIMA="
    set /p "OP1_PROSSIMA=Utilizzatore 1 - Prossima scadenza: "
    set "OP1_PROSSIMA=%OP1_PROSSIMA:"=%"

    >> "%OPCSV%" echo 1,!OP1_NOME!,!OP1_REPARTO!,!OP1_ID!,!OP1_D1!,!OP1_D2!,!OP1_SERIALE!,!OP1_ULTIMA!,!OP1_PROSSIMA!
    echo [OK] Utilizzatore 1 salvato.
) else (
    echo [INFO] Formazione iniziale CESARI saltata.
    goto after_training
)

echo.
set "OP2_NOME="
set /p "OP2_NOME=Utilizzatore 2 - Nome e cognome: "

if defined OP2_NOME (
    set "OP2_NOME=%OP2_NOME:"=%"

    set "OP2_REPARTO="
    set /p "OP2_REPARTO=Utilizzatore 2 - Reparto/Funzione: "
    set "OP2_REPARTO=%OP2_REPARTO:"=%"

    set "OP2_ID="
    set /p "OP2_ID=Utilizzatore 2 - ID interno: "
    set "OP2_ID=%OP2_ID:"=%"

    set "OP2_D1="
    set /p "OP2_D1=Utilizzatore 2 - Dispositivo 1: "
    set "OP2_D1=%OP2_D1:"=%"

    set "OP2_D2="
    set /p "OP2_D2=Utilizzatore 2 - Dispositivo 2: "
    set "OP2_D2=%OP2_D2:"=%"

    set "OP2_SERIALE="
    set /p "OP2_SERIALE=Utilizzatore 2 - Seriale/Matricola: "
    set "OP2_SERIALE=%OP2_SERIALE:"=%"

    set "OP2_ULTIMA="
    set /p "OP2_ULTIMA=Utilizzatore 2 - Ultima verifica: "
    set "OP2_ULTIMA=%OP2_ULTIMA:"=%"

    set "OP2_PROSSIMA="
    set /p "OP2_PROSSIMA=Utilizzatore 2 - Prossima scadenza: "
    set "OP2_PROSSIMA=%OP2_PROSSIMA:"=%"

    >> "%OPCSV%" echo 2,!OP2_NOME!,!OP2_REPARTO!,!OP2_ID!,!OP2_D1!,!OP2_D2!,!OP2_SERIALE!,!OP2_ULTIMA!,!OP2_PROSSIMA!
    echo [OK] Utilizzatore 2 salvato.
) else (
    echo [INFO] Utilizzatore 2 non inserito.
)

:after_training
(
    echo README TRAINING CESARI
    echo.
    echo File principali:
    echo %TRAININGCSV%
    echo %OPCSV%
    echo %CASICSV%
    echo.
    echo Regola consigliata:
    echo - inserire 2 operatori campione completi
    echo - verificare 5 casi reali iniziali
    echo - usare queste decisioni per affinare dashboard e classificazione
) > "%SUPPORTDIR%\README_TRAINING_CESARI.txt"

echo [OK] Training CESARI predisposto:
echo %TRAININGCSV%
echo [OK] Operatori campione:
echo %OPCSV%
echo [OK] Casi iniziali:
echo %CASICSV%

if exist "%DEST%\02_OUTPUT\dashboard_data.json" (
    del /f /q "%DEST%\02_OUTPUT\dashboard_data.json" >nul 2>&1
)
if exist "%DEST%\02_OUTPUT\DPI_GUARDIAN_DEMO_REPORT.txt" (
    del /f /q "%DEST%\02_OUTPUT\DPI_GUARDIAN_DEMO_REPORT.txt" >nul 2>&1
)
if exist "%DEST%\03_PRESENTAZIONE\console\dashboard_data.json" (
    del /f /q "%DEST%\03_PRESENTAZIONE\console\dashboard_data.json" >nul 2>&1
)
echo [OK] Runtime sporco pulito.

set "REQ1=%DEST%\START_DEMO.bat"
set "REQ2=%DEST%\03_PRESENTAZIONE\console\index.html"
set "REQ3=%DEST%\04_SCRIPT\DPI_GUARDIAN_RUN.ps1"
set "REQ4=%DEST%\04_SCRIPT\run_local.ps1"

set "MISSING=0"

if exist "%REQ1%" (
    echo [OK] File presente: %REQ1%
) else (
    echo [ERRORE] File obbligatorio mancante: %REQ1%
    set "MISSING=1"
)

if exist "%REQ2%" (
    echo [OK] File presente: %REQ2%
) else (
    echo [ERRORE] File obbligatorio mancante: %REQ2%
    set "MISSING=1"
)

if exist "%REQ3%" (
    echo [OK] File presente: %REQ3%
) else (
    echo [ERRORE] File obbligatorio mancante: %REQ3%
    set "MISSING=1"
)

if exist "%REQ4%" (
    echo [OK] File presente: %REQ4%
) else (
    echo [ERRORE] File obbligatorio mancante: %REQ4%
    set "MISSING=1"
)

if "%MISSING%"=="1" (
    echo.
    echo [ERRORE] Installazione incompleta.
    echo.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo INSTALLAZIONE COMPLETATA
echo Cartella installata:
echo %DEST%
echo ==========================================
echo.

choice /C SA /N /M "Premi S per avviare subito la demo oppure A per aprire la cartella: "
if errorlevel 2 (
    start "" "%DEST%"
) else (
    call "%DEST%\START_DEMO.bat"
)

endlocal
exit /b 0