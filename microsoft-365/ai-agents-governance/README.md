# Governance degli agenti AI in Microsoft 365

Undici script PowerShell di sola lettura per sapere quali agenti AI esistono nel tuo tenant, quali permessi hanno davvero, e chi li ha concessi.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Prima di accendere Copilot su un tenant conviene sapere che cosa c'è già: quali identità non umane sono registrate in Microsoft Entra, quali permessi applicativi esercitano senza nessun utente collegato, chi ha dato quel consenso e quando, quali app e flow le persone hanno costruito da sole, e quanto è larga la condivisione di SharePoint che un assistente si troverà a leggere. Questi script raccolgono quei dati in CSV, un'area per script, senza modificare niente. Sono rivolti a chi conduce un assessment pre-Copilot su un tenant che amministra o che gli è stato affidato: MSP, consulenti, IT interno.

Una cosa va detta subito, perché è il limite di merito di tutta la raccolta: alla domanda «cosa vede questo agente?» non esiste oggi una risposta automatizzabile. Nessun cmdlet unisce una agent identity ai permessi effettivi su SharePoint o OneDrive. Il toolkit costruisce i due lati del ponte — da una parte l'elenco degli agenti con i permessi che gli sono stati concessi, dall'altra la postura di condivisione dei contenuti — e la giunzione resta analisi manuale.

## Gli script

Nessuno script di questa cartella modifica il tenant: tutti e undici sono di sola lettura, e il loro unico effetto sul disco è un file CSV. Due di essi stampano un comando di modifica, che non eseguono: vedi l'avvertenza 5.

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `00-Test-Prerequisiti.ps1` | Da lanciare per primo. Per ogni area controlla se il modulo è installato, con quale versione, e se i cmdlet che il toolkit usa rispondono davvero a `Get-Command`: metà di quei cmdlet è comparsa in versioni di modulo recenti, e uno script che li presume esistenti fallisce con un errore che sembra un problema di permessi e non lo è. Non si connette a nessun tenant. | Sola lettura |
| `01-Get-AgentIdentityInventory.ps1` | Inventario tenant-wide delle identità non umane di tipo agente in Entra: nome, `appId`, stato, data di creazione, tenant proprietario. Usa il cmdlet generico filtrando `servicePrincipalType`, perché i cmdlet dedicati (`Get-EntraAgentIdentity`) accettano solo un ID e non permettono un inventario. `-IncludiTutteLeIdentitaNonUmane` estende la ricerca ad `Application` e `ManagedIdentity`. | Sola lettura |
| `02-Get-AgentIdentityPermissions.ps1` | Per ogni identità elenca i permessi realmente concessi: app role assignment (permessi applicativi, che valgono senza un utente collegato) e oauth2 permission grant (delegati, limitati da ciò che vede l'utente a nome del quale l'agente agisce). È la base di un audit di least privilege. Si alimenta dal CSV dello `01`. | Sola lettura |
| `03-Get-ConsentAccountability.ps1` | Legge dall'audit di directory gli eventi di consenso — attore, applicazione, permessi, esito — perché l'app role assignment conserva la data del consenso ma non chi ha premuto «accetta». Passata la retention dell'audit, quel «chi» non esiste più da nessuna parte: il CSV va conservato, non ricostruito a posteriori. | Sola lettura |
| `04-Test-UnifiedAuditLogEnabled.ps1` | Verifica che l'audit log unificato sia attivo, connettendosi esplicitamente a Exchange Online e dichiarandolo nell'output: lo stesso cmdlet eseguito in Security & Compliance PowerShell ritorna `False` anche quando l'audit è attivo. Va eseguito prima dello `05`. | Sola lettura — stampa un comando che scrive (avvertenza 5) |
| `05-Get-CopilotInteractionAudit.ps1` | Estrae dall'audit log unificato le interazioni Copilot e le invocazioni di agenti e le appiattisce in CSV. `-FiltraApp` filtra sull'identità dell'app in post-processing, perché lato server quel filtro non è possibile. | Sola lettura |
| `06-Get-CopilotLicenseInventory.ps1` | Censimento delle licenze Microsoft 365 Copilot: quante acquistate, assegnate e libere, e chi le ha in mano. Lo `SkuId` è risolto a runtime invece di essere cablato come GUID, perché un GUID scritto dentro uno script un giorno restituisce zero utenti senza dare errore. | Sola lettura |
| `07-Get-SharePointOversharingBaseline.ps1` | Fotografa la policy di condivisione del tenant e lo stato di ogni sito. Il doppio passaggio è necessario, non una svista: l'enumerazione popola valori di default sulle proprietà di sharing, e i valori reali si leggono solo con una chiamata per sito. `-MaxSiti` (default 500) interrompe avvisando. | Sola lettura |
| `08-Get-RestrictedContentDiscoveryStatus.ps1` | Stato di Restricted Content Discovery sito per sito: dove il contenuto è escluso dalla ricerca a livello di organizzazione e da Copilot senza che i permessi vengano toccati. | Sola lettura — stampa un comando che scrive (avvertenza 5) |
| `09-Get-ShadowAIPowerPlatform.ps1` | Censimento della shadow AI in Power Platform: ambienti con le impostazioni di AI generativa, app, flow, connessioni, connettori custom, policy DLP e impostazioni del tenant. L'header elenca quattro buchi dichiarati dell'inventario, fra cui i connettori standard e le bozze non pubblicate. Unico script che gira solo su Windows PowerShell 5.x. | Sola lettura |
| `10-Get-CopilotStudioAgents.ps1` | Inventario degli agenti di Copilot Studio e mappa agente → connettori, via Azure Resource Graph: un cmdlet dedicato non esiste, e nessuno dei circa 170 cmdlet di amministrazione di Power Platform contiene `bot`, `copilot` o `agent` nel nome. Oltre 200 risorse per tipo, Resource Graph restituisce 200 elementi casuali: lo script lo segnala. | Sola lettura |

