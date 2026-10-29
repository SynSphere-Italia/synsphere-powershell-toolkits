# Toolkit Teams e SharePoint per Microsoft 365

Dieci script PowerShell di sola lettura che fotografano la governance di Microsoft Teams e SharePoint Online di un tenant ed esportano tutto in CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Gli script sono per chi amministra un tenant Microsoft 365, reparto IT interno o MSP, e ha bisogno in forma esportabile di quello che il centro di amministrazione mostra una schermata alla volta: quali team esistono e chi ne è proprietario, dove sono entrati ospiti esterni, quali siti SharePoint consentono link anonimi, quanto spazio consuma ciascun sito, chi ha cancellato un file, chi ha partecipato a una riunione.

Nessuno dei dieci script modifica il tenant: leggono e scrivono un CSV. L'uso tipico è la revisione periodica degli accessi, l'offboarding, il capacity planning e la raccolta di evidenze per un audit.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-M365TeamsReport.ps1` | Elenca tutti i Teams del tenant (gruppi Microsoft 365 con provisioning "Team") con visibilità Public/Private, numero di proprietari, membri e ospiti, data di creazione. | Sola lettura |
| `02-Get-M365OrphanedTeams.ps1` | Trova i team orfani, cioè senza alcun proprietario: nessuno è responsabile della gestione e della membership, e gli accessi non vengono più revisionati. | Sola lettura |
| `03-Get-M365TeamsMembership.ps1` | Esporta una riga per ogni appartenenza (team, persona, ruolo owner o member, tipo di utente): la mappa completa di chi è in quale team. | Sola lettura |
| `04-Get-M365TeamsChannels.ps1` | Elenca i canali di ciascun team con il tipo di membership (standard, privato, condiviso) e conta quelli privati o condivisi. | Sola lettura |
| `05-Get-M365TeamsWithGuests.ps1` | Elenca i team con almeno un ospite esterno e i relativi indirizzi, per sapere dove c'è collaborazione esterna. | Sola lettura |
| `06-Get-M365SPOSitesReport.ps1` | Inventario dei siti SharePoint Online: URL, proprietario, modello, storage usato e quota, capacità di condivisione esterna, ultima modifica dei contenuti. | Sola lettura |
| `07-Get-M365SPOExternalSharingSettings.ps1` | Riporta la `SharingCapability` di ogni sito e quella del tenant, segnalando i siti al livello più aperto (`ExternalUserAndGuestSharing`, cioè link anonimi). | Sola lettura |
| `08-Get-M365SPOStorageReport.ps1` | Ordina i siti per spazio occupato, calcola la percentuale rispetto alla quota e il totale del tenant. | Sola lettura |
| `09-Get-M365FileDeletionAudit.ps1` | Interroga l'Unified Audit Log per le eliminazioni di file in SharePoint e OneDrive (`FileDeleted`, `FileRecycled`, cestino di primo e secondo livello): chi, quando, quale file, quale sito. | Sola lettura |
| `10-Get-M365TeamsMeetingAudit.ps1` | Estrae dall'Unified Audit Log i dettagli di partecipazione alle riunioni Teams: partecipante, ruolo, ora di ingresso e di uscita. | Sola lettura |

Nessuno dei dieci script scrive nel tenant e nessuno chiede permessi di scrittura. Attenzione però all'avvertenza 5: 06, 07 e 08 sono di sola lettura, ma per eseguirli serve un ruolo che può anche scrivere.

## Prima di eseguirli

**PowerShell.** 5.1 o 7. Nessuno degli script dichiara `#Requires -Version`, quindi su un host più vecchio non ricevi un messaggio chiaro: fallisce il primo cmdlet non supportato.

**Moduli.**

```powershell
# script 01-05 (Microsoft Graph)
Install-Module Microsoft.Graph -Scope CurrentUser

# script 06-08 (SharePoint Online Management Shell)
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser

# script 09-10 (Exchange Online, per l'Unified Audit Log)
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

Gli script 01-05 dichiarano `#Requires -Modules Microsoft.Graph.Authentication` (04 anche `Microsoft.Graph.Teams`), ma usano `Get-MgGroup`, `Get-MgGroupOwner` e `Get-MgGroupMember`, che stanno in `Microsoft.Graph.Groups` e non sono dichiarati da nessuno script: installare solo il modulo di autenticazione non basta. Il meta-modulo `Microsoft.Graph` del comando sopra li comprende tutti.

**Permessi e ruoli.**

- **01-05**: scope delegati Microsoft Graph. `Group.Read.All` per tutti e cinque; `GroupMember.Read.All` anche per 01, 03 e 05; `Channel.ReadBasic.All` anche per 04. Sono scope che **richiedono il consenso di un amministratore**: al primo `Connect-MgGraph` un utente non privilegiato riceve un errore di consenso e non un errore di permessi. Il consenso lo dà un Global Administrator, una volta per tenant.
- **01, 03 e 05** chiedono sia `Group.Read.All` sia `GroupMember.Read.All`. Il primo è il più ampio e consente già di leggere proprietari e membri di un gruppo: il secondo non aggiunge nulla e compare solo come voce in più nella schermata di consenso.
- **06-08**: ruolo **SharePoint Administrator**, più l'URL dell'admin center (`https://<tenant>-admin.sharepoint.com`) nel parametro obbligatorio `-AdminUrl`. Vedi l'avvertenza 5.
- **09-10**: connessione a Exchange Online e ruolo **View-Only Audit Logs**.

## ⚠️ Avvertenze

