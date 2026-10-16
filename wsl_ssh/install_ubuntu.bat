@echo off
rem Installa Ubuntu-24.04 in WSL per l'utente corrente, con un doppio clic.
rem Non serve amministratore se WSL e' gia' presente sul PC. Se la distro c'e'
rem gia' non fa nulla: non tocca mai una Ubuntu esistente.
set "DISTRO=Ubuntu-24.04"
rem Output di wsl.exe in UTF-8 (altrimenti UTF-16 e findstr non lo legge)
set "WSL_UTF8=1"

wsl -l -q 2>nul | findstr /x /c:"%DISTRO%" >nul
if not errorlevel 1 (
    echo %DISTRO% e' gia' installata: niente da fare.
    pause
    exit /b 0
)

echo Installazione di %DISTRO%: qualche minuto, serve internet.
echo Al termine Ubuntu chiede di creare un utente e una password Linux:
echo poi scrivi "exit" per chiudere.
echo.
wsl --install -d %DISTRO%

wsl -l -q 2>nul | findstr /x /c:"%DISTRO%" >nul
if errorlevel 1 (
    echo.
    echo Installazione non riuscita. Se WSL non e' presente sul PC, installarlo
    echo la prima volta richiede un amministratore.
    pause
    exit /b 1
)
echo.
echo %DISTRO% installata. Si apre dal menu Start, cercando "Ubuntu".
pause
