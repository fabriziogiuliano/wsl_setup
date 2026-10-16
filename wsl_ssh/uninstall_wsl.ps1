<#
    Lab Network Monitor - disinstallazione di quanto fatto da setup_wsl.ps1.

    Da eseguire dalla stessa sessione utente del setup (doppio clic su uninstall.bat).
    Usa lo stato salvato dal setup alla prima esecuzione per rimettere il PC com'era:
      1. Distro: NON viene mai eliminata (salvo -RemoveDistro). Si annullano le
         modifiche: chiavi del monitor, openssh-server (se installato dal setup,
         altrimenti torna disabilitato se lo era), login solo a chiave, avvio di sshd,
         systemd. L'utente creato dal setup viene eliminato solo se la distro c'era
         gia'; se l'ha installata il setup e' il suo utente principale e resta.
      2. .wslconfig: networkingMode e firewall tornano ai valori originali (il file
         viene cancellato se prima non esisteva).
      3. 'wsl --shutdown' per applicare (chiude i terminali Ubuntu aperti).

    Parametri:
      -Yes            non chiede conferma
      -RemoveDistro   elimina la distro, con TUTTI i file al suo interno, se l'aveva
                      installata il setup (wsl --unregister: non si recupera)
#>
param(
    [switch]$Yes,
    [switch]$RemoveDistro
)

# Non "Stop": in Windows PowerShell 5.1 lo stderr di wsl.exe diventerebbe un errore
# fatale; gli esiti dei comandi sono controllati esplicitamente.
$ErrorActionPreference = "Continue"
$env:WSL_UTF8 = "1"                                       # output di wsl.exe in UTF-8, non UTF-16

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERRORE: $msg" -ForegroundColor Red; exit 1 }
function WslLines($wslArgs) { @(& wsl.exe @wslArgs 2>$null) | ForEach-Object { ($_ -replace "`0", "").Trim() } | Where-Object { $_ } }

# Imposta key=value nella sezione [section] (stessa funzione di setup_wsl.ps1)
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

# Toglie key dalla sezione [section]
function Remove-IniKey([string[]]$lines, [string]$section, [string]$key) {
    $out = New-Object System.Collections.Generic.List[string]
    $inSec = $false
    foreach ($l in $lines) {
        if ($l -match '^\s*\[(.+)\]\s*$') { $inSec = ($Matches[1].Trim() -ieq $section) }
        elseif ($inSec -and $l -match "^\s*$key\s*=") { continue }
        $out.Add($l)
    }
    , $out.ToArray()
}

# --- 0. Stato salvato dal setup ----------------------------------------------
$stateFile = Join-Path $env:LOCALAPPDATA "LabMonitor\setup_state.json"
if (-not (Test-Path $stateFile)) {
    Write-Host "Nessuno stato del setup per l'utente $env:USERDOMAIN\$env:USERNAME`: niente da disinstallare." -ForegroundColor Yellow
    Write-Host "(La disinstallazione va eseguita dallo stesso account Windows che ha eseguito il setup.)"
    exit 0
}
$state   = Get-Content $stateFile -Raw | ConvertFrom-Json
$Distro  = $state.Distro
$present = (WslLines @("-l", "-q")) -contains $Distro

Write-Host "Utente Windows: $env:USERDOMAIN\$env:USERNAME   Distro: $Distro"
Write-Host "Verra' fatto:"
if (-not $present)            { Write-Host "  - distro ${Distro}: gia' assente, nulla da fare" }
elseif ($state.DistroCreated -and $RemoveDistro) { Write-Host "  - distro ${Distro}: ELIMINATA con tutti i file al suo interno" -ForegroundColor Yellow }
else                          { Write-Host "  - distro ${Distro}: resta, si annullano solo le modifiche del setup (SSH, chiavi, configurazione)" }
Write-Host "  - .wslconfig: ripristino di networkingMode e firewall"
Write-Host "  - riavvio di WSL (i terminali Ubuntu aperti vengono chiusi)"
if (-not $Yes) {
    $ans = Read-Host "`nProcedere? [s/N]"
    if ($ans -notmatch '^[sSyY]') { Write-Host "Annullato."; exit 1 }
}