1. **Un report che sembra completo può non esserlo (01, 03, 05).** Le chiamate che leggono proprietari e membri usano `-ErrorAction SilentlyContinue`: se una di esse fallisce (throttling, permesso negato su un singolo gruppo, gruppo in stato transitorio) l'errore viene soppresso e il risultato di quella chiamata resta vuoto. In 05 un team che **ha** ospiti esterni viene semplicemente omesso dal CSV e il conteggio stampato a fine esecuzione risulta più basso del reale; in 01 i proprietari e i membri di quel team diventano 0; in 03 mancano righe di appartenenza, cioè proprio quelle che servono in un audit di offboarding. Lo script non distingue "nessun ospite" da "non ho potuto chiedere". Rilancia lo script e confronta i due esiti: se non coincidono, almeno uno dei due è incompleto. Confronta anche il numero di team riportato da 01 con il numero di team che vedi nel centro di amministrazione.

2. **L'elenco dei team orfani può contenere falsi positivi (02).** Stesso meccanismo, nella direzione opposta: se la lettura dei proprietari fallisce, la variabile resta vuota, la condizione "zero owner" risulta vera e il team finisce nell'elenco degli orfani. Lo script stampa poi in rosso "ATTENZIONE: N team SENZA owner", quindi un errore dell'API diventa un allarme di governance e porta a intervenire su team sani. Prima di assegnare proprietari o chiudere un team, verifica nel centro di amministrazione Teams che quei team siano davvero senza owner.

3. **Gli audit si fermano a 5.000 eventi senza dirlo (09, 10).** Entrambi chiamano `Search-UnifiedAuditLog` con `-ResultSize 5000`, senza `-SessionCommand ReturnLargeSet` e senza paginazione: se la finestra temporale contiene più eventi, ricevi i primi 5.000 e il messaggio finale stampa quel numero come se fosse il totale. Se il numero stampato è 5.000 o vicino a 5.000, tratta il report come troncato e rifai l'estrazione spezzando la finestra in intervalli più corti.

4. **Gli output sono dati personali (tutti, in particolare 03, 05, 09, 10).** I CSV non sono cifrati e nessuno script chiede conferma prima di scriverli né avvisa sul contenuto: 03 contiene lo userPrincipalName di ogni persona di ogni team, 05 gli indirizzi e-mail degli ospiti esterni, 09 l'identità di chi ha cancellato un file insieme al nome del file, 10 lo UPN di ogni partecipante a ogni riunione con ora di ingresso e di uscita. Gli ultimi due toccano il controllo a distanza dell'attività dei lavoratori: prima di eseguirli, verifica su quale base stai raccogliendo quei dati, chi può leggerli e per quanto tempo li conservi. Scrivili fuori dalle cartelle sincronizzate con OneDrive o SharePoint e cancellali quando non servono più.

5. **06, 07 e 08 sono di sola lettura, ma richiedono un ruolo che può scrivere.** `Get-SPOSite` e `Get-SPOTenant` funzionano solo con il ruolo SharePoint Administrator, che è tenant-wide e consente anche di cancellare siti e di cambiare la condivisione esterna dell'intero tenant; il modulo `Microsoft.Online.SharePoint.PowerShell` non ha un equivalente di sola lettura. Non è un difetto degli script, è una delega da non lasciare aperta: attiva il ruolo a tempo (per esempio con PIM), produci il report, disattivalo, invece di assegnarlo in modo permanente a chi deve solo leggere.

6. **`-Days` non è validato (09, 10).** L'help dichiara "max 90", ma il parametro è un `[int]` senza alcun vincolo: `-Days 400` viene accettato e produce una data iniziale fuori dalla retention dell'Unified Audit Log, `-Days -5` viene accettato e produce una data iniziale successiva a quella finale. In entrambi i casi ottieni un CSV vuoto o un errore grezzo, non un messaggio comprensibile. Qui un CSV vuoto non significa "nessun evento": significa che la finestra chiesta non ha senso.

## Dove finiscono i file

Tutti e dieci gli script accettano `-OutputCsv`. Se non lo passi, il file nasce **nella directory corrente**, con un nome che contiene solo la data (per esempio `.\M365-TeamsMembership-20261029.csv`). Due conseguenze:

- **Il file nasce dove si trova il prompt, non dove si trova lo script.** Se hai clonato il repository e lanci gli script da quella cartella, i CSV finiscono dentro il clone. Il `.gitignore` del repository esclude `*.csv`, ma non fidarti di quella rete: passa `-OutputCsv` con un percorso fuori dal clone e fuori dalle cartelle sincronizzate con OneDrive o SharePoint.
- **Una seconda esecuzione nello stesso giorno sovrascrive la prima, senza chiedere.** Il nome contiene la data ma non l'ora. Se devi confrontare due esecuzioni dello stesso giorno (è il modo per accorgersi dei report incompleti dell'avvertenza 1), dai a ciascuna un `-OutputCsv` diverso.

Sul contenuto di questi file vale l'avvertenza 4: sono dati personali in chiaro.

## Esempi

```powershell
# Team senza proprietario: nessun parametro necessario
.\02-Get-M365OrphanedTeams.ps1

# Inventario dei siti SharePoint: -AdminUrl è obbligatorio
.\06-Get-M365SPOSitesReport.ps1 -AdminUrl https://contoso-admin.sharepoint.com

# Eliminazioni di file degli ultimi 30 giorni
.\09-Get-M365FileDeletionAudit.ps1 -Days 30

# Partecipanti alle riunioni Teams degli ultimi 14 giorni
.\10-Get-M365TeamsMeetingAudit.ps1 -Days 14
```

## Download e supporto

Lo stesso contenuto è scaricabile come ZIP dalla pagina [synsphere.it/download/toolkit-powershell-teams-sharepoint-microsoft-365](https://synsphere.it/download/toolkit-powershell-teams-sharepoint-microsoft-365/). Se serve aiuto su Teams e SharePoint: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
