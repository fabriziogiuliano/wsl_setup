# wsl_setup — accesso SSH a Ubuntu in WSL sui PC del laboratorio

Prepara un PC Windows del laboratorio perché Ubuntu in WSL sia raggiungibile via SSH
(**solo con chiave**), **senza amministratore**. Lo usa il
[monitor](https://github.com/fabriziogiuliano/lab_monitor), che si collega ai PC via SSH, e
serve per l'accesso remoto.

## Uso

**Code → Download ZIP** da GitHub, tasto destro sullo zip → **Estrai tutto**, poi dalla
cartella principale:

- **`install.bat`** — prepara il PC; non chiede nulla.
- **`uninstall.bat`** — annulla tutto (Ubuntu e i suoi file restano).

Il riepilogo finale di `install.bat` deve riportare `sshd attivo: SI`.

## Cosa fa `install.bat`

1. in `%USERPROFILE%\.wslconfig` attiva il networking **mirrored** (WSL usa l'IP del PC);
2. installa **Ubuntu-24.04** se manca (serve internet); se c'è già, usa quella;
3. in Ubuntu crea l'utente `cn` con password `cn` (con `sudo`), installa `openssh-server`
   e autorizza le chiavi in [`authorized_keys`](wsl_ssh/authorized_keys): **si entra solo
   con la chiave**, la password serve solo a `sudo`. Per utente e password diversi c'è
   `wsl_ssh\credentials.txt` (vedi `credentials.example.txt`);
4. riavvia WSL e verifica che `sshd` sia attivo.

`sshd` parte quando si apre Ubuntu e si ferma quando WSL si spegne: il PC è raggiungibile
finché Ubuntu resta aperta. Dall'esterno serve che la porta 22 verso WSL sia aperta nel
firewall Hyper-V e in quello di Windows (con un utente standard, lo fa l'IT).

## Disinstallazione

`uninstall.bat` (stesso account dell'installazione) rimette tutto com'era usando lo stato
salvato alla prima installazione, **senza eliminare Ubuntu**: toglie SSH, chiavi e
configurazione e ripristina `.wslconfig`. Per eliminare anche la distro, se l'aveva
installata il setup, si lancia `wsl_ssh\uninstall_wsl.ps1 -RemoveDistro` da PowerShell
(cancella **tutti** i file al suo interno).

## File

| File | |
|---|---|
| `install.bat` / `uninstall.bat` | installazione e disinstallazione (cartella principale) |
| `wsl_ssh/setup_wsl.ps1`, `wsl_ssh/uninstall_wsl.ps1` | gli script che fanno il lavoro |
| `wsl_ssh/setup.bat`, `wsl_ssh/uninstall.bat` | gli stessi, lanciabili dalla cartella `wsl_ssh` |
| `wsl_ssh/install_ubuntu.bat` | installa solo Ubuntu-24.04, senza SSH (se c'è già non fa nulla) |
| `wsl_ssh/authorized_keys` | chiavi pubbliche autorizzate a entrare |

> [`authorized_keys`](wsl_ssh/authorized_keys) contiene la chiave pubblica di chi mantiene
> questo repository: se riusi questi script **sostituiscila con la tua**, altrimenti dai a
> lui l'accesso ai tuoi PC.
