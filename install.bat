@echo off
rem Prepara il PC con un doppio clic e senza amministratore: Ubuntu in WSL
rem raggiungibile via SSH (solo con chiave), per il monitor via SSH e per
rem l'accesso remoto. Esegue il setup di wsl_ssh.

set "ROOT=%~dp0"
if not exist "%ROOT%wsl_ssh\setup_wsl.ps1" goto :noextract

rem Toglie il segno "scaricato da internet" a tutti gli script
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%ROOT%' -Recurse -Filter *.ps1 | Unblock-File"

echo.
echo ======================== WSL + SSH ========================
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%wsl_ssh\setup_wsl.ps1"
set "RC_SSH=%errorlevel%"

echo.
echo ======================== Riepilogo ========================
if "%RC_SSH%"=="0" (echo WSL + SSH:  OK) else (echo WSL + SSH:  ERRORE, vedi sopra)
echo.
pause
exit /b 0

:noextract
echo Non trovo la cartella wsl_ssh accanto a questo file.
echo Estrai prima tutto lo zip, poi rilancia install.bat.
pause
exit /b 1