## Prima di eseguirli

**PowerShell.** PowerShell 7 (`pwsh.exe`) per gli script da `00` a `08` e per il `10`. Windows PowerShell 5.x (`powershell.exe`) **soltanto** per il `09`: il modulo di amministrazione di Power Platform non è compatibile con .NET Core, e lo script si interrompe da sé se lanciato su PowerShell 7.

**Moduli.** Dei moduli Graph servono i cinque sottomoduli elencati qui sotto, in versione 2.0.0 o successiva.

```powershell
# PowerShell 7 - script da 00 a 08 e 10
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Applications, Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Reports -Scope CurrentUser
Install-Module ExchangeOnlineManagement -MinimumVersion 3.2.0 -Scope CurrentUser
Install-Module Microsoft.Online.SharePoint.PowerShell -MinimumVersion 16.0.0 -Scope CurrentUser
Install-Module Az.ResourceGraph -MinimumVersion 0.13.0 -Scope CurrentUser

# Windows PowerShell 5.x - SOLO lo script 09
Install-Module Microsoft.PowerApps.Administration.PowerShell -MinimumVersion 2.0.0 -Scope CurrentUser
```

Lo `00` controlla anche `Microsoft.Entra` 1.3.0, che nessuno script richiede: i cmdlet dedicati agli agenti sono comodi ma non consentono un inventario, e il toolkit non li usa. Le superfici di governance degli agenti AI cambiano di mese in mese — i cmdlet di questa raccolta sono stati verificati sulla documentazione Microsoft il 19 agosto 2026 — ed è la ragione per cui lo `00` esiste: esegui quello prima di tutto il resto.

**Permessi e ruoli.** Gli scope Graph sono delegati e chiedono il consenso dell'amministratore al primo accesso. Sono tutti `.Read.All`: in questa raccolta non c'è un solo `.ReadWrite`.

| Script | Permesso o ruolo |
| --- | --- |
| `00` | nessuno: non si connette a niente |
| `01`, `02` | `Application.Read.All`, `Directory.Read.All` |
| `03` | `AuditLog.Read.All`, `Directory.Read.All` |
| `04`, `05` | Exchange Online, ruolo **View-Only Audit Logs** oppure **Audit Logs** — dalla sessione Exchange Online, non da Security & Compliance |
| `06` | `Organization.Read.All`, `User.Read.All`, `Directory.Read.All`; più `AuditLog.Read.All` se vuoi la colonna `UltimoAccesso` (avvertenza 2) |
| `07`, `08` | **SharePoint Administrator**, e l'URL admin del tenant in `-Url` (per esempio `-Url https://contoso-admin.sharepoint.com`) |
| `09` | **Power Platform Administrator**; le credenziali di `Add-PowerAppsAccount` valgono circa 8 ore |
| `10` | ruolo **Reader** sulle sottoscrizioni da interrogare |

