# Emergenza Microsoft 365: contenimento e raccolta delle prove

Dieci script PowerShell per le prime ore di un account compromesso: fermare l'accesso senza perdere le prove, e poter tornare indietro.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Serve al tecnico MSP o all'IT interno di una PMI che deve contenere un account compromesso o una frode del bonifico su un tenant Microsoft 365 / Entra ID. Nelle prime ore si rischiano due errori opposti: agire e cancellare le prove, oppure raccogliere con calma e lasciare l'attaccante dentro.

Gli script coprono la sequenza intera: verifica go/no-go di quali fonti di prova esistono davvero su quel tenant, fotografia reversibile dello stato degli account, contenimento (disabilitazione più revoca delle sessioni), export dei sign-in log, del log di controllo Entra, del log di controllo unificato, del message trace e delle regole e inoltri di posta, report HTML finale e rientro.

Otto script su dieci sono di sola lettura. I due che scrivono sul tenant, il 03 e il 04, sono in simulazione per default: senza `-Esegui` non toccano nulla.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Test-PrerequisitiEmergenza.ps1` | Go/no-go prima del contenimento: dice se i sign-in log di Entra sono interrogabili su questo tenant, se il log di controllo unificato sta registrando e se il modulo Exchange è abbastanza recente per `Get-MessageTraceV2`. Stampa la finestra temporale reale di ciascuna fonte. | Sola lettura |
| `02-Backup-StatoUtenti.ps1` | Fotografa lo stato di abilitazione di tutti gli account prima del blocco: è ciò che rende il blocco reversibile. Registra anche quali account sono sincronizzati da Active Directory e chi ha un ruolo di amministrazione. | Sola lettura |
| `03-Invoke-BloccoEmergenza.ps1` | Contenimento: imposta `AccountEnabled = false` e revoca le sessioni attive. La revoca è la parte che conta: senza, un token di aggiornamento già emesso resta valido e l'attaccante continua a leggere la posta su un account che nel portale risulta bloccato. Richiede lo snapshot del 02. | **SCRIVE** — simulazione per default |
| `04-Restore-StatoUtenti.ps1` | Riabilita soltanto gli account che nello snapshot risultavano abilitati, così gli ex dipendenti e le utenze chiuse apposta restano chiuse. `-Utenti` limita il rientro a un elenco preciso. | **SCRIVE** — simulazione per default |
| `05-Export-SignInLogs.ps1` | Esporta gli accessi di Entra ID e ne ricava un secondo CSV di soli sospetti: accessi riusciti con esito di rischio, protocolli di autenticazione legacy che aggirano l'MFA, paesi non abituali. | Sola lettura |
| `06-Export-AuditLogEntra.ps1` | Esporta il log di controllo di Entra e isola sette famiglie di eventi con cui si costruisce la persistenza: metodi di autenticazione aggiunti, consensi applicativi e service principal, credenziali aggiunte a un'applicazione, ruoli di amministrazione assegnati, utenti creati, domini aggiunti, criteri di accesso condizionale modificati. | Sola lettura |
| `07-Export-UnifiedAuditLog.ps1` | Esporta il log di controllo unificato (Exchange, SharePoint, Entra, Teams) con la paginazione corretta: `-SessionCommand ReturnLargeSet` e lo stesso `-SessionId` finché non tornano zero record. Senza quella paginazione la ricerca restituisce 100 record e nessun errore. | Sola lettura |
| `08-Export-MessageTrace.ps1` | Esporta la posta in transito con `Get-MessageTraceV2`, spezzando da sé la finestra nei blocchi da 10 giorni che il cmdlet impone; il blocco che tocca il tetto dei 5.000 risultati viene rifatto giorno per giorno. | Sola lettura |
| `09-Export-RegolePostaEInoltri.ps1` | Censisce gli inoltri a livello di cassetta e le regole della posta in arrivo: la persistenza che resta attiva anche dopo il blocco e il cambio password. Ordina per gravità, dall'inoltro di cassetta che l'utente non vede in Outlook fino ai nomi di regola sospetti. | Sola lettura |
| `10-New-ReportIncidente.ps1` | Costruisce un report HTML unico dai CSV raccolti. Dove una fonte manca scrive che manca, non zero. Non interroga il tenant: gira anche su un'altra macchina, a incidente chiuso. | Sola lettura (nessuna connessione al tenant) |

## Prima di eseguirli

- **PowerShell 5.1 oppure PowerShell 7.** Nessuno script lo impone con `#Requires -Version`: su una versione più vecchia l'errore arriva a metà corsa, non all'avvio.
- **Microsoft Graph** (script 01-06): `Install-Module Microsoft.Graph -Scope CurrentUser`
- **Exchange Online** (script 07, 08, 09): `Install-Module ExchangeOnlineManagement -Scope CurrentUser` — serve la **versione 3.7.0 o superiore**, perché `Get-MessageTraceV2` non esiste prima e `Get-MessageTrace`, il cmdlet storico, è deprecato. Verifica con `Get-Module -ListAvailable ExchangeOnlineManagement`, aggiorna con `Update-Module ExchangeOnlineManagement`.
- Lo script 10 non richiede moduli né connessione al tenant: legge solo i CSV già raccolti.

