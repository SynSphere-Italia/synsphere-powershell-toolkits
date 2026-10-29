# Scadenze delle credenziali delle app registration di Entra ID

Tutti i client secret e i certificati del tenant in una tabella sola, ordinata per data di scadenza, con quelli già scaduti in testa.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

È rivolto all'amministratore di sistema di una PMI, o al consulente che segue più tenant, e risolve un problema che non dà preavviso: le credenziali delle app registration di Entra ID scadono in silenzio — nessuna mail, nessuna notifica nel portale, nessun alert. Il primo segnale è un'integrazione che smette di funzionare: un invio SMTP che risponde 535, un job che non autentica più, un webhook che non firma.

Il portale quelle date le mostra solo entrando in ogni singola applicazione. Lo script le raccoglie tutte in un elenco ordinato per urgenza e, per ogni client secret, riporta il campo HINT, cioè i primi tre caratteri del valore. Serve a capire *quale* secret sta usando una certa applicazione, confrontandolo con i primi tre caratteri del valore configurato nel file di ambiente o nel vault: il valore completo non è recuperabile dopo la creazione, quindi quella è la sola corrispondenza possibile.

## Gli script

| File | Che cosa fa | Legge / Scrive |
|------|-------------|----------------|
| `get-entra-app-credentials-expiry-synsphere.ps1` | Si connette a Microsoft Graph chiedendo lo scope `Application.Read.All`, legge tutte le app registration del tenant con `Get-MgApplication -All` e — solo se passi `-IncludiServicePrincipal` — anche i service principal (enterprise applications). Per ogni client secret e per ogni certificato calcola i giorni rimasti alla scadenza, ordina dal più urgente (le credenziali senza scadenza vanno in fondo) e stampa la tabella con applicazione, descrizione, tipo, data e HINT, colorando le scadute e quelle entro la soglia. Chiude con il riepilogo nominativo delle credenziali scadute e di quelle in scadenza entro `-GiorniAvviso` (90 giorni per default). Con `-SoloInScadenza` mostra solo scadute e in scadenza; con `-EsportaCsv` salva l'elenco completo in un CSV; con `-TenantId` si connette a un tenant diverso da quello predefinito dell'utente. | **Sola lettura** — non modifica nulla nel tenant. Scrive su disco un solo file, il CSV, e soltanto se glielo chiedi con `-EsportaCsv` |

## Prima di eseguirlo

- **PowerShell 5.1 o 7.** Il blocco `.NOTES` dichiara «PowerShell 5.1+ oppure 7+», ma lo script **non** ha una direttiva `#Requires`: su una versione più vecchia non si ferma da sé.
- **Modulo `Microsoft.Graph.Applications`**, l'unico richiesto. Installalo prima a mano:

  ```powershell
  Install-Module Microsoft.Graph.Applications -Scope CurrentUser
  ```

  Lo script non installa niente: se il modulo manca stampa esattamente questo comando e termina. Basta questo sottomodulo, non serve il meta-modulo `Microsoft.Graph` completo.
- **Permesso: `Application.Read.All`**, richiesto da `Connect-MgGraph` al momento della connessione (consenso interattivo, funziona con MFA; nel codice non è memorizzata nessuna credenziale). È il permesso minimo sufficiente, e il blocco `.NOTES` spiega perché: le credenziali sono proprietà ordinarie dell'oggetto application e non richiedono uno scope dedicato.
- **Ruolo nel tenant: Directory Readers, Global Reader, Cloud Application Administrator o Application Administrator.** Il consenso allo scope da solo non basta — vedi l'avvertenza 1.

## ⚠️ Avvertenze

1. **Un elenco vuoto, o un «nessuna credenziale scaduta» in verde, può essere un problema di permessi e non una buona notizia.** Lo script conta e mostra quello che Graph gli restituisce. Se l'utente che esegue non ha uno dei ruoli elencati sopra, il consenso allo scope non è sufficiente: Graph può restituire soltanto le applicazioni di cui quell'utente è proprietario. Se la risposta arriva **vuota** lo script almeno te lo dice («Nessuna credenziale trovata. Verifica di avere i permessi di lettura.»); se arriva **parziale** non c'è nessun avviso, e il riepilogo stampa in verde un «Nessuna credenziale scaduta» calcolato solo su ciò che ha letto. Prima di chiudere il controllo, leggi la riga «*N* app registration esaminate» e confrontala con il numero di app registration che ti aspetti nel tenant: un numeratore senza il suo denominatore non vale.

2. **Per default il perimetro è più stretto di quanto sembri: i service principal non vengono esaminati.** Senza `-IncludiServicePrincipal` lo script legge solo le app registration, e l'help ricorda che alcune integrazioni di terze parti registrano le credenziali sul service principal (enterprise application) invece che sull'app registration. Il totale e il riepilogo si riferiscono quindi a una parte del tenant. Per il controllo periodico esegui sempre con `-IncludiServicePrincipal`.

