<#
    Lab Network Monitor - installa l'agent su questo PC, SENZA amministratore.

    Da eseguire dalla sessione dell'utente che usa il PC (doppio clic su install.bat).
      1. Legge server e token da agent.conf accanto allo script (se manca li chiede
         e lo crea) e verifica che il server risponda e accetti il token.
      2. Copia lab_agent.ps1 e agent.conf in %LOCALAPPDATA%\LabMonitorAgent.
      3. Collegamento in Esecuzione automatica: l'agent parte, nascosto, a ogni
         accesso dell'utente.
      4. Riavvia l'agent e controlla che il server riceva i report.
    Rieseguirlo aggiorna l'installazione (es. dopo aver cambiato agent.conf).
#>

$ErrorActionPreference = "Continue"
function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERRORE: $msg" -ForegroundColor Red; exit 1 }

$Dir      = Join-Path $env:LOCALAPPDATA "LabMonitorAgent"
$Shortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "LabMonitorAgent.lnk"
$Conhost  = Join-Path $env:SystemRoot "System32\conhost.exe"
$SrcConf  = Join-Path $PSScriptRoot "agent.conf"
$SrcAgent = Join-Path $PSScriptRoot "lab_agent.ps1"
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy   # come l'agent: niente proxy

if (-not (Test-Path $SrcAgent)) { Fail "manca lab_agent.ps1 accanto a questo script" }

# --- 1. Configurazione e verifica del server ---------------------------------
Step "Configurazione"
if (-not (Test-Path $SrcConf)) {
    # Primo avvio da una copia del repository: agent.conf non c'e' (contiene il
    # token, e' escluso da git). L'indirizzo proposto viene da agent.conf.example.
    $default = ""
    $example = Join-Path $PSScriptRoot "agent.conf.example"
    if (Test-Path $example) {
        $m = Select-String -Path $example -Pattern '^\s*server\s*=\s*(.*?)\s*$' | Select-Object -First 1
        if ($m) { $default = $m.Matches[0].Groups[1].Value }
    }
    $server = Read-Host "Indirizzo del monitor [$default]"
    if (-not $server) { $server = $default }
    $token  = Read-Host "Token (agent.token in app/config.yml del monitor)"
    if (-not $server -or -not $token) { Fail "server e token sono obbligatori" }
    [IO.File]::WriteAllText($SrcConf, "server=$server`r`ntoken=$token`r`ninterval=2`r`nwsl=1`r`n")
}
$conf = @{}
foreach ($l in Get-Content $SrcConf) {
    if ($l -match '^\s*([a-z_]+)\s*=\s*(.*?)\s*$') { $conf[$Matches[1]] = $Matches[2] }
}
if (-not $conf["server"] -or -not $conf["token"]) { Fail "agent.conf deve contenere server= e token=" }
$base    = $conf["server"].TrimEnd("/")
$headers = @{ Authorization = "Bearer $($conf['token'])" }
Write-Host "  server: $base"

function Ping-Monitor {
    Invoke-RestMethod -Uri "$base/api/ping" -Headers $headers -TimeoutSec 5
}
try {
    $ping = Ping-Monitor
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    if ($code -eq 401) { Fail "il server rifiuta il token: controlla token= in agent.conf" }
    Fail "server non raggiungibile ($($_.Exception.Message)). Il monitor e' avviato? Indirizzo e porta giusti?"
}
Write-Host "  il server vede questo PC come $($ping.ip)" -NoNewline
if ($ping.name) { Write-Host " -> '$($ping.name)'" } else { Write-Host " (non in hosts.csv)" -ForegroundColor Yellow }

# --- 2. Copia ----------------------------------------------------------------
Step "Installazione in $Dir"
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*LabMonitorAgent*lab_agent.ps1*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
Copy-Item $SrcAgent, $SrcConf -Destination $Dir -Force
Get-ChildItem $Dir | Unblock-File
$agentPath = Join-Path $Dir "lab_agent.ps1"
$argsLine  = "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$agentPath`""

# --- 3. Avvio automatico all'accesso -----------------------------------------
Step "Avvio automatico all'accesso"
$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut($Shortcut)
$lnk.TargetPath       = $Conhost
$lnk.Arguments        = $argsLine
$lnk.WorkingDirectory = $Dir
$lnk.WindowStyle      = 7
$lnk.Description      = "Lab Network Monitor agent"
$lnk.Save()
Write-Host "  $Shortcut"

# --- 4. Avvio e verifica -----------------------------------------------------
Step "Avvio dell'agent"
Start-Process -FilePath $Conhost -ArgumentList $argsLine -WorkingDirectory $Dir
$interval = if ($conf["interval"]) { [double]$conf["interval"] } else { 2 }
Start-Sleep -Seconds ([int][math]::Ceiling($interval * 2 + 3))
try { $ping = Ping-Monitor } catch { $ping = $null }

Write-Host ""
Write-Host "------------ Riepilogo ------------" -ForegroundColor Green
Write-Host "PC:        $env:COMPUTERNAME ($($ping.ip))"
Write-Host "Monitor:   $base"
if ($ping -and $null -ne $ping.last_report_age -and $ping.last_report_age -le ($interval * 3)) {
    Write-Host "Report:    ricevuti dal monitor come '$($ping.name)'" -ForegroundColor Green
    Write-Host "L'agent parte da solo a ogni accesso. Disinstallazione: uninstall.bat"
} else {
    Write-Host "Report:    il monitor non li riceve" -ForegroundColor Red
    Write-Host "Se il PC non e' in hosts.csv, il monitor deve avere agent.accept_unknown: true." -ForegroundColor Red
    exit 1
}
