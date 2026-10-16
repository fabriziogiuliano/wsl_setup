@echo off
rem Prepara il PC per entrambe le cose, con un doppio clic e senza amministratore:
rem   1. wsl_ssh        Ubuntu in WSL raggiungibile via SSH (solo con chiave)
rem   2. monitor_agent  invio del traffico del PC al monitor
rem Le due parti restano indipendenti: questo file lancia solo, una dopo l'altra,
rem le loro installazioni (si possono sempre usare anche separatamente).
set "ROOT=%~dp0"
if not exist "%ROOT%wsl_ssh\setup_wsl.ps1" goto :noextract
if not exist "%ROOT%monitor_agent\install_agent.ps1" goto :noextract

rem Toglie il segno "scaricato da internet" a tutti gli script
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%ROOT%' -Recurse -Filter *.ps1 | Unblock-File"

echo.
echo ===================== 1/2  WSL + SSH =====================
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%wsl_ssh\setup_wsl.ps1"
set "RC_SSH=%errorlevel%"

echo.
echo ================= 2/2  Agent del monitor =================
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%monitor_agent\install_agent.ps1"
set "RC_AGENT=%errorlevel%"

echo.
echo ======================== Riepilogo ========================
if "%RC_SSH%"=="0" (echo WSL + SSH:          OK) else (echo WSL + SSH:          ERRORE, vedi sopra)
if "%RC_AGENT%"=="0" (echo Agent del monitor:  OK) else (echo Agent del monitor:  ERRORE, vedi sopra)
echo.
pause
exit /b 0

:noextract
echo Non trovo le cartelle wsl_ssh e monitor_agent accanto a questo file.
echo Estrai prima tutto lo zip, poi rilancia install.bat.
pause
exit /b 1
