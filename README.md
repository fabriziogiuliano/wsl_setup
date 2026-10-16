# wsl_setup — agent per i PC del laboratorio

Agent Windows di [lab_monitor](https://github.com/fabriziogiuliano/lab_monitor): gira su
ogni PC del laboratorio e invia ogni 2 secondi al monitor le connessioni e il traffico del
PC. È il PC che si collega al monitor, quindi **sul PC non serve amministratore** e non va
aperta nessuna porta: basta che il PC raggiunga il monitor.

## Installazione su un PC

Dall'account con cui si usa il PC:

1. **Code → Download ZIP** da GitHub, poi tasto destro sullo zip → **Estrai tutto**.
2. Doppio clic su `install.bat`. Al primo avvio chiede:
   - l'indirizzo del monitor (invio per quello proposto, da `agent.conf.example`);
   - il **token**: `agent.token` in `app/config.yml` del monitor.

   Le risposte vengono salvate in `agent.conf` (escluso da git): copiando la cartella con
   `agent.conf` sugli altri PC non vengono più chieste.
3. Il riepilogo finale deve riportare **"Report: ricevuti dal monitor"**.

L'installazione copia l'agent in `%LOCALAPPDATA%\LabMonitorAgent` e lo fa partire, nascosto,
a ogni accesso dell'utente. Rieseguirla aggiorna l'agent o la configurazione.

**Disinstallazione:** doppio clic su `uninstall.bat` (stesso account): ferma l'agent, toglie
l'avvio automatico e cancella la cartella.

## Cosa invia

Ogni `interval` secondi, al server indicato in `agent.conf` (`POST /api/report`, con il token):

- `netstat -ano` — connessioni di tutti i programmi, con il nome del processo;
- `netstat -e` — byte totali, per la banda;
- gli IPv4 del PC;
- `ss -tunp` della distro WSL, **solo se una distro è già in esecuzione** (le connessioni
  di WSL2 non compaiono in `netstat`); `wsl=0` in `agent.conf` lo disattiva.

Il monitor identifica il PC dall'IP da cui arrivano i report e li analizza con le sue
regole. Se l'agent viene chiuso, il monitor segnala il PC come disconnesso.

## File

| File | |
|---|---|
| `install.bat` / `install_agent.ps1` | installazione |
| `uninstall.bat` / `uninstall_agent.ps1` | disinstallazione |
| `lab_agent.ps1` | l'agent |
| `agent.conf.example` | modello di configurazione (`server`, `token`, `interval`, `name`, `wsl`) |
| `old_wsl_ssh/` | vecchio setup via WSL + SSH: serve solo il suo `uninstall.bat` per ripulire i PC dove era stato installato |
