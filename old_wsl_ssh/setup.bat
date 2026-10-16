@echo off
rem Lab Network Monitor - preparazione del PC con un doppio clic, senza admin.
rem Da lanciare dalla sessione dell'account comune degli studenti: esegue
rem setup_wsl.ps1 (stessa cartella) per l'utente corrente.

set "PS1=%~dp0setup_wsl.ps1"
if not exist "%PS1%" (
    echo Non trovo setup_wsl.ps1 accanto a questo file.
    echo Estrai prima tutta la cartella dallo zip, poi rilancia setup.bat.
    pause
    exit /b 1
)

rem Unblock-File toglie il segno "scaricato da internet" lasciato dal browser
powershell -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -LiteralPath '%PS1%'; & '%PS1%'"
echo.
pause
