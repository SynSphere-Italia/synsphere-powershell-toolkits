# SynSphere PowerShell Toolkits

247 script PowerShell per amministrare Microsoft 365, Azure ed Entra ID. Nascono
dal lavoro quotidiano di [SynSphere Italia](https://synsphere.it) sui tenant dei
nostri clienti: ogni script risolve un problema che ci siamo trovati davanti
almeno una volta.

[English version](README.en.md) · [Licenza Apache-2.0](LICENSE) · [Sicurezza](SECURITY.md) · [Contribuire](CONTRIBUTING.md)

---

## Prima di cominciare: due cose che contano

**La maggior parte è in sola lettura, ma non tutta.** Gli script il cui nome
inizia per `Get-` o `Export-` leggono e basta. Quelli con un altro verbo
(`Set-`, `Remove-`, `Invoke-`, `New-`) **modificano il tenant**. La tabella
degli script in ogni cartella marca le due categorie, e dove esiste `-WhatIf`
va usato la prima volta.

**I `#Requires` dei moduli Graph sono incompleti, e lo diciamo noi.** Quasi
tutti gli script dichiarano solo `Microsoft.Graph.Authentication`, che fornisce
`Connect-MgGraph` e nient'altro. I cmdlet `Get-Mg*` che usano vivono in altri
sottomoduli. Se installi solo quello che il `#Requires` dichiara, il primo
`Get-Mg*` risponde «termine non riconosciuto». La via breve e sicura è
installare il meta-modulo:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser
Install-Module Az -Scope CurrentUser          # solo per i toolkit Azure
```

Ogni cartella elenca i moduli che servono davvero ai suoi script.

---

## I toolkit

### Microsoft 365 — 114 script

| Cartella | Script | Che cosa risolve |
| --- | ---: | --- |
| [license-management](microsoft-365/license-management/) | 10 | Chi ha quali licenze, quali SKU sono consumati, shared mailbox licenziate per errore, licenze dirette sovrapposte a quelle da gruppo, utenti licenziati e inattivi |
| [user-lifecycle](microsoft-365/user-lifecycle/) | 10 | Ultimo accesso reale, stato MFA, età delle password, amministratori e ruoli, manager, storico sign-in, e l'offboarding completo di un utente |
| [exchange-mailbox](microsoft-365/exchange-mailbox/) | 10 | Deleghe su caselle e shared mailbox, lookup inverso degli accessi di un utente, dimensioni di caselle e archivi, inoltri automatici |
| [groups](microsoft-365/groups/) | 10 | Inventario di gruppi e liste di distribuzione, owner e membri, gruppi vuoti, gruppi senza proprietario, i gruppi di un singolo utente |
| [teams-sharepoint](microsoft-365/teams-sharepoint/) | 10 | Team con owner, membri e ospiti, team orfani, canali privati e condivisi, siti SharePoint e consumo di spazio |
| [guest-external](microsoft-365/guest-external/) | 10 | Ospiti esterni con dominio di provenienza e stato dell'invito, ospiti inattivi da ripulire, impostazioni di collaborazione esterna del tenant |
| [backup-continuity](microsoft-365/backup-continuity/) | 10 | Quanto è davvero recuperabile un tenant: hold, finestra di ripristino, Single Item Recovery, cassette senza alcuna protezione, elementi eliminati ancora recuperabili |
| [tenant-to-tenant-preflight](microsoft-365/tenant-to-tenant-preflight/) | 10 | La fotografia da prendere **prima** di una migrazione fra tenant: domini e DNS, GUID delle cassette, deleghe da ricostruire, licenze, dimensionamento |
| [mailbox-delegation](microsoft-365/mailbox-delegation/) | 2 | Assegna o revoca le quattro deleghe di una cassetta (FullAccess, SendAs, SendOnBehalf, cartella), con i preset per lo scenario assistente-responsabile |
| [intune-endpoint](microsoft-365/intune-endpoint/) | 10 | Parco endpoint gestito: inventario, conformità totale e per sistema operativo, policy e profili con le assegnazioni, app distribuite, Autopilot |
| [windows-11-migration](microsoft-365/windows-11-migration/) | 10 | Idoneità hardware sulla singola macchina e sull'intera flotta via WinRM (TPM 2.0, Secure Boot, UEFI/GPT, RAM, CPU), inventario dei Windows 10 e delle applicazioni |
| [aruba-imap-migration](microsoft-365/aruba-imap-migration/) | 1 | Migrazione della posta da Aruba a Microsoft 365 via IMAP |
| [ai-agents-governance](microsoft-365/ai-agents-governance/) | 11 | Governance degli agenti AI: agent identity e permessi reali, chi li ha concessi e quando, interazioni Copilot nell'audit log, licenze Copilot, shadow AI su Power Platform |

### Azure — 80 script

| Cartella | Script | Che cosa risolve |
| --- | ---: | --- |
| [compute](azure/compute/) | 10 | Inventario VM e dischi, VM spente ma ancora allocate, VM senza backup, dischi orfani, estensioni, auto-shutdown, stato delle patch |
| [cost-management](azure/cost-management/) | 10 | Dove vanno i soldi (per resource group, servizio, risorsa, trend mensile) e che cosa si può tagliare subito: dischi e IP pubblici inutilizzati |
| [governance](azure/governance/) | 10 | Inventario multi-subscription, tag mancanti e applicazione in bulk, resource group vuoti, lock, risorse orfane che restano in fattura |
| [monitoring](azure/monitoring/) | 10 | Activity Log, regole di alert e Action Group, workspace Log Analytics, esiti dei job di backup, autoscale, diagnostic settings |
| [networking](azure/networking/) | 10 | Inventario VNet e subnet, export completo delle regole NSG, IP pubblici, risorse di rete orfane, peering, Load Balancer e Application Gateway, record DNS |
| [rbac](azure/rbac/) | 10 | Chi ha quale ruolo su quale scope: assegnazioni complete, ruoli privilegiati, ruoli custom, assegnazioni orfane, service principal, ereditarietà dai gruppi |
| [security](azure/security/) | 10 | Secure Score e raccomandazioni di Defender for Cloud, regole NSG aperte a Internet su porte di gestione e database, IP pubblici esposti, Key Vault |
| [storage-database](azure/storage-database/) | 10 | Storage account (ridondanza, capacità, container anonimi, firewall, lifecycle policy) e database SQL |

### Sicurezza e conformità — 53 script

| Cartella | Script | Che cosa risolve |
| --- | ---: | --- |
| [defender](security/defender/) | 10 | Secure Score attuale e storico, azioni di miglioramento ordinate per divario, avvisi e incidenti aperti, utenti a rischio e rilevamenti di Entra ID Protection |
| [purview-compliance](security/purview-compliance/) | 10 | Quanto della configurazione Purview sta davvero proteggendo qualcosa: ambito reale delle policy di conservazione, etichette mai pubblicate, policy DLP |
| [email-security](security/email-security/) | 10 | Audit della posta: volumi per utente, esiti del filtro anti-spam e anti-phishing, eliminazioni, invii con delega, regole di trasporto, connettori, quarantena |
| [incident-response](security/incident-response/) | 10 | Le prime ore di un incidente: verifica go/no-go delle prove disponibili, fotografia reversibile degli account, contenimento, ripristino, export forensi |
| [entra-identity-governance](security/entra-identity-governance/) | 10 | Amministratori attivi e ruoli PIM eleggibili, app registration ed enterprise app, segreti e certificati in scadenza, consensi OAuth |
| [acn-cyber-taxonomy](security/acn-cyber-taxonomy/) | 1 | Consulta e esporta la Tassonomia Cyber dell'ACN, scaricata dalla fonte ufficiale a ogni esecuzione |
| [entra-credentials-expiry](security/entra-credentials-expiry/) | 1 | Scadenze di client secret e certificati delle app registration di Entra ID |
| [mailbox-retention-exposure](security/mailbox-retention-exposure/) | 1 | Inventario della conservazione della posta: litigation hold, caselle inattive, politiche applicate |

---

## ⚠️ Tre cose da sapere prima di eseguire qualsiasi cosa

**1. I report esportano nella directory corrente, e sovrascrivono.** Quasi tutti
gli script scrivono un CSV in `.\` con un nome che contiene solo la data. Due
conseguenze: se lanci lo script dalla cartella in cui hai clonato questo
repository, **il CSV nasce dentro il clone** (il `.gitignore` lo esclude, ma
non fidarti e controlla prima di un `git add`); e una seconda esecuzione nello
stesso giorno sovrascrive la precedente senza chiedere niente.

Alcuni di quei CSV contengono dati sensibili: chiavi di ripristino BitLocker,
indirizzi IP di accesso, permessi di cassetta, stato MFA, elenchi di ospiti
esterni. Le avvertenze di ogni cartella dicono quali.

**2. Un report vuoto non è una buona notizia.** Diversi script producono un
risultato che, se i permessi sono insufficienti, esce vuoto o tutto-negativo
senza errori: «nessuna VM ha il backup», «nessun utente ha l'MFA». Prima di
agire su un risultato estremo, verifica di avere i permessi che la cartella
dichiara. Un numeratore senza il suo denominatore non vale.

**3. Usa PowerShell 7 se puoi.** Gli script funzionano su Windows PowerShell
5.1, e i file di questo repository sono salvati in UTF-8 **con BOM** proprio
perché su 5.1 i messaggi con gli accenti si leggano correttamente. Se prendi
uno di questi script da un'altra fonte e lo vedi stampare `perchÃ©` invece di
`perché`, è un file senza BOM: ricopialo da qui.

---

## Rapporto con synsphere.it

Questo repository è la **fonte di verità** degli script. Le pagine di
[synsphere.it/download](https://synsphere.it/download/) ne distribuiscono gli
stessi contenuti confezionati in archivi ZIP, per chi preferisce scaricare un
file invece di clonare. Gli archivi si rigenerano dal repository con
`tools/Build-DownloadZips.ps1`: non esistono due copie da tenere allineate a
mano.

Molti toolkit hanno un articolo che ne spiega l'uso su un caso concreto: il
rimando è nel README di ogni cartella.

---

## Struttura

```
microsoft-365/   13 raccolte, 114 script
azure/            8 raccolte,  80 script
security/         8 raccolte,  53 script
tools/            Build-DownloadZips.ps1  rigenera gli archivi del sito
                  Test-Codifica.ps1       verifica UTF-8 con BOM e fine-riga LF
.github/          analisi PowerShell su ogni push e pull request
```

Ogni cartella contiene i suoi script, un `README.md` in italiano e un
`README.en.md` in inglese.

---

## Qualità

Su ogni push e su ogni pull request gira una pipeline che verifica quattro cose:
che ogni script sia analizzabile da PowerShell senza errori di sintassi; che
PSScriptAnalyzer non segnali errori; che la codifica sia UTF-8 con BOM e i
fine-riga LF; e che nessun segreto in chiaro — password, token, chiavi — sia
entrato nel repository.

---

## Licenza e marchi

Apache License 2.0 — vedi [LICENSE](LICENSE) e [NOTICE](NOTICE).

Il nome e il logo SynSphere non sono coperti dalla licenza. Microsoft,
Microsoft 365, Azure, Entra, Intune, Purview, Defender, Exchange, SharePoint,
Teams e Windows sono marchi del gruppo Microsoft: qui sono usati in modo
referenziale, per identificare i prodotti che questi script amministrano.
SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.

Gli script sono forniti **"as is"**, senza garanzie. Eseguirli su un tenant di
produzione è una responsabilità di chi li esegue: leggi l'header, usa `-WhatIf`
dove c'è, prova su un perimetro ristretto.

---

**SynSphere Italia SRL** — [synsphere.it](https://synsphere.it) ·
[Contattaci](https://synsphere.it/contattaci) · Milano e Bolzano
