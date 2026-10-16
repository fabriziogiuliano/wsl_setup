<#
    Lab Network Monitor - agent per PC Windows.

    Ogni "interval" secondi raccoglie le connessioni e il traffico del PC e li invia
    al server del monitor (POST /api/report). Non serve amministratore: netstat -ano
    mostra le connessioni di tutti i processi anche a un utente normale.

    Report (il parsing lo fa il server, l'agent invia l'output grezzo):
      netstat    'netstat -ano'  connessioni TCP/UDP con PID
      pids       PID -> nome processo, solo per i PID presenti in netstat
      netstat_e  'netstat -e'    byte totali ricevuti/inviati (per la banda)
      ss         'ss -tunp' della distro WSL, se ce n'e' una in esecuzione
                 (le connessioni di WSL2 non compaiono in netstat)
      ips        IPv4 del PC (rilevamento delle connessioni fra PC del laboratorio)

    Configurazione in agent.conf (stessa cartella), righe chiave=valore:
      server=http://<IP del monitor>:8080   token=<agent.token di config.yml>
      interval=2   name=<nome mostrato, default nome del PC>   wsl=1

    Installato e avviato da install_agent.ps1; gira nascosto (conhost --headless).
#>
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "agent.conf")
)

$ErrorActionPreference = "Continue"
$env:WSL_UTF8 = "1"                                       # output di wsl.exe in UTF-8, non UTF-16

# Una sola istanza per utente
$mutex = New-Object System.Threading.Mutex($false, "Local\LabMonitorAgent")
if (-not $mutex.WaitOne(0)) { exit 0 }

$conf = @{ interval = "2"; wsl = "1"; name = "" }
foreach ($l in Get-Content $ConfigPath -ErrorAction Stop) {
    if ($l -match '^\s*([a-z_]+)\s*=\s*(.*?)\s*$') { $conf[$Matches[1]] = $Matches[2] }
}
$url      = $conf["server"].TrimEnd("/") + "/api/report"
$headers  = @{ Authorization = "Bearer $($conf['token'])" }
$interval = [double]$conf["interval"]
$sys32    = Join-Path $env:SystemRoot "System32"
$useWsl   = ($conf["wsl"] -ne "0") -and [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue)

# Il monitor e' sulla rete locale: niente proxy di sistema (se c'e', in un'aula
# spesso intercetta o blocca le richieste verso IP interni).
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy

$pidNames = @{}; $pidAt = [datetime]::MinValue
$ips      = @(); $ipsAt = [datetime]::MinValue
$ssText   = ""; $wslAt = [datetime]::MinValue

while ($true) {
    $t0 = Get-Date
    try {
        $netstat = @(& "$sys32\netstat.exe" -ano)
        $netE    = (& "$sys32\netstat.exe" -e) -join "`n"

        # PID -> nome: aggiornato quando compare un PID sconosciuto (al massimo
        # una volta al secondo), cosi' anche un ssh.exe appena lanciato ha il nome.
        $pids = foreach ($line in $netstat) {
            $f = $line.Trim() -split '\s+'
            if ($f[0] -eq "TCP" -or $f[0] -eq "UDP") { $f[-1] }
        }
        $unknown = @($pids | Where-Object { -not $pidNames.ContainsKey($_) })
        if ($unknown.Count -gt 0 -and ((Get-Date) - $pidAt).TotalSeconds -ge 1) {
            $pidNames = @{}
            foreach ($p in Get-Process) { $pidNames["$($p.Id)"] = "$($p.ProcessName).exe" }
            $pidAt = Get-Date
        }
        $names = @{}
        foreach ($id in ($pids | Select-Object -Unique)) {
            if ($pidNames.ContainsKey($id)) { $names[$id] = $pidNames[$id] }
        }

        # IP del PC: cambiano di rado, ogni 30 s
        if (((Get-Date) - $ipsAt).TotalSeconds -ge 30) {
            $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                     Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
                     ForEach-Object { $_.IPAddress })
            $ipsAt = Get-Date
        }

        # WSL: solo se una distro e' gia' in esecuzione (non la avvia), ogni 5 s
        if ($useWsl -and ((Get-Date) - $wslAt).TotalSeconds -ge 5) {
            $running = ((& wsl.exe --list --running --quiet 2>$null) -join "") -replace "`0", ""
            $ssText = if ($LASTEXITCODE -eq 0 -and $running.Trim()) { (& wsl.exe -e ss -tunp 2>$null) -join "`n" } else { "" }
            $wslAt = Get-Date
        }

        $body = @{
            v         = 1
            os        = "windows"
            hostname  = $env:COMPUTERNAME
            name      = $conf["name"]
            user      = $env:USERNAME
            ips       = $ips
            netstat   = $netstat -join "`n"
            netstat_e = $netE
            pids      = $names
            ss        = $ssText
        } | ConvertTo-Json -Compress -Depth 4
        Invoke-RestMethod -Uri $url -Method Post -Headers $headers -TimeoutSec 5 `
            -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
    } catch {
        # Server non raggiungibile o errore temporaneo: si riprova al giro dopo.
        # Il monitor vede comunque l'interruzione (host disconnesso).
    }
    $wait = $interval - ((Get-Date) - $t0).TotalSeconds
    if ($wait -gt 0) { Start-Sleep -Milliseconds ([int]($wait * 1000)) }
}
