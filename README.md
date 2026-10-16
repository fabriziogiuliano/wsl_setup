# wsl_setup — strumenti per i PC del laboratorio

Script da lanciare sui PC Windows del laboratorio, **senza amministratore**. Le due cartelle
sono **indipendenti**: si installano, si usano e si disinstallano separatamente, e nessuna
modifica ciò che fa l'altra.

| Cartella | A cosa serve | Richiede |
|---|---|---|
| [`monitor_agent/`](#monitor_agent--monitoraggio-della-rete) | il PC invia al [monitor](https://github.com/fabriziogiuliano/lab_monitor) il proprio traffico (esami) | solo che il PC raggiunga il monitor |
| [`wsl_ssh/`](#wsl_ssh--accesso-ssh-a-ubuntu-in-wsl) | accesso SSH (solo a chiave) a Ubuntu in WSL su ogni PC | porta 22 aperta verso WSL (firewall gestito dall'IT) |

**Code → Download ZIP** da GitHub, tasto destro sullo zip → **Estrai tutto**, poi:

- **tutto in una volta:** doppio clic su **`install.bat`** nella cartella principale. Esegue
  il setup di `wsl_ssh` e poi l'installazione di `monitor_agent`, e alla fine riporta l'esito
  di ciascuno;
- **una parte sola:** entra nella cartella che ti serve (sotto).

L'utente Linux è `cn` con password `cn`, senza chiedere nulla; al primo avvio vengono
chiesti solo l'indirizzo del monitor e il token (se manca `monitor_agent\agent.conf`). Per disinstallare si usano gli `uninstall.bat` delle due cartelle.

## `monitor_agent/` — monitoraggio della rete

Gira in background su ogni PC e invia ogni 2 secondi al monitor le connessioni e il
traffico del PC. È il PC che si collega al monitor: non va aperta nessuna porta sul PC.

1. Doppio clic su `install.bat`. Al primo avvio chiede:
   - l'indirizzo del monitor (invio per quello proposto, da `agent.conf.example`);
   - il **token**: `agent.token` in `app/config.yml` del monitor.

   Le risposte vengono salvate in `agent.conf` (escluso da git): copiando la cartella con
   `agent.conf` sugli altri PC non vengono più chieste.
2. Il riepilogo finale deve riportare **"Report: ricevuti dal monitor"**.

L'agent viene copiato in `%LOCALAPPDATA%\LabMonitorAgent` e parte, nascosto, a ogni
accesso dell'utente. **Disinstallazione:** `uninstall.bat` (stesso account): ferma l'agent,
toglie l'avvio automatico e cancella la sua cartella.

Cosa invia, ogni `interval` secondi (`POST /api/report`, con il token):
- `netstat -ano` — connessioni di tutti i programmi, con il nome del processo;
- `netstat -e` — byte totali, per la banda;
- gli IPv4 del PC;
- `ss -tunp` della distro WSL, **solo se è già in esecuzione** (le connessioni di WSL2 non
  compaiono in `netstat`); la legge soltanto, non la avvia. `wsl=0` in `agent.conf` lo
  disattiva.

## `wsl_ssh/` — accesso SSH a Ubuntu in WSL

| File | |
|---|---|
| `install_ubuntu.bat` | installa Ubuntu-24.04 se manca (se c'è già non fa nulla) |
| `setup.bat` | configura WSL per l'accesso SSH |
| `uninstall.bat` | annulla il setup |

`setup.bat`:
1. in `%USERPROFILE%\.wslconfig` attiva il networking **mirrored** (WSL usa l'IP del PC);
2. installa **Ubuntu-24.04** se manca (serve internet);
3. in Ubuntu crea l'utente `cn` con password `cn` (con `sudo`), installa `openssh-server`
   e autorizza le chiavi in [`authorized_keys`](wsl_ssh/authorized_keys): **si entra solo
   con la chiave**, la password serve solo a `sudo`. Per utente e password diversi c'è
   `credentials.txt` (vedi `credentials.example.txt`);
4. riavvia WSL e verifica che `sshd` sia attivo.

`sshd` parte quando si apre Ubuntu e si ferma quando WSL si spegne. Dall'esterno il PC è
raggiungibile solo se la porta 22 verso WSL è aperta nel firewall Hyper-V e in quello di
Windows: con un utente standard serve l'IT.

`uninstall.bat` (stesso account del setup) rimette tutto com'era usando lo stato salvato
dal setup, **senza eliminare Ubuntu**: toglie SSH, chiavi e configurazione e ripristina
`.wslconfig`. Per eliminare anche la distro, se l'aveva installata il setup, va lanciato da
PowerShell con `-RemoveDistro` (cancella **tutti** i file al suo interno).

> [`authorized_keys`](wsl_ssh/authorized_keys) contiene la chiave pubblica di chi mantiene
> questo repository: se riusi questi script **sostituiscila con la tua**, altrimenti dai a
> lui l'accesso ai tuoi PC.
