@echo off
rem Lab Network Monitor - install_agent.ps1 con un doppio clic, senza amministratore.
set "PS1=%~dp0install_agent.ps1"
if not exist "%PS1%" (
    echo Non trovo install_agent.ps1 accanto a questo file.
    echo Estrai prima tutta la cartella dallo zip, poi rilancia install.bat.
    pause
    exit /b 1
)
rem Unblock-File toglie il segno "scaricato da internet" lasciato dal browser
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -Filter *.ps1 | Unblock-File; & '%PS1%'"
echo.
pause
