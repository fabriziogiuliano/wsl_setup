<#
    Lab Network Monitor - rimuove l'agent da questo PC (doppio clic su uninstall.bat),
    dalla stessa sessione utente in cui e' stato installato: ferma l'agent, toglie
    il collegamento in Esecuzione automatica e cancella %LOCALAPPDATA%\LabMonitorAgent.
#>

$ErrorActionPreference = "Continue"
$Dir      = Join-Path $env:LOCALAPPDATA "LabMonitorAgent"
$Shortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "LabMonitorAgent.lnk"

$procs = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
           Where-Object { $_.CommandLine -like "*LabMonitorAgent*lab_agent.ps1*" })
$procs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host "Agent fermato ($($procs.Count) processi)"

Remove-Item $Shortcut -Force -ErrorAction SilentlyContinue
Write-Host "Avvio automatico rimosso"
Start-Sleep -Seconds 1
Remove-Item $Dir -Recurse -Force -ErrorAction SilentlyContinue
if (Test-Path $Dir) { Write-Host "ATTENZIONE: non riesco a cancellare $Dir" -ForegroundColor Yellow }
else { Write-Host "Cartella $Dir cancellata" }

Write-Host "`nAgent disinstallato. Il monitor segnalera' il PC come disconnesso." -ForegroundColor Green