# --- 1. Distro ---------------------------------------------------------------
Step "Distro $Distro"
if (-not $present) {
    Write-Host "  non presente"
} elseif ($state.DistroCreated -and $RemoveDistro) {
    & wsl.exe --terminate $Distro *> $null
    & wsl.exe --unregister $Distro
    if ((WslLines @("-l", "-q")) -contains $Distro) { Fail "eliminazione di $Distro non riuscita" }
    # WSL meno recenti installano anche l'app dello Store: si rimuove pure quella
    Get-AppxPackage -Name ("CanonicalGroupLimited." + ($Distro -replace '-', '') + "*") -ErrorAction SilentlyContinue |
        Remove-AppxPackage -ErrorAction SilentlyContinue
    Write-Host "  eliminata"
} else {
    $LinuxCmds = @'
M=/etc/labmonitor-setup
if [ ! -f "$M" ]; then echo "  nessuna traccia del setup nella distro"; exit 0; fi
. "$M"
# Distro installata dal setup e tenuta: l'utente creato e' il suo utente principale, resta
[ "$1" = 1 ] && user_created=0
export DEBIAN_FRONTEND=noninteractive
rm -f /etc/ssh/sshd_config.d/10-labmonitor.conf
rm -f /usr/local/sbin/labmonitor-sshd /etc/sudoers.d/labmonitor-sshd /etc/profile.d/labmonitor-sshd.sh
pkill -x sshd 2>/dev/null
if [ "$ssh_installed" = 1 ]; then
    apt-get purge -y -qq openssh-server >/dev/null && echo "  openssh-server rimosso"
elif [ "$ssh_enabled" = 0 ]; then
    systemctl disable --now ssh ssh.socket >/dev/null 2>&1; echo "  ssh disabilitato"
fi
# Chiavi del monitor: tolte da authorized_keys se l'utente resta
H=$(getent passwd "$user" | cut -d: -f6)
if [ "$user_created" != 1 ] && [ -f /etc/labmonitor-authorized-keys ] && [ -f "$H/.ssh/authorized_keys" ]; then
    grep -vxFf /etc/labmonitor-authorized-keys "$H/.ssh/authorized_keys" > "$H/.ssh/authorized_keys.tmp"
    cat "$H/.ssh/authorized_keys.tmp" > "$H/.ssh/authorized_keys"; rm -f "$H/.ssh/authorized_keys.tmp"
    echo "  chiavi del monitor rimosse"
fi
rm -f /etc/labmonitor-authorized-keys
if [ "$user_created" = 1 ] && id "$user" >/dev/null 2>&1; then
    pkill -KILL -u "$user" 2>/dev/null; sleep 1
    userdel -r "$user" 2>/dev/null || userdel -f "$user"
    echo "  utente $user eliminato"
fi
# /etc/wsl.conf: systemd torna al valore originale (o sparisce se non c'era)
python3 - "$systemd_orig" <<'PY'
import configparser, sys
orig = sys.argv[1]
c = configparser.ConfigParser()
c.optionxform = str
c.read("/etc/wsl.conf")
if orig:
    if not c.has_section("boot"):
        c.add_section("boot")
    c.set("boot", "systemd", orig)
elif c.has_section("boot"):
    c.remove_option("boot", "systemd")
    if not c.options("boot"):
        c.remove_section("boot")
with open("/etc/wsl.conf", "w") as f:
    c.write(f)
PY
rm -f "$M"
echo "  modifiche annullate"
'@ -replace "`r", ""
    $shWin = Join-Path $env:TEMP "labmonitor_uninstall.sh"
    [IO.File]::WriteAllText($shWin, $LinuxCmds, (New-Object Text.UTF8Encoding $false))
    try {
        $shLinux = (& wsl.exe -d $Distro -u root -- wslpath -a ($shWin -replace '\\', '/')).Trim()
        & wsl.exe -d $Distro -u root -- bash $shLinux ([int][bool]$state.DistroCreated)
        $rc = $LASTEXITCODE
    } finally {
        Remove-Item $shWin -ErrorAction SilentlyContinue
    }
    if ($rc -ne 0) { Fail "pulizia dentro $Distro non riuscita" }
}

# --- 2. .wslconfig -----------------------------------------------------------
Step "Ripristino di .wslconfig"
$cfg = Join-Path $env:USERPROFILE ".wslconfig"
if (Test-Path $cfg) {
    $lines = @(Get-Content $cfg)
    foreach ($k in @(@("networkingMode", $state.NetworkingMode), @("firewall", $state.Firewall))) {
        if ($null -ne $k[1]) { $lines = Set-IniKey $lines "wsl2" $k[0] $k[1] }
        else                 { $lines = Remove-IniKey $lines "wsl2" $k[0] }
    }
    $rest = @($lines | Where-Object { $_.Trim() -and $_.Trim() -ine "[wsl2]" })
    if (-not $state.WslConfigExisted -and -not $rest) {
        Remove-Item $cfg
        Write-Host "  cancellato (non esisteva prima del setup)"
    } else {
        [IO.File]::WriteAllLines($cfg, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
        Write-Host "  ripristinato: $cfg"
    }
} else {
    Write-Host "  non presente"
}

# --- 3. Applica e pulizia ----------------------------------------------------
Step "Riavvio di WSL"
& wsl.exe --shutdown
Remove-Item (Split-Path $stateFile) -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "------------ Disinstallazione completata ------------" -ForegroundColor Green
