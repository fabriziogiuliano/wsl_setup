@echo off
rem Annulla install.bat con un doppio clic: rimuove l'agent del monitor e la
rem configurazione WSL + SSH. Ubuntu e i suoi file restano.
set "ROOT=%~dp0"
if not exist "%ROOT%wsl_ssh\uninstall_wsl.ps1" goto :noextract
if not exist "%ROOT%monitor_agent\uninstall_agent.ps1" goto :noextract

echo Verranno rimossi l'agent del monitor e la configurazione SSH di WSL.
echo Ubuntu e i suoi file NON vengono toccati. I terminali Ubuntu aperti si chiudono.
echo.
choice /c SN /m "Procedere"
if errorlevel 2 exit /b 1

rem Toglie il segno "scaricato da internet" a tutti gli script
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%ROOT%' -Recurse -Filter *.ps1 | Unblock-File"

echo.
echo ================= 1/2  Agent del monitor =================
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%monitor_agent\uninstall_agent.ps1"

echo.
echo ===================== 2/2  WSL + SSH =====================
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%wsl_ssh\uninstall_wsl.ps1" -Yes
echo.
pause
exit /b 0

:noextract
echo Non trovo le cartelle wsl_ssh e monitor_agent accanto a questo file.
echo Estrai prima tutto lo zip, poi rilancia uninstall.bat.
pause
exit /b 1
