@echo off
rem Annulla install.bat con un doppio clic: rimuove la configurazione WSL + SSH.
rem Ubuntu e i suoi file restano (vedi wsl_ssh\uninstall_wsl.ps1, -RemoveDistro).
set "ROOT=%~dp0"
if not exist "%ROOT%wsl_ssh\uninstall_wsl.ps1" goto :noextract

echo Verra' rimossa la configurazione SSH di WSL.
echo Ubuntu e i suoi file NON vengono toccati. I terminali Ubuntu aperti si chiudono.
echo.
choice /c SN /m "Procedere"
if errorlevel 2 exit /b 1

rem Toglie il segno "scaricato da internet" a tutti gli script
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%ROOT%' -Recurse -Filter *.ps1 | Unblock-File"

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%wsl_ssh\uninstall_wsl.ps1" -Yes
echo.
pause
exit /b 0

:noextract
echo Non trovo la cartella wsl_ssh accanto a questo file.
echo Estrai prima tutto lo zip, poi rilancia uninstall.bat.
pause
exit /b 1