3. **L'output contiene identificativi del tuo tenant e i primi caratteri dei secret.** A schermo lo script stampa il tenant ID e l'account con cui ti sei connesso. Il CSV contiene, per ogni credenziale, l'`AppId` dell'applicazione, il `KeyId` della credenziale, i primi tre caratteri del valore del client secret (colonna `Hint`) e i primi otto dell'impronta del certificato. Nessuno di questi valori è nel file sorgente: nascono a runtime sul tenant di chi esegue. Incollare quell'output in una issue pubblica o in un ticket significa pubblicare gli identificativi del proprio tenant e delle proprie applicazioni: anonimizzali prima, e tratta il CSV come un documento riservato.

4. **Senza `-TenantId` lavori sul tenant predefinito dell'utente, che non è necessariamente quello su cui volevi lavorare.** Se amministri più tenant, è il modo più semplice per produrre — e consegnare — il report di quello sbagliato. Lo script stampa la riga «Tenant: …» subito dopo la connessione proprio per questo: leggila prima di leggere la tabella, oppure passa `-TenantId` esplicitamente.

5. **Il CSV viene sovrascritto senza chiedere.** L'esportazione usa `Export-Csv` senza `-NoClobber`: se il file che indichi con `-EsportaCsv` esiste già, viene riscritto e il report precedente è perso. Il nome non contiene la data — lo scegli tu — quindi è facile riusare sempre lo stesso. Se devi confrontare un prima e un dopo, usa due nomi distinti.

6. **La sessione Graph resta aperta quando lo script termina.** Non c'è nessun `Disconnect-MgGraph`: su una postazione condivisa la sessione autenticata rimane attiva, e l'esecuzione successiva la riusa senza chiederti niente. Chiudila con `Disconnect-MgGraph` quando hai finito, soprattutto prima di passare a un altro tenant.

## Dove finiscono i file

A differenza di gran parte degli script di questa raccolta, qui **non c'è un percorso predefinito**: senza `-EsportaCsv` lo script non scrive niente su disco e tutto resta nella console. Il CSV nasce solo se passi quel parametro, con il nome che gli dai tu. Due conseguenze da tenere a mente:

- **Un percorso relativo si risolve dove si trova il prompt, non dove si trova lo script.** Se hai clonato questo repository e lanci da lì, `-EsportaCsv .\credenziali.csv` fa nascere il file **dentro il clone**. Il `.gitignore` nella radice esclude `*.csv`, ma non fidarti: controlla con `git status` prima di committare. Lo stesso vale per le cartelle sincronizzate su OneDrive, SharePoint o Dropbox, dove nessun `.gitignore` ti protegge.
- **Una seconda esportazione sullo stesso nome cancella la precedente, senza chiedere** (avvertenza 5). Il nome non porta automaticamente la data: se vuoi conservare lo storico, mettila tu.

Quello che finisce nel file va protetto come un documento riservato: i nomi di tutte le applicazioni registrate, le descrizioni delle credenziali, `AppId`, `KeyId`, i primi tre caratteri di ogni client secret, l'inizio dell'impronta dei certificati e le date di scadenza. È l'elenco di quali integrazioni esistono nel tenant e di quando ognuna diventa fragile.

Il contenuto della console non viene salvato da nessuna parte. Se ti serve un verbale dell'intervento, aprilo con `Start-Transcript` prima di lanciare: il `.gitignore` della radice esclude `transcript*.txt`.

## Esempi

```powershell
# Tutte le credenziali di tutte le app registration
.\get-entra-app-credentials-expiry-synsphere.ps1

# Solo ciò che scade entro 60 giorni o è già scaduto
.\get-entra-app-credentials-expiry-synsphere.ps1 -SoloInScadenza -GiorniAvviso 60

# Report completo, app registration e service principal, esportato in CSV
.\get-entra-app-credentials-expiry-synsphere.ps1 -IncludiServicePrincipal -EsportaCsv .\credenziali.csv

# Controllo periodico su un tenant specifico, con il CSV fuori dal clone
.\get-entra-app-credentials-expiry-synsphere.ps1 -TenantId "contoso.onmicrosoft.com" -SoloInScadenza -IncludiServicePrincipal -EsportaCsv C:\Report\credenziali-entra.csv
```

## Altro

Lo stesso contenuto si scarica come ZIP da [synsphere.it/download/script-powershell-scadenze-credenziali-entra-id](https://synsphere.it/download/script-powershell-scadenze-credenziali-entra-id/). Se serve aiuto: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