- `Directory.Read.All` è una lettura di tutti gli oggetti di directory del tenant, e nel `06` è più larga del necessario: `Get-MgSubscribedSku` è coperto da `Organization.Read.All` e `Get-MgUser` da `User.Read.All`. Se il consenso passa da un approvatore, questa tabella serve a concedere il minimo per lo script che devi lanciare, invece del consenso più ampio per tutta la raccolta.
- `AgentIdentity.Read.All` e il ruolo **Agent ID Administrator** sono citati nel commento dello `01` ma non vengono richiesti dal codice: vedi l'avvertenza 1.
- Gli script `04` e `05` presuppongono che l'audit unificato sia attivo sul tenant; è quello che verifica il `04`.
- Licenze: Restricted Content Discovery (`08`) richiede almeno una licenza **Microsoft 365 Copilot** nel tenant, che è ciò che sblocca SharePoint Advanced Management — su Business Premium puro non c'è. L'inventario di Power Platform (`09`) non richiede E5.

## ⚠️ Avvertenze

1. **L'inventario degli agenti passa da `Application.Read.All`, e una lista vuota viene presentata come esito normale.** Il commento dentro lo `01` dichiara di chiedere anche `AgentIdentity.Read.All` («Chiediamo entrambi»), ma l'array degli scope contiene solo `Application.Read.All` e `Directory.Read.All`: quello scope non viene mai portato al consenso. Conseguenza: su un tenant in cui le agent identity sono gestite e quello scope serve davvero, l'inventario torna incompleto o vuoto, e il messaggio dello script in quel caso recita «la lista sara vuota: non e un errore» — cioè invita a leggere uno zero come una buona notizia. E siccome lo `02` si alimenta da questo CSV, il vuoto si propaga a tutto il resto. Prima di concludere che nel tenant non ci sono agenti, rilancia con `-IncludiTutteLeIdentitaNonUmane` — un agente registrato come normale app registration non compare fra le `ServiceIdentity` — e verifica a mano dal portale. Uno zero, qui, va spiegato, non accettato.

2. **Nel CSV delle licenze Copilot la colonna `UltimoAccesso` è vuota per costruzione, e vuota non significa «non usata».** Lo `06` si connette con `Organization.Read.All`, `User.Read.All` e `Directory.Read.All`, poi chiede la proprietà `SignInActivity`, che richiede `AuditLog.Read.All`: con quel consenso la richiesta fallisce sempre, lo script rilegge senza la proprietà (è previsto e lo dichiara in un avviso) ed esporta `UltimoAccesso` sistematicamente vuota. Conseguenza: chi apre il CSV vede una colonna di celle vuote e conclude che nessuno usa Copilot, cioè prende una decisione di spesa su un dato che non è mai stato letto. Se ti serve quella colonna, aggiungi `AuditLog.Read.All` al consenso; altrimenti ignorala e non fondarci i rinnovi. Il conteggio delle licenze su account disattivati, che lo script stampa a parte, è invece affidabile: si basa su `AccountEnabled`, non su `SignInActivity`.

3. **I conteggi per operazione dello `05` sono un minimo, non un totale.** Lo script ha due cicli, e si comportano in modo diverso: quello sui `RecordType` pagina correttamente con `-SessionId` e `-SessionCommand ReturnLargeSet`, mentre quello sulle quattro operazioni degli agenti (`AIInvokeAgent`, `AIExecuteTool`, `AIInferenceCall`, `AIGuardrail`) chiama la ricerca con `-ResultSize 5000` e nessuna paginazione, quindi si ferma a 5.000 record per operazione senza dirlo. Conseguenza: su un tenant attivo quelle righe vengono tagliate in silenzio, mentre il totale stampato in fondo sembra completo. Lavora su finestre brevi e somma, invece di chiedere un mese in un colpo; se un'operazione restituisce esattamente 5.000 record, è il segnale che ce ne sono altri. Valgono anche i due limiti che l'header dichiara: la latenza dell'audit è di 60-90 minuti, quindi le ultime ore sono incomplete per costruzione, e Microsoft avverte che l'audit log non è inteso come base per il reporting di adozione — questi numeri servono alla sicurezza e alla tracciabilità, non a costruire percentuali da presentare.

4. **Se il `09` non stampa «Fatto.», i CSV che trovi sono un inventario parziale, e niente nei file lo dice.** Lo script gira con `$ErrorActionPreference = 'Stop'` e quattro delle sette raccolte — app, flow, connessioni, connettori custom — sono invocate senza `try/catch`, mentre ambienti, policy DLP e impostazioni del tenant sono protette. Conseguenza: se una delle quattro fallisce per permessi, throttling o scadenza della sessione, lo script muore dopo aver già scritto i CSV precedenti; i file restano a terra, validi nel formato e incompleti nel contenuto, e l'ultima riga dell'output non viene raggiunta. Controlla sempre la fine dell'output: senza «Fatto.», butta i CSV di quella esecuzione e rilancia, perché un censimento di shadow AI parziale è peggio di nessun censimento.