Ruoli in sola lettura (script 01, 02, 05, 06, 07, 08, 09): **Global Reader** per la parte Microsoft Graph; **Security Reader** oppure **Reports Reader** per i sign-in log e il log di controllo di Entra; **View-Only Organization Management** per la parte Exchange; **View-Only Audit Logs** per il log di controllo unificato.

Ruoli in scrittura (script 03 e 04): **User Administrator** oppure **Global Administrator**.

Scope Graph richiesti dal codice: `AuditLog.Read.All`, `Directory.Read.All`, `User.Read.All` nel 01; `User.Read.All`, `Directory.Read.All`, `RoleManagement.Read.Directory` nel 02; `AuditLog.Read.All`, `Directory.Read.All` nel 05 e nel 06; `User.ReadWrite.All`, `Directory.ReadWrite.All` nel 03 (vedi l'avvertenza 6); `User.ReadWrite.All` nel 04. Gli script 07, 08 e 09 non usano Graph: si autenticano con `Connect-ExchangeOnline`.

**Ordine in emergenza:** `01 → 02 → 03 → 05 → 06 → 09 → 07 → 08 → 10 → 04`. Il 02 va sempre prima del 03: senza quella fotografia il blocco non è reversibile, perché dopo non esiste più modo di sapere quali account erano già disabilitati prima dell'incidente, e riabilitarli tutti rimetterebbe in servizio ex dipendenti e utenze chiuse apposta. Il 04 va per ultimo.

Prima di lanciare il 03:

- il 02 è stato eseguito e il CSV è salvato fuori dal tenant;
- esiste almeno un'utenza di emergenza (break-glass) funzionante e non compromessa, da passare in `-Escludi`;
- il 03 è stato lanciato prima in simulazione, senza `-Esegui`, e l'elenco è stato letto per intero.

Quanto indietro si può guardare, perché è il vincolo che decide tutta la raccolta:

- **Sign-in log di Entra ID**: 30 giorni con P1 o P2, 7 giorni con Entra ID Free. Richiedono P1 o P2: su Business Basic e Standard non esistono via API, e la chiamata fallisce con un errore che somiglia a un problema di permessi. Business Premium include P1.
- **Log di controllo di Entra**: 30 giorni con P1 o P2.
- **Log di controllo unificato**: 180 giorni con Audit Standard (default dal 17 ottobre 2023), un anno solo con Audit Premium o E5, e solo se la registrazione era già attiva quando i fatti sono accaduti: accenderla adesso non recupera il passato. Se lo script 07 dichiara di aver toccato il tetto dei 50.000 record di sessione, quello non è «tutti gli eventi»: va rilanciato su finestre più strette.
- **Message trace**: 90 giorni, al massimo 10 giorni per interrogazione.

## ⚠️ Avvertenze

1. **L'esclusione automatica dei Global Administrator può non proteggere nessuno, senza dare errore.** Lo script 03 salta i Global Administrator leggendo la colonna `RuoliAdmin` dello snapshot, e quella colonna cade in silenzio in tre modi: se nel 02 la lettura dei ruoli non riesce, lo script emette solo un avviso e prosegue, quindi `RuoliAdmin` resta vuota per tutti, e il 03 valida la sola colonna `AccountEnabled`, perciò accetta quello snapshot; il confronto è una sottostringa sul nome visualizzato del ruolo (`Global Administrator` oppure `Amministratore globale`), mentre le API di directory restituiscono quel ruolo anche come `Company Administrator`, e in un tenant con un'altra lingua con un terzo nome ancora; le assegnazioni lette sono solo quelle attive, quindi i Global Administrator eleggibili via PIM, cioè la configurazione raccomandata da Microsoft, non compaiono nello snapshot. In tutti e tre i casi, con `-Esegui` i Global Administrator vengono disabilitati, break-glass compreso se non è elencato in `-Escludi`, e il riepilogo stampa «Account esclusi: 0», indistinguibile da «non c'erano amministratori». Passa sempre i break-glass in `-Escludi` a mano, e prima di `-Esegui` apri lo snapshot e verifica che la colonna `RuoliAdmin` sia davvero popolata: non contare sull'esclusione automatica.

2. **Lo script 09 può concludere «Nessun inoltro esterno trovato» su un tenant compromesso.** Ogni cassetta che non riesce a leggere, per throttling di Exchange Online, permessi mancanti o cassetta inaccessibile, viene scartata senza lasciare traccia, e il riepilogo non dice quante cassette sono state saltate. Se nessuna delle cassette effettivamente lette ha un inoltro, lo script stampa in verde che non ne ha trovati: una scansione throttlata al 90% produce così un esito rassicurante. È il falso negativo più pericoloso del toolkit. Confronta il numero di cassette esaminate con il numero reale di caselle del tenant, parti da `-Utenti` sulle caselle sospette e rilancia la scansione completa: un numero senza il suo denominatore non prova nessuna assenza.

3. **`-Esegui -Confirm:$false` sul 03 toglie l'ultima rete.** Dopo `-Esegui` l'unico cancello che resta è la richiesta di conferma per ogni singolo account; `-Confirm:$false` la rimuove, e lo script disabilita e revoca le sessioni di ogni account che nello snapshot risultava abilitato senza fare una sola domanda. Non esiste una conferma aggregata: il riepilogo stampa il numero di account in ambito, ma non chiede di confermarlo. Non passare `-Confirm:$false`, e leggere l'elenco della simulazione prima di eseguire.

4. **L'ambito del 03 comprende gli account di servizio, e su un tenant ibrido ferma la sincronizzazione.** L'ambito è «ogni account che nello snapshot risultava abilitato», meno l'operatore, meno i Global Administrator, meno `-Escludi`: vi rientra l'account di sincronizzazione di Entra Connect (`Sync_*@*.onmicrosoft.com`), che ha il ruolo Directory Synchronization Accounts e quindi non corrisponde al filtro delle esclusioni. Disabilitarlo interrompe la sincronizzazione di directory e il password hash sync proprio mentre si sta contenendo l'incidente, e il ripristino di quell'account non è coperto da questi script. Passa sempre in `-Escludi`, insieme ai break-glass, l'account di sincronizzazione e le altre utenze di servizio (Directory Synchronization Accounts, Partner Tier1 e Tier2 Support). Il rovescio dello stesso problema: sugli account sincronizzati da Active Directory il blocco lato cloud viene sovrascritto al ciclo di sincronizzazione successivo, e vanno disabilitati in AD; il 02 e il 03 li contano e li segnalano a parte.

5. **Un `-OutputCsv` che non termina in `.csv` distrugge l'export principale.** Gli script 05, 06 e 09 scrivono un secondo CSV filtrato (`-SOSPETTI`, `-PERSISTENZA`, `-INOLTRI-CASSETTA`) il cui percorso è derivato da `-OutputCsv` sostituendo il `.csv` finale. Se il valore passato non termina in `.csv` la sostituzione non aggancia nulla e i due percorsi coincidono: l'export completo, appena scritto, viene sovrascritto dal solo sottoinsieme filtrato, senza errore. `.\IR-05` e `.\export.csv.bak` collidono; `.\IR-05.csv` e `D:\caso\export.CSV` vanno bene. In contesto forense significa conservare il filtro e perdere la prova principale. Lascia il valore di default, oppure passa un percorso che finisca in `.csv`.

6. **Il 03 chiede un consenso Graph più ampio di quello che usa.** Richiede `User.ReadWrite.All` e `Directory.ReadWrite.All`, ma esegue due sole scritture: disabilitare l'account e revocare le sessioni. `Directory.ReadWrite.All` è uno degli scope più ampi di Graph, con scrittura su gruppi, applicazioni, service principal, dispositivi e impostazioni di directory, e non serve a nessuna delle due: la prova è nello stesso toolkit, perché il 04 fa la stessa `Update-MgUser` con il solo `User.ReadWrite.All`. Quel consenso viene chiesto a un amministratore sotto pressione, durante un incidente, cioè nel momento peggiore per approvare uno scope che non serve: se la finestra di consenso compare, concedi `User.ReadWrite.All` (ancora più stretto: `User.EnableDisableAccount.All` e `User.RevokeSessions.All`). Vale in piccolo anche in sola lettura: il 05 e il 06 chiedono `Directory.Read.All` ma invocano soltanto i cmdlet dei log.

## Dove finiscono i file

Gli script esportano nella **directory corrente**, con un nome che contiene data e ora al minuto (`IR-02-StatoUtenti-20260828-1030.csv` e simili); il 10 produce un `IR-Report-<data-ora>.html`. Tutti i percorsi sono parametrizzabili. Due conseguenze da tenere a mente:

- **Il file nasce dove si trova il prompt.** Se hai clonato il repository e lanci gli script da dentro il clone, i CSV finiscono nel clone: non committarli. Il `.gitignore` nella radice esclude `*.csv`, `*.json` e `*.html`, ma non fidarti del filtro: guarda `git status` prima di aggiungere qualcosa.
- **Due esecuzioni nello stesso minuto si sovrascrivono senza chiedere**, perché nessun `Export-Csv` usa `-NoClobber`. Se rilanci un export subito dopo il precedente, passa un `-OutputCsv` diverso, che finisca in `.csv` (vedi l'avvertenza 5).

Questi file contengono dati del cliente: l'ID del tenant, tutti gli UPN e i nomi visualizzati, l'elenco degli account guest esterni, gli indirizzi IP da cui sono stati fatti gli accessi, gli oggetti e i MessageId dei messaggi di posta, le regole della posta in arrivo con le destinazioni di inoltro. Trattali come materiale dell'incidente: fuori dal repository, fuori dal tenant compromesso, su un supporto controllato.

Una nota sul report: il 10 cerca i CSV per nome (`IR-05-SignIn-*-SOSPETTI.csv` e simili) nella cartella indicata. Se hai cambiato i nomi con `-OutputCsv`, il report dichiara quella fonte **assente** anche se l'hai raccolta. Nel report «assente» non vuol dire «vuota», ed è una scelta deliberata: «nessun accesso sospetto» quando i sign-in log non sono mai stati scaricati sarebbe la conclusione più pericolosa che uno strumento come questo possa produrre.

## Esempi

```powershell
# La fotografia dello stato, obbligatoria prima di qualunque blocco
.\02-Backup-StatoUtenti.ps1

# Contenimento in simulazione: mostra chi verrebbe bloccato, non tocca nulla
.\03-Invoke-BloccoEmergenza.ps1 -SnapshotCsv .\IR-02-StatoUtenti-20260828-1030.csv

# Letto l'elenco, si esegue davvero, con il break-glass escluso
.\03-Invoke-BloccoEmergenza.ps1 -SnapshotCsv .\IR-02-StatoUtenti-20260828-1030.csv -Escludi 'breakglass@contoso.com' -Esegui

# Rientro a ondate, un gruppo di utenti per volta
.\04-Restore-StatoUtenti.ps1 -SnapshotCsv .\IR-02-StatoUtenti-20260828-1030.csv -Utenti 'mario.rossi@contoso.com','anna.bianchi@contoso.com' -Esegui
```

## In chiusura

Lo stesso contenuto si scarica come archivio ZIP dalla pagina [Toolkit PowerShell: emergenza compromissione Microsoft 365](https://synsphere.it/download/toolkit-powershell-emergenza-compromissione-microsoft-365/). Se serve supporto durante un incidente in corso: [synsphere.it/contattaci](https://synsphere.it/contattaci).

Che cosa questi script non fanno: non rimuovono le regole malevole né i consensi applicativi, li trovano e li elencano, perché la rimozione va decisa caso per caso; non forzano il cambio password, che dipende dal piano di rientro; non sostituiscono una risposta all'incidente condotta da persone. Il report raccoglie indizi, non stabilisce se ci sia stata una compromissione: quella resta una valutazione umana. Fornito «as is», senza garanzie: provalo in un ambiente di prova prima di averne bisogno davvero.

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
