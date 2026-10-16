@echo off
rem Lab Network Monitor - disinstallazione con un doppio clic, senza admin.
rem Da lanciare dalla stessa sessione utente in cui e' stato eseguito il setup:
rem esegue uninstall_wsl.ps1 (stessa cartella).

set "PS1=%~dp0uninstall_wsl.ps1"
if not exist "%PS1%" (
    echo Non trovo uninstall_wsl.ps1 accanto a questo file.
    echo Estrai prima tutta la cartella dallo zip, poi rilancia uninstall.bat.
    pause
    exit /b 1
)

rem Unblock-File toglie il segno "scaricato da internet" lasciato dal browser
powershell -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -LiteralPath '%PS1%'; & '%PS1%'"
echo.
pause