5. **Due script stampano, pronto da incollare, un comando che modifica il tenant. Il toolkit non lo esegue: la decisione è di chi amministra.** Il `04`, subito dopo aver detto «Audit NON attivo» — cioè nel momento di massima fretta — suggerisce `Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true`: è una modifica a livello di tenant, e l'audit appena abilitato non recupera il passato, gli eventi iniziano a comparire da quel momento in poi. L'`08` suggerisce `Set-SPOSite -Identity <url> -RestrictContentOrgWideSearch $true`: cambia la discoverability del contenuto di un sito, non si applica a OneDrive, e su siti oltre 500.000 elementi la propagazione può superare la settimana, quindi un controllo fatto il giorno dopo non dimostra che non abbia funzionato. Prima di incollare uno dei due, concordalo con chi amministra il tenant e mettilo a verbale come cambiamento, non come passo del toolkit.

6. **L'`08` non ha un tetto al numero di siti: su un tenant grande gira per ore e non lo si può limitare.** Enumera tutti i siti e poi fa una chiamata per ciascuno — il doppio passaggio è necessario, perché l'enumerazione restituisce valori di default invece di quelli reali — ma, a differenza dello script gemello `07`, non ha il parametro `-MaxSiti` che si interrompe avvisando oltre i 500 siti. Conseguenza: niente di distruttivo, ma throttling di SharePoint, sessione che cade a metà e CSV parziale, dopo una lunga attesa. Lancia prima il `07` sullo stesso tenant: ti dice quanti siti ci sono e, se sono oltre il suo limite, si ferma prima di farti aspettare a vuoto. Da quel numero stima il tempo e decidi se avviare l'`08`.

## Dove finiscono i file

Ogni script esporta uno o più CSV, e il percorso predefinito è **relativo alla directory corrente**, con un nome che contiene solo la data (per esempio `.\AI-AgentIdentityInventory-20261029.csv`). Il `09` scrive fino a sette file `AI-PP-<area>-<data>.csv` nella cartella passata con `-CartellaOutput`, che per default è quella corrente; il `10` ne scrive due. Due conseguenze:

- Il file nasce dove si trova il prompt. Se hai clonato il repository e lanci gli script da dentro il clone, il CSV nasce **dentro il clone**: il `.gitignore` della radice esclude i `*.csv`, ma non fidarti di quella rete e controlla `git status` prima di un commit.
- Una seconda esecuzione nello stesso giorno **sovrascrive** l'export precedente senza chiedere: il nome dipende solo dalla data, e `Export-Csv` non usa `-NoClobber`.

Il contenuto non è anonimo. Nei CSV finiscono dati personali: UPN, nome, reparto, ruolo e ultimo accesso di ogni utente con licenza Copilot (`06`); l'UPN di chi ha concesso un consenso (`03`); gli identificativi degli utenti che hanno interagito con Copilot, con il thread id e fino a 1.500 caratteri del record di audit grezzo (`05`); i nomi di chi ha creato app, flow e connessioni (`09`). E ci finisce anche materiale che è una mappa della superficie di attacco: l'elenco dei siti che consentono link anonimi, con URL e proprietario (`07`, `08`), e l'elenco degli agenti con i permessi applicativi che esercitano su tutto il tenant (`02`). Passa `-OutputCsv` verso una cartella controllata e cancella gli export a analisi conclusa.

Una precisazione sullo `05`, perché evita una preoccupazione sbagliata e ne crea una giusta: il testo di prompt e risposte **non** è nell'audit log, che porta solo il thread id. Quel contenuto vive negli strumenti di data security, non in questi CSV. Resta però scritto chi ha interagito, quando e con quale carico di lavoro.

## Esempi

```powershell
# Primo passo: moduli, versioni e cmdlet. Non si connette a nessun tenant.
.\00-Test-Prerequisiti.ps1

# Inventario delle agent identity, esteso a tutte le identità non umane
.\01-Get-AgentIdentityInventory.ps1 -IncludiTutteLeIdentitaNonUmane

# Permessi concessi, partendo dal CSV dell'inventario
.\02-Get-AgentIdentityPermissions.ps1 -InventoryCsv .\AI-AgentIdentityInventory-20260819.csv

# Shadow AI in Power Platform: da Windows PowerShell 5.x, non da pwsh
powershell.exe -File .\09-Get-ShadowAIPowerPlatform.ps1
```

## Altro

Lo stesso contenuto è scaricabile come archivio ZIP dalla pagina [synsphere.it/download/toolkit-powershell-governance-agenti-ai](https://synsphere.it/download/toolkit-powershell-governance-agenti-ai/).

Se serve aiuto a interpretare i risultati o a impostare un assessment pre-Copilot: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
