# Pre-flight per migrazione tenant-to-tenant (Microsoft 365)

Dieci script PowerShell di sola lettura che fotografano un tenant Microsoft 365 prima di una migrazione tenant-to-tenant ed esportano in CSV i dati con cui dimensionarla e pianificarla.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Prima di spostare un tenant bisogna sapere che cosa c'è dentro: quali domini e quali record DNS sono pubblicati, quante cassette ci sono e quanto pesano, quali deleghe andranno ricostruite a mano, chi è sincronizzato da Active Directory e chi è nato nel cloud, quante licenze serviranno di là. Questi script raccolgono quei dati e li scrivono in CSV, uno per area, più un cruscotto di sintesi.

Sono rivolti a chi deve dimensionare e pianificare una migrazione tenant-to-tenant: MSP, consulenti e reparti IT di PMI. Non spostano e non modificano niente, sono tutti `Get-*`. Dove possono, disinnescano i default di Exchange Online, SharePoint e Microsoft Graph che producono un report sbagliato senza mostrare un errore: `ResultSize` fermo a 1000, `Get-SPOSite -Limit` fermo a 200, le undici proprietà che `Get-MgUser` restituisce se non gliene si chiedono altre, il tri-stato di `onPremisesSyncEnabled`, `NT AUTHORITY\SELF` che compare fra le deleghe di ogni cassetta.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-T2TDomains.ps1` | Domini del tenant (verificato, predefinito, iniziale, gestito o federato) e per ognuno i record di servizio pubblicati oggi: MX, TXT di verifica e SPF, CNAME, SRV | Sola lettura |
| `02-Get-T2TMailboxInventory.ps1` | Cassette con ExchangeGuid, ArchiveGuid, dimensioni e numero elementi: i valori da riportare sugli oggetti mail-enabled del tenant di destinazione | Sola lettura |
| `03-Get-T2TMailboxDelegations.ps1` | FullAccess, SendAs e SendOnBehalf, cioè l'elenco delle deleghe da ricostruire; esclude SELF e le voci coperte da un Deny | Sola lettura |
| `04-Get-T2TGroups.ps1` | Distribution list, gruppi di sicurezza mail-enabled, gruppi Microsoft 365 e dinamici, con membri, owner e filtro di appartenenza | Sola lettura |
| `05-Get-T2TLicenseGap.ps1` | Licenze per utente e per SKU, usageLocation, e quali licenze arrivano da un gruppo invece che da un'assegnazione diretta | Sola lettura |
| `06-Get-T2TSharePointSizing.ps1` | Siti SharePoint e OneDrive personali con spazio occupato e quota, normalizzati in byte | Sola lettura (chiude la sessione SharePoint: vedi avvertenza 6) |
| `07-Get-T2TTeamsInventory.ps1` | Team con owner e canali standard, privati e condivisi, letti da Microsoft Graph perché il modulo Teams non espone i condivisi | Sola lettura |
| `08-Get-T2TMailFlow.ps1` | Connettori in ingresso e in uscita, domini accettati e remoti, regole di trasporto con il loro stato | Sola lettura |
| `09-Get-T2TEntraObjects.ps1` | Utenti cloud-only contro sincronizzati da on-premises, guest, e i gruppi di sicurezza che Exchange non vede | Sola lettura |
| `10-Get-T2TPreflightSummary.ps1` | Cruscotto: conteggi e volumi del tenant in un unico CSV; con `-SharePointCsv` somma anche SharePoint e OneDrive | Sola lettura |

Nessuno scrive sul tenant: l'unica cosa che producono è un CSV su disco.

**Ordine consigliato:** 09 → 05 → 02 → 03 → 04 → 01 → 08 → 06 → 07 → 10. Si parte dalle identità perché la distinzione cloud-only / sincronizzati decide il piano, e si chiude col cruscotto, a cui si passa il CSV dello script 06.

**Perimetro.** Il toolkit non produce i record DNS da creare sul tenant di destinazione: i CNAME DKIM del target dipendono dal prefisso del suo dominio iniziale e dalla partizione assegnata, valori che esistono solo dopo che il dominio è stato aggiunto di là, quindi un runbook DNS ricavato dal sorgente sarebbe sbagliato. E non verifica Organization Relationship, MailboxMoveCapability o la raggiungibilità dell'endpoint di migrazione, perché in un pre-flight quegli oggetti non esistono ancora.

## Prima di eseguirli

**PowerShell.** Windows PowerShell 5.1 oppure PowerShell 7. Nessuno script impone una versione minima con `#Requires -Version`; ciascuno dichiara invece i moduli che gli servono con `#Requires -Modules` e si ferma subito se mancano.

