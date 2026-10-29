# Backup e continuità Microsoft 365 — 10 script PowerShell

Dieci script di sola lettura che misurano quanto è davvero recuperabile un tenant Microsoft 365, e lasciano un CSV per ogni misura.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Microsoft 365 non include un backup nativo: vale il modello di responsabilità condivisa, in cui Microsoft garantisce l'infrastruttura e i dati restano responsabilità del cliente. Ciò che il servizio offre nativamente è una **recuperabilità a breve termine** — hold, Single Item Recovery, cestini della directory, retention policy — e nessuna console la riassume in un quadro unico.

Questo toolkit misura quella recuperabilità, cassetta per cassetta e policy per policy, e la mette su CSV. È pensato per chi amministra Microsoft 365 di PMI (MSP, IT manager interni) e deve decidere dove intervenire prima, e se serve un backup dedicato. Misura la recuperabilità nativa: non la crea e non sostituisce un backup.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-MailboxHoldStatus.ps1` | Cassette utente e condivise con Litigation Hold, Retention Hold e In-Place Hold: quali cassette sono protette dalla conservazione e quali no. | Sola lettura |
| `02-Get-MailboxRecoverySettings.ps1` | Finestra di conservazione degli elementi eliminati (`RetainDeletedItemsFor`) e stato di Single Item Recovery per ogni cassetta: che cosa e per quanto si può recuperare. | Sola lettura |
| `03-Get-MailboxesAtRisk.ps1` | Cassette utente che non hanno alcun hold **e** hanno Single Item Recovery disattivato: la lista di priorità su cui intervenire. | Sola lettura |
| `04-Get-SoftDeletedMailboxes.ps1` | Cassette eliminate ma ancora ripristinabili, con data di eliminazione e giorni residui stimati. | Sola lettura |
| `05-Get-InactiveMailboxes.ps1` | Cassette inactive: cassette di utenti eliminati che restano conservate perché coperte da un hold o da una retention policy al momento della cancellazione. | Sola lettura |
| `06-Get-RetentionPolicies.ps1` | Retention policy di Microsoft Purview con stato, modalità e workload dichiarato. Il campo `Workload` del cmdlet elenca sempre tutti i workload possibili, non l'ambito su cui la policy è effettivamente applicata: per quello serve `-DistributionDetail`. | Sola lettura |
| `07-Get-DeletedUsers.ps1` | Utenti eliminati ancora recuperabili dal cestino della directory di Entra ID, con data di eliminazione e giorni residui stimati. | Sola lettura |
| `08-Get-DeletedGroups.ps1` | Gruppi eliminati ancora recuperabili dal cestino della directory. Solo i gruppi Microsoft 365 sono recuperabili, i gruppi di sicurezza no. | Sola lettura |
| `09-Get-ArchiveMailboxStatus.ps1` | Stato dell'archivio online per ogni cassetta: archivio attivo, archivio a espansione automatica, nome dell'archivio. | Sola lettura |
| `10-Get-M365ContinuitySummary.ps1` | Cruscotto unico: cassette con hold, cassette a rischio, soft-deleted, inactive, retention policy e utenti eliminati. Interroga le tre fonti in modo indipendente; quella non disponibile diventa `n/d`. | Sola lettura |

Nessuno dei dieci script modifica la configurazione del tenant.

## Prima di eseguirli

**PowerShell 5.1 o PowerShell 7.** Gli script sono salvati in UTF-8 con BOM, l'unica codifica che entrambe le versioni interpretano correttamente. Se li riapri e li risalvi senza BOM, su PowerShell 5.1 gli accenti nell'output e in `Get-Help` diventano illeggibili.

**Moduli.**

```powershell
# Exchange Online e Purview (01-06, 09, 10). Serve la 3.2.0 o superiore,
# perché fornisce sia Connect-ExchangeOnline sia Connect-IPPSSession.
Install-Module ExchangeOnlineManagement -MinimumVersion 3.2.0 -Scope CurrentUser

# Microsoft Graph (07, 08 e parte di 10)
Install-Module Microsoft.Graph -Scope CurrentUser

# in alternativa al meta-modulo, i due soli sottomoduli necessari
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
```

**Contesti di connessione e permessi.** Sono tre, separati: essere connessi a Exchange Online non dà accesso ai cmdlet di Purview.

| Contesto | Serve per | Permesso minimo |
| --- | --- | --- |
| `Connect-ExchangeOnline` | 01, 02, 03, 04, 05, 09 e la parte Exchange di 10 | ruolo di sola lettura **View-Only Recipients** |
| `Connect-IPPSSession` | 06 e la parte retention di 10 | un ruolo di lettura sulle retention policy nel portale Microsoft Purview |
| `Connect-MgGraph` | 07 e la parte Graph di 10; 08 | **User.Read.All** (07, 10) e **Group.Read.All** (08) |

I due scope Graph sono di sola lettura e sono il minimo privilegio per leggere `/directory/deletedItems`: nessuno script richiede uno scope `.ReadWrite.All`. Sono però scope a livello di tenant, quindi alla prima esecuzione richiedono il consenso di un amministratore.

## ⚠️ Avvertenze

1. **03 e il cruscotto 10 non guardano le cassette condivise.** I due script interrogano solo `-RecipientTypeDetails UserMailbox`, mentre 01, 02 e 09 includono anche `SharedMailbox`. Una cassetta condivisa senza hold e con Single Item Recovery disattivato non comparirà quindi mai nell'elenco "a rischio" e non verrà contata dal cruscotto, pur essendo esattamente il caso più esposto. Incrocia sempre 03 con 01 e 02 prima di dichiarare coperto un perimetro.

2. **07, 08 e 10 fanno scattare il consenso amministratore prima di poter funzionare.** I tre script dichiarano `#Requires -Modules Microsoft.Graph.Authentication`, ma i cmdlet che usano (`Get-MgDirectoryDeletedItemAsUser`, `Get-MgDirectoryDeletedItemAsGroup`) stanno in `Microsoft.Graph.Identity.DirectoryManagement`. Se hai installato solo il sottomodulo Authentication la guardia `#Requires` passa, `Connect-MgGraph` chiede il consenso sul tenant e solo dopo lo script muore con `CommandNotFoundException`: hai concesso un consenso a vuoto. In 10 il `try/catch` lo degrada a `n/d` senza errore evidente. Installa `Microsoft.Graph`, o i due sottomoduli indicati sopra, prima della prima esecuzione.

