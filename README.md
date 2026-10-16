# wsl_setup

Prepara un PC Windows del laboratorio perché sia raggiungibile via SSH dentro WSL,
**senza permessi di amministratore**, e lo rimette com'era a fine utilizzo.
Pensato per [lab_monitor](https://github.com/fabriziogiuliano/lab_monitor), che si
collega ai PC per monitorarne il traffico di rete.

## Cosa fa `setup.bat`

1. In `%USERPROFILE%\.wslconfig` attiva il networking **mirrored** (WSL usa lo stesso IP
   del PC) e `firewall=false` (il firewall Hyper-V non blocca SSH in ingresso verso WSL).
2. Installa **Ubuntu-24.04** se manca (serve internet).
3. In Ubuntu crea l'utente (default `cn`, con `sudo`), installa `openssh-server` e
   autorizza le chiavi in [`authorized_keys`](authorized_keys). **Si entra solo con la
   chiave**: il login SSH a password è disattivato, la password serve solo a `sudo`.
4. Riavvia WSL e verifica che `sshd` sia attivo.

`sshd` parte da solo quando si apre Ubuntu (systemd su WSL2, `/etc/profile.d` su WSL1) e
si ferma quando WSL si spegne: il PC è raggiungibile finché Ubuntu resta aperto.

## Uso

Su ogni PC, dall'account Windows degli studenti:

1. **Code → Download ZIP** da GitHub, poi tasto destro sullo zip → **Estrai tutto**.
2. Doppio clic su `setup.bat` e inserisci la password dell'utente Linux quando richiesta
   (oppure mettila prima in `credentials.txt`, vedi `credentials.example.txt`).
3. Il riepilogo finale deve riportare `sshd attivo: SI`.

Dal monitor: `ssh -i <chiave privata> cn@<IP del PC>`.

Se la finestra si chiude senza mostrare nulla, lancia lo script da PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup_wsl.ps1
```

## Disinstallazione

Doppio clic su `uninstall.bat`, dallo **stesso account Windows** del setup. Usa lo stato
salvato alla prima esecuzione per rimettere tutto com'era:

- se Ubuntu l'ha installata il setup viene **eliminata con tutti i file** (chiede conferma);
- se c'era già, si annullano solo le modifiche (utente, chiavi, ssh, configurazione);
- `.wslconfig` torna ai valori originali.

## Requisiti e limiti

- WSL già installato (installarlo la prima volta richiede un amministratore).
- Il mirror richiede **Windows 11 22H2+** e WSL2. Con **WSL1** (es. PC o VM senza
  virtualizzazione) WSL usa già l'IP del PC, ma la porta 22 resta dietro il firewall di
  Windows: serve un amministratore per aprirla.
- Una policy dell'IT può impedire `firewall=false`: in quel caso SSH resta bloccato.

## Se riusi questi script

[`authorized_keys`](authorized_keys) contiene la chiave pubblica di **chi mantiene questo
repository**: sostituiscila con la tua, altrimenti dai a lui l'accesso ai tuoi PC.

```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/lab_monitor_ed25519
cat ~/.ssh/lab_monitor_ed25519.pub   # incollala in authorized_keys
```