**Moduli.**

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser                 # 02, 03, 04, 08, 10
Install-Module Microsoft.Graph -Scope CurrentUser                          # 01, 05, 07, 09, 10
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser   # solo 06
```

Se preferisci non installare l'intero meta-modulo Graph, i sottomoduli effettivamente dichiarati sono `Microsoft.Graph.Identity.DirectoryManagement` (01, 05, 10), `Microsoft.Graph.Users` (05, 09, 10), `Microsoft.Graph.Groups` (07, 09) e `Microsoft.Graph.Teams` (07).

**Ruoli e permessi.** Tutti in sola lettura: in nessuno dei dieci script compare uno scope `.ReadWrite.` o `.Write`, né gestione di ruoli, né assegnazione di app role.

| Script | Quello che lo script dichiara e chiede | Set minimo che copre le chiamate effettive |
| --- | --- | --- |
| 01 | Graph: `Domain.Read.All` (Global Reader è sufficiente) | come dichiarato |
| 02, 03, 04, 08 | Exchange: View-Only Organization Management | come dichiarato |
| 05 | Graph: `User.Read.All`, `Organization.Read.All`, `Directory.Read.All` | `User.Read.All` + `Organization.Read.All` |
| 06 | SharePoint Administrator (oppure Global Reader per la sola lettura) | come dichiarato |
| 07 | Graph: `Group.Read.All`, `Channel.ReadBasic.All`, `ChannelMember.Read.All`; ruolo consigliato: Teams Administrator | `Group.Read.All` + `Channel.ReadBasic.All` |
| 09 | Graph: `User.Read.All`, `Group.Read.All`, `Directory.Read.All` | `User.Read.All` + `Group.Read.All` |
| 10 | Exchange: View-Only Organization Management, e Graph: `User.Read.All`, `Directory.Read.All`, `Organization.Read.All` | `User.Read.All` + `Organization.Read.All` |

**Due tenant = due esecuzioni separate.** `Connect-MgGraph` sostituisce la sessione del processo, ed Exchange Online e SharePoint tengono un contesto per sessione. Per confrontare sorgente e destinazione si esegue il toolkit su un tenant per volta, in processi PowerShell distinti, e si confrontano i CSV offline. Due tenant nello stesso processo riporterebbero due volte lo stesso tenant, senza dare errore.

**Tempi.** Lo script 10 chiama `Get-MailboxStatistics` una volta per ogni cassetta del tenant, senza indicatore di avanzamento e senza un interruttore per saltare le statistiche: su un tenant grande sembra bloccato, ma sta lavorando. Lo script 02 ha invece `-SkipStatistics` e una barra di avanzamento.

## ⚠️ Avvertenze

1. **L'output è un export di dati personali.** Lo script 09 esporta, per ogni utente, nome, UserPrincipalName, indirizzo di posta, ImmutableId, SamAccountName e usageLocation; lo 03 la mappa completa di chi ha accesso alla cassetta di chi; lo 04 l'indirizzo di ogni membro di ogni gruppo; lo 06 gli URL dei OneDrive, che contengono l'identità dell'utente. Sono dati personali ai sensi del GDPR e vanno trattati come tali: dove li tieni, per quanto tempo, e la cancellazione a fine assessment. Aggravante pratica: il percorso predefinito è la cartella corrente, quindi se lanci gli script dentro il repository clonato i CSV di un cliente finiscono nel working tree di git. Esegui da una cartella fuori dal clone.

2. **Cinque errori vengono inghiottiti in silenzio, e due di essi abbassano i numeri.** Nello script 10 ogni `Get-MailboxStatistics` che fallisce viene ignorato senza un avviso: il volume totale delle cassette, cioè il numero con cui si dimensiona la migrazione, esce più basso del vero e ha l'aspetto di un risultato corretto. Nello script 04, se la lettura dei membri di un gruppo fallisce, il gruppo viene esportato con `NumeroMembri` a 0 e la colonna `Membri` vuota, indistinguibile da un gruppo realmente vuoto; lo stesso vale per gli owner, nello 04 e nello 07, dove un team può risultare senza owner solo perché la chiamata è fallita. Confronta i conteggi con quello che vedi nel portale, e non accettare uno zero senza verificarlo.

3. **Senza i ruoli giusti il report esce incompleto, non in errore.** Lo script 07 senza il ruolo Teams Administrator restituisce i canali privati e condivisi in modo incompleto, e il conteggio esce più basso del vero senza un solo messaggio. Vale in generale: se un consenso Graph manca o è più stretto del necessario, il CSV può uscire vuoto o con tutte le righe negative, e un numero senza il suo denominatore inganna. Verifica di avere i ruoli della tabella qui sopra prima di fidarti di un risultato, soprattutto se quel risultato è uno zero.

4. **Una seconda esecuzione nello stesso giorno sovrascrive il CSV precedente, senza chiedere.** Tutti i nomi predefiniti contengono solo la data (`yyyyMMdd`) e nessuna delle tredici esportazioni usa `-NoClobber` o controlla se il file esiste già. Si somma alla regola del punto precedente: chi esegue il sorgente e poi la destinazione nella stessa cartella e nello stesso giorno si ritrova il CSV del sorgente sostituito da quello del target, con lo stesso nome file e nessun errore. Esegui ciascun tenant in una sottocartella dedicata, oppure passa un percorso esplicito ai parametri (`-OutputCsv`, `-SkuCsv`, `-TeamsCsv`, `-GroupsCsv`): nessun percorso è cablato nel codice.

5. **Il consenso che l'amministratore vede è più ampio di quello che gli script usano.** Lo script 07 chiede `ChannelMember.Read.All`, che dà accesso in lettura all'elenco dei membri di ogni canale compresi i privati, ma non legge mai i membri di un canale: le sue chiamate sono coperte da `Group.Read.All` e `Channel.ReadBasic.All`. Allo stesso modo `Directory.Read.All`, chiesto dagli script 05, 09 e 10, legge l'intera directory mentre gli scope più stretti coprirebbero già le chiamate effettive. Sono tutti permessi di sola lettura, ma se il tenant concede i consensi con parsimonia usa il set minimo della tabella qui sopra.

6. **Lo script 06 chiude la tua sessione SharePoint anche se non l'ha aperta lui.** Il blocco finale esegue sempre `Disconnect-SPOService`: se avevi già un `Connect-SPOService` attivo per altro lavoro, al termine dello script te lo ritrovi chiuso e devi riconnetterti. Gli script Exchange si comportano diversamente: verificano con `Get-ConnectionInformation` se la connessione esiste già, e non disconnettono mai.

## Dove finiscono i file

Ogni script scrive uno o due CSV in UTF-8 nella directory **corrente**, con un nome che contiene solo la data: `T2T-Domains-<data>.csv`, `T2T-Mailboxes-<data>.csv`, `T2T-Delegations-<data>.csv`, `T2T-Groups-<data>.csv`, `T2T-Licenses-<data>.csv` e `T2T-LicenseSkus-<data>.csv`, `T2T-SharePoint-<data>.csv`, `T2T-Teams-<data>.csv` e `T2T-TeamsChannels-<data>.csv`, `T2T-MailFlow-<data>.csv`, `T2T-EntraUsers-<data>.csv` e `T2T-EntraGroups-<data>.csv`, `T2T-Summary-<data>.csv`.

Due conseguenze da tenere a mente ogni volta:

- Il file nasce dove si trova il prompt, non dove sta lo script. Se hai clonato questo repository e lanci da lì, il CSV finisce **dentro il clone**. Il `.gitignore` della radice esclude `*.csv`, ma non fidarti del filtro come unica protezione: non committare quei file, e meglio ancora lavora da una cartella fuori dal repository.
- Una seconda esecuzione nello stesso giorno sovrascrive la precedente senza chiedere (avvertenza 4).

**Contenuto sensibile.** I CSV non sono anonimi. Contengono nominativi, UserPrincipalName e indirizzi di posta (02, 03, 04, 05, 09), ImmutableId e SamAccountName degli utenti sincronizzati da Active Directory (09), l'elenco degli utenti guest esterni (09), la mappa dei permessi di accesso alle cassette (03), l'elenco dei membri di ogni gruppo (04) e gli URL dei OneDrive personali (06). Lo 08 aggiunge configurazione di infrastruttura: gli indirizzi IP dei mittenti ammessi dai connettori in ingresso e gli smart host di quelli in uscita. Trattali come l'export di un sistema di produzione, perché è quello che sono.

## Esempi

```powershell
# Si parte dalle identità: cloud-only contro sincronizzati da on-premises
.\09-Get-T2TEntraObjects.ps1

# Inventario delle cassette senza le statistiche di dimensione, sui tenant grandi
.\02-Get-T2TMailboxInventory.ps1 -SkipStatistics

# Dimensionamento di SharePoint e OneDrive
.\06-Get-T2TSharePointSizing.ps1 -TenantAdminUrl https://contoso-admin.sharepoint.com

# Cruscotto finale, col volume SharePoint preso dal CSV dello script 06
.\10-Get-T2TPreflightSummary.ps1 -SharePointCsv .\T2T-SharePoint-20260824.csv
```

## Download e supporto

Lo stesso contenuto si scarica come archivio ZIP dalla pagina [synsphere.it/download/toolkit-powershell-migrazione-tenant-to-tenant-preflight](https://synsphere.it/download/toolkit-powershell-migrazione-tenant-to-tenant-preflight/).

Gli script sono forniti "as is", senza garanzia: verificali in un ambiente di prova prima di usarli su un tenant di produzione. Se serve aiuto, o un assessment di migrazione seguito da noi: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