3. **Il cruscotto 10 esporta il CSV anche quando una fonte non ha risposto.** Le tre interrogazioni stanno in `try/catch` separati: se una fallisce — ruolo mancante, consenso non concesso, throttling — la metrica vale `n/d`, compare una riga gialla "non disponibile" e il CSV viene scritto comunque. `n/d` non è uno zero, ma la riga esportata ha lo stesso aspetto di un quadro completo, e una mancanza di permessi si legge come "nessun problema". Prima di usare i numeri, controlla che non sia comparsa nessuna riga "non disponibile" e che nessun campo del CSV sia `n/d`.

4. **`GiorniResidui` è una stima, e in 04 è calcolato in ora locale.** La finestra di 30 giorni è un'ipotesi scritta nello script, non un valore letto dal tenant. Inoltre 04 confronta `WhenSoftDeleted`, che è in UTC, con l'ora locale, mentre 07 e 08 usano correttamente `(Get-Date).ToUniversalTime()`: il valore di 04 è sfasato dell'offset locale (una o due ore in Italia) e a cavallo della mezzanotte può mostrare un giorno in più o in meno. Non programmare un ripristino sull'ultimo giorno indicato dalla colonna: verifica la finestra reale nel portale.

5. **I CSV contengono dati personali in chiaro.** Nome visualizzato, indirizzo di posta primario e UPN di dipendenti ed ex dipendenti finiscono nei file senza mascheratura, e i report 04, 05 e 07 sono di fatto elenchi di persone uscite dall'organizzazione. L'esecuzione produce quindi, sul disco di chi la lancia, un file rilevante ai fini del GDPR. Lancia gli script da una cartella locale fuori dalla sincronizzazione, oppure passa `-OutputCsv` con un percorso scelto, e cancella i file quando l'analisi è chiusa.

6. **In 06 un diniego di permessi si presenta come una richiesta di login.** Lo script racchiude `Get-RetentionCompliancePolicy` in un `try/catch` che interpreta qualsiasi errore come "non sono connesso" e reagisce chiamando `Connect-IPPSSession`; la seconda chiamata non è protetta. Un ruolo di lettura mancante su Purview, o un throttling, si manifestano quindi come un secondo prompt di accesso invece che come un messaggio chiaro, e l'elenco delle retention policy può risultare vuoto per un motivo che non viene detto. Se lo script chiede l'accesso a Purview due volte di seguito, sospetta il ruolo mancante, non la sessione scaduta.

## Dove finiscono i file

Tutti e dieci gli script esportano un CSV. Il percorso predefinito è **relativo** — `.\M365-<nome>-<data>.csv` — e il nome contiene solo la data, non l'ora. Da qui due conseguenze, sempre valide:

- **Il file nasce dove si trova il prompt**, qualunque esso sia. Se hai clonato questo repository e lanci gli script da lì, il CSV finisce dentro il clone. La radice del repository esclude `*.csv` dal versionamento, ma non fidarti dell'esclusione: dai un `git status` prima di committare.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente senza chiedere.** `Export-Csv` non usa `-Append` né `-NoClobber`: se vuoi confrontare due esecuzioni dello stesso giorno, rinomina il primo file o passa `-OutputCsv`.

Il contenuto è dato personale, non aggregato: nomi visualizzati, indirizzi di posta primari, UPN, nomi di utenti e gruppi eliminati, nomi delle retention policy. Vale il punto 5 delle avvertenze.

## Esempi

```powershell
# le due più utili per decidere dove intervenire
.\03-Get-MailboxesAtRisk.ps1
.\10-Get-M365ContinuitySummary.ps1

# inventario degli hold e degli utenti eliminati
.\01-Get-MailboxHoldStatus.ps1
.\07-Get-DeletedUsers.ps1

# fuori dalla cartella corrente: ogni script accetta -OutputCsv
.\03-Get-MailboxesAtRisk.ps1 -OutputCsv 'C:\Audit\cassette-a-rischio.csv'
```

## Download e supporto

Lo stesso contenuto è scaricabile come ZIP dalla pagina [synsphere.it/download/toolkit-powershell-backup-continuita-m365](https://synsphere.it/download/toolkit-powershell-backup-continuita-m365/).

Per una strategia di backup e continuità su Microsoft 365 — add-on Microsoft 365 Backup o soluzioni di terze parti, configurazione di hold e retention — scrivici da [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
