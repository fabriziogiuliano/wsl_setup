<#
    Lab Network Monitor - preparazione di un PC Windows SENZA permessi di amministratore.

    Da eseguire una volta per PC, dalla sessione dell'account comune degli studenti
    (doppio clic su setup.bat). Dopo, finche' Ubuntu e' aperto, il PC e' raggiungibile
    via SSH dal monitor all'IP del PC stesso.

    Cosa fa (idempotente: rieseguirlo non rompe nulla):
      1. .wslconfig dell'utente: networkingMode=mirrored (WSL sull'IP del PC) e
         firewall=false (il firewall Hyper-V non blocca SSH in ingresso verso WSL).
      2. Installa Ubuntu-24.04 se manca (serve internet).
      3. Dentro Ubuntu, come root: utente del monitor con password (serve per sudo),
         chiave pubblica del monitor (file authorized_keys accanto allo script),
         openssh-server con accesso SOLO a chiave, avvio di sshd all'apertura
         della distro (systemd su WSL2, /etc/profile.d su WSL1).
      4. 'wsl --shutdown' per applicare tutto (chiude i terminali Ubuntu aperti)
         e verifica che sshd sia attivo.

    sshd parte da solo ogni volta che si apre Ubuntu e si ferma quando WSL si spegne
    (pochi secondi dopo aver chiuso l'ultimo terminale).

    Alla prima esecuzione salva lo stato iniziale del PC (%LOCALAPPDATA%\LabMonitor e
    /etc/labmonitor-setup nella distro): uninstall_wsl.ps1 lo usa per rimettere tutto com'era.
#>
param(
    [string]$Distro       = "Ubuntu-24.04",
    # Utente Linux con cui il monitor entra via SSH: uguale su tutti i PC.
    # Se non passati qui, vengono letti da credentials.txt (accanto allo script,
    # fuori da git: vedi credentials.example.txt); altrimenti cn / cn.
    [string]$LinuxUser    = "",
    [string]$LinuxPassword = ""
)

# Non "Stop": in Windows PowerShell 5.1 lo stderr di wsl.exe diventerebbe un errore
# fatale; gli esiti dei comandi sono controllati esplicitamente.
$ErrorActionPreference = "Continue"
$env:WSL_UTF8 = "1"                                       # output di wsl.exe in UTF-8, non UTF-16

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERRORE: $msg" -ForegroundColor Red; exit 1 }
function WslLines($wslArgs) { @(& wsl.exe @wslArgs 2>$null) | ForEach-Object { ($_ -replace "`0", "").Trim() } | Where-Object { $_ } }

# Imposta key=value nella sezione [section] di un file ini (righe), senza toccare il resto
function Set-IniKey([string[]]$lines, [string]$section, [string]$key, [string]$value) {
    $out = New-Object System.Collections.Generic.List[string]
    $inSec = $false; $secSeen = $false; $done = $false
    foreach ($l in $lines) {
        if ($l -match '^\s*\[(.+)\]\s*$') {
            if ($inSec -and -not $done) { $out.Add("$key=$value"); $done = $true }
            $inSec = ($Matches[1].Trim() -ieq $section)
            if ($inSec) { $secSeen = $true }
        } elseif ($inSec -and $l -match "^\s*$key\s*=") {
            if (-not $done) { $out.Add("$key=$value"); $done = $true }
            continue
        }
        $out.Add($l)
    }
    if (-not $done) {
        if (-not $secSeen) { $out.Add("[$section]") }
        $out.Add("$key=$value")
    }
    , $out.ToArray()
}

# Valore di key nella sezione [section], $null se assente
function Get-IniKey([string[]]$lines, [string]$section, [string]$key) {
    $inSec = $false; $val = $null
    foreach ($l in $lines) {
        if ($l -match '^\s*\[(.+)\]\s*$') { $inSec = ($Matches[1].Trim() -ieq $section) }
        elseif ($inSec -and $l -match "^\s*$key\s*=\s*(.*?)\s*$") { $val = $Matches[1] }
    }
    $val
}

# Stato iniziale del PC, salvato alla prima esecuzione: lo usa uninstall_wsl.ps1
# per rimettere tutto com'era (e cancellare la distro solo se l'ha creata il setup).
$stateFile = Join-Path $env:LOCALAPPDATA "LabMonitor\setup_state.json"

# --- 0. Prerequisiti ---------------------------------------------------------
$credFile = Join-Path $PSScriptRoot "credentials.txt"
if (Test-Path $credFile) {
    foreach ($l in Get-Content $credFile) {
        if ($l -match '^\s*user\s*=\s*(.*?)\s*$'     -and -not $LinuxUser)     { $LinuxUser = $Matches[1] }
        if ($l -match '^\s*password\s*=\s*(.*?)\s*$' -and -not $LinuxPassword) { $LinuxPassword = $Matches[1] }
    }
}
# Default cn/cn, senza chiedere nulla: l'accesso SSH e' solo a chiave, la
# password serve solo a sudo. Si cambiano con credentials.txt o i parametri.
if (-not $LinuxUser)     { $LinuxUser = "cn" }
if (-not $LinuxPassword) { $LinuxPassword = "cn" }
if ($LinuxUser -notmatch '^[a-z_][a-z0-9_-]*$') { Fail "nome utente Linux non valido: '$LinuxUser'" }
# Chiave pubblica del monitor: l'accesso SSH a password viene disattivato
$keysFile = Join-Path $PSScriptRoot "authorized_keys"
if (-not (Test-Path $keysFile) -or -not (Get-Content $keysFile | Where-Object { $_ -match '^\s*(ssh-|ecdsa-|sk-)' })) {
    Fail "manca la chiave pubblica del monitor in $keysFile"
}
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { Fail "WSL non e' presente su questo PC" }
& wsl.exe --status *> $null
if ($LASTEXITCODE -ne 0) { Fail "WSL non e' installato/abilitato: la prima installazione di WSL richiede un amministratore" }
if ([Environment]::OSVersion.Version.Build -lt 22621) {
    Write-Host "ATTENZIONE: il mirror richiede Windows 11 22H2 o successivo; qui potrebbe non funzionare." -ForegroundColor Yellow
}
Write-Host "Utente Windows: $env:USERDOMAIN\$env:USERNAME   Distro: $Distro   Utente Linux: $LinuxUser"

# --- 1. .wslconfig: mirror e firewall Hyper-V --------------------------------
Step "Configurazione WSL (.wslconfig)"
$cfg    = Join-Path $env:USERPROFILE ".wslconfig"
$before = if (Test-Path $cfg) { @(Get-Content $cfg) } else { @() }
if (Test-Path $stateFile) {
    $state = Get-Content $stateFile -Raw | ConvertFrom-Json
} else {
    $state = [pscustomobject]@{
        Distro         = $Distro
        DistroCreated  = $false
        WslConfigExisted = [bool](Test-Path $cfg)
        NetworkingMode = Get-IniKey $before "wsl2" "networkingMode"
        Firewall       = Get-IniKey $before "wsl2" "firewall"
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $stateFile) | Out-Null
    $state | ConvertTo-Json | Set-Content -Path $stateFile -Encoding ASCII
}
$after = Set-IniKey $before "wsl2" "networkingMode" "mirrored"
$after  = Set-IniKey $after  "wsl2" "firewall" "false"
if (($before -join "`n") -ne ($after -join "`n")) {
    [IO.File]::WriteAllLines($cfg, $after, (New-Object Text.UTF8Encoding $false))
    Write-Host "  aggiornato: $cfg"
} else {
    Write-Host "  gia' configurato"
}

# --- 2. Distro ---------------------------------------------------------------
Step "Distro $Distro"
$created = $false
if ((WslLines @("-l", "-q")) -notcontains $Distro) {
    Write-Host "  non presente: installazione (qualche minuto, serve internet)..."
    & wsl.exe --install -d $Distro --no-launch
    if ((WslLines @("-l", "-q")) -notcontains $Distro) {
        # WSL meno recenti installano l'app ma registrano la distro solo al primo avvio
        $launcher = "ubuntu" + ($Distro -replace '^Ubuntu-', '' -replace '\.', '') + ".exe"
        if (Get-Command $launcher -ErrorAction SilentlyContinue) { & $launcher install --root }
    }
    if ((WslLines @("-l", "-q")) -notcontains $Distro) { Fail "installazione di $Distro non riuscita" }
    $created = $true
    $state.DistroCreated = $true
    $state | ConvertTo-Json | Set-Content -Path $stateFile -Encoding ASCII
} else {
    Write-Host "  gia' installata"
}
$version = 0
foreach ($line in (WslLines @("-l", "-v"))) {
    if ($line -match "^\*?\s*$([regex]::Escape($Distro))\s+\S+\s+([12])$") { $version = [int]$Matches[1] }
}
Write-Host "  versione: WSL$version"
if ($version -eq 1) {
    Write-Host "  WSL1: il mirror non serve, ma la porta 22 resta dietro il firewall di Windows (serve un admin per aprirla)" -ForegroundColor Yellow
}

# --- 3. Utente, systemd e OpenSSH dentro Ubuntu ------------------------------
Step "Utente '$LinuxUser' e OpenSSH dentro $Distro"
$LinuxCmds = @'
set -e
export DEBIAN_FRONTEND=noninteractive
U="$1"; CRED="$2"; CREATED="$3"; KEYS="$4"
# Stato iniziale della distro, salvato solo alla prima esecuzione: lo usa la disinstallazione
M=/etc/labmonitor-setup
if [ ! -f "$M" ]; then
    {
        echo "user=$U"
        id "$U" >/dev/null 2>&1 && echo "user_created=0" || echo "user_created=1"
        dpkg -s openssh-server 2>/dev/null | grep -q "install ok installed" && echo "ssh_installed=0" || echo "ssh_installed=1"
        systemctl is-enabled ssh >/dev/null 2>&1 && echo "ssh_enabled=1" || echo "ssh_enabled=0"
        echo "systemd_orig=$(sed -n 's/^[[:space:]]*systemd[[:space:]]*=[[:space:]]*//p' /etc/wsl.conf 2>/dev/null | tail -n 1)"
    } > "$M"
fi
# Utente del monitor (sudo), password sempre riallineata a quella dello script
id "$U" >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo "$U"
chpasswd < "$CRED"
# Chiavi del monitor in authorized_keys (senza duplicati); l'elenco resta in
# /etc/labmonitor-authorized-keys perche' la disinstallazione sappia cosa togliere
H=$(getent passwd "$U" | cut -d: -f6); G=$(id -gn "$U")
tr -d '\r' < "$KEYS" | grep -E '^[[:space:]]*(ssh-|ecdsa-|sk-)' | sed 's/^[[:space:]]*//' > /etc/labmonitor-authorized-keys
install -d -m 700 -o "$U" -g "$G" "$H/.ssh"
touch "$H/.ssh/authorized_keys"
while IFS= read -r k; do
    grep -qxF "$k" "$H/.ssh/authorized_keys" || echo "$k" >> "$H/.ssh/authorized_keys"
done < /etc/labmonitor-authorized-keys
chown "$U:$G" "$H/.ssh/authorized_keys"; chmod 600 "$H/.ssh/authorized_keys"
# /etc/wsl.conf: systemd attivo (avvia sshd all'apertura della distro) e,
# se la distro l'ha creata lo script, utente predefinito = utente del monitor
python3 - "$U" "$CREATED" <<'PY'
import configparser, sys
user, created = sys.argv[1], sys.argv[2] == "1"
c = configparser.ConfigParser()
c.optionxform = str
c.read("/etc/wsl.conf")
for sec in ("boot",) + (("user",) if created else ()):
    if not c.has_section(sec):
        c.add_section(sec)
c.set("boot", "systemd", "true")
if created:
    c.set("user", "default", user)
with open("/etc/wsl.conf", "w") as f:
    c.write(f)
PY
# OpenSSH server
if ! dpkg -s openssh-server 2>/dev/null | grep -q "install ok installed"; then
    apt-get update -qq && apt-get install -y -qq openssh-server \
        || { echo "ERRORE: installazione openssh-server fallita (serve internet)"; exit 1; }
fi
# Accesso solo a chiave (il file in sshd_config.d prevale su quelli successivi):
# la password dell'utente serve solo a sudo, da dentro la sessione
printf '%s\n' "PubkeyAuthentication yes" "PasswordAuthentication no" "KbdInteractiveAuthentication no" \
    > /etc/ssh/sshd_config.d/10-labmonitor.conf
sshd -t && echo "sshd_config OK"
systemctl enable ssh >/dev/null 2>&1 || true
# Senza systemd (WSL1) sshd non parte da solo: lo avvia /etc/profile.d all'apertura
# di Ubuntu, tramite uno script senza argomenti che e' l'unico comando concesso
# da sudo senza password (non sshd stesso, che con -f/-o permetterebbe di tutto).
cat > /usr/local/sbin/labmonitor-sshd <<'SH'
#!/bin/sh
mkdir -p /run/sshd
pgrep -x sshd >/dev/null || /usr/sbin/sshd
SH
chmod 755 /usr/local/sbin/labmonitor-sshd
echo "ALL ALL=(root) NOPASSWD: /usr/local/sbin/labmonitor-sshd" > /etc/sudoers.d/labmonitor-sshd
chmod 440 /etc/sudoers.d/labmonitor-sshd
visudo -cf /etc/sudoers.d/labmonitor-sshd >/dev/null
cat > /etc/profile.d/labmonitor-sshd.sh <<'SH'
# Lab Network Monitor: senza systemd (WSL1) avvia sshd all'apertura di Ubuntu
[ -d /run/systemd/system ] || sudo -n /usr/local/sbin/labmonitor-sshd >/dev/null 2>&1
SH
'@ -replace "`r", ""
# Script e credenziali passati come file (LF, senza BOM): come argomenti di wsl.exe
# le virgolette non sopravvivono, e da una pipe la password arriverebbe con il CR finale.
$utf8   = New-Object Text.UTF8Encoding $false
$shWin  = Join-Path $env:TEMP "labmonitor_setup.sh"
$crWin  = Join-Path $env:TEMP "labmonitor_cred.txt"
$kyWin  = Join-Path $env:TEMP "labmonitor_keys.txt"
[IO.File]::WriteAllText($shWin, $LinuxCmds, $utf8)
[IO.File]::WriteAllText($crWin, "${LinuxUser}:${LinuxPassword}`n", $utf8)
Copy-Item $keysFile $kyWin -Force
try {
    $shLinux = (& wsl.exe -d $Distro -u root -- wslpath -a ($shWin -replace '\\', '/')).Trim()
    $crLinux = (& wsl.exe -d $Distro -u root -- wslpath -a ($crWin -replace '\\', '/')).Trim()
    $kyLinux = (& wsl.exe -d $Distro -u root -- wslpath -a ($kyWin -replace '\\', '/')).Trim()
    & wsl.exe -d $Distro -u root -- bash $shLinux $LinuxUser $crLinux ([int]$created) $kyLinux
    $rc = $LASTEXITCODE
} finally {
    Remove-Item $shWin, $crWin, $kyWin -ErrorAction SilentlyContinue
}
if ($rc -ne 0) { Fail "configurazione dentro $Distro non riuscita" }

# --- 4. Applica e verifica ---------------------------------------------------
Step "Riavvio di WSL per applicare la configurazione"
& wsl.exe --shutdown
# Con systemd (WSL2) ssh e' gestito da systemd; su WSL1 lo avvia lo script del passo 3.
# pgrep invece di ss: su WSL1 ss non funziona (niente netlink).
$check = & wsl.exe -d $Distro -u root -- bash -c "sleep 3; if [ -d /run/systemd/system ]; then systemctl is-active -q ssh.socket || systemctl is-active -q ssh.service; else /usr/local/sbin/labmonitor-sshd; sleep 1; pgrep -x sshd >/dev/null; fi && echo SI || echo NO; hostname -I"
$listening = "$($check | Select-Object -First 1)".Trim()
$wslIps    = ($check | Select-Object -Skip 1) -join " "
$winIps    = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
              Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" }).IPAddress -join ", "

Write-Host ""
Write-Host "------------ Riepilogo ------------" -ForegroundColor Green
Write-Host "PC:           $env:COMPUTERNAME"
Write-Host "IP Windows:   $winIps"
Write-Host "IP WSL:       $wslIps   (deve coincidere con quello di Windows)"
Write-Host "Distro:       $Distro (WSL$version)"
Write-Host "Utente SSH:   $LinuxUser (solo con chiave)"
Write-Host "sshd attivo:  $listening"
if ($listening -ne "SI") { Write-Host "sshd non risulta attivo." -ForegroundColor Red; exit 1 }
Write-Host "Il PC e' raggiungibile via SSH finche' Ubuntu resta aperto."
if ($version -eq 1) {
    Write-Host "WSL1: la porta 22 e' dietro il firewall di Windows; senza una regola (serve un admin) da fuori resta bloccata." -ForegroundColor Yellow
}
