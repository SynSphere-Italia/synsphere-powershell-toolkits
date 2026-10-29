# Azure Security & Compliance Toolkit

Dieci report di sola lettura che fotografano la postura di sicurezza di una subscription Azure e la esportano in CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

La raccolta è rivolta ad amministratori IT, MSP e team di sicurezza che devono produrre in fretta un assessment di una subscription Azure, o un'evidenza da allegare a un percorso di compliance (GDPR, ISO 27001). Ogni script interroga un'area diversa — Defender for Cloud, regole NSG, IP pubblici, storage account, Key Vault, dischi delle VM, Azure Policy, diagnostica — e scrive il risultato in un CSV, senza bisogno di installare nulla oltre al modulo Az.

Nessuno dei dieci script modifica il tenant: l'audit del codice non ha trovato nessun cmdlet di scrittura, solo `Get-*` e l'esportazione del CSV. È quindi materiale che si può eseguire anche su un tenant di un cliente senza il timore di cambiare qualcosa per sbaglio — il rischio, come spiega la sezione avvertenze, è di leggere male il risultato, non di guastare l'ambiente.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-AzSecureScore.ps1` | Secure Score di Microsoft Defender for Cloud: punteggio complessivo e per singolo control, con valore corrente, massimo e percentuale. | Sola lettura |
| `02-Get-AzSecurityRecommendations.ps1` | Assessment di Defender for Cloud in stato non integro: la to-do list di hardening, con severità e risorsa interessata. | Sola lettura |
| `03-Get-AzNsgOpenPorts.ps1` | Regole NSG inbound che accettano traffico da qualsiasi sorgente (`*`, `0.0.0.0/0`, `Internet`), con porte e priorità. Marca come ALTO le porte di gestione e di database (22, 3389, 1433, 3306, 5432, 445) e gli intervalli completi. | Sola lettura |
| `04-Get-AzPublicExposure.ps1` | Tutti gli IP pubblici della subscription, con SKU, metodo di allocazione e risorsa a cui sono associati (oppure "non associato"). | Sola lettura |
| `05-Get-AzStoragePublicAccess.ps1` | Storage account con accesso pubblico ai blob consentito, HTTPS non forzato o rete pubblica aperta. Nel CSV finiscono solo quelli con almeno un rilievo. | Sola lettura |
| `06-Get-AzKeyVaultSecurity.ps1` | Key Vault: soft-delete, purge protection, modello di autorizzazione (RBAC o access policy) e accesso di rete pubblico. | Sola lettura |
| `07-Get-AzVmDiskEncryption.ps1` | Stato di cifratura di disco OS e dischi dati di ogni VM (Azure Disk Encryption), con il conteggio delle VM che hanno l'OS non cifrato. | Sola lettura |
| `08-Get-AzPolicyCompliance.ps1` | Risorse in stato NonCompliant rispetto ad Azure Policy, con la definizione e l'assegnazione violate. | Sola lettura |
| `09-Get-AzResourcesWithoutDiagnostics.ps1` | Risorse senza alcuna impostazione di diagnostica, cioè i buchi nel logging. `-ResourceTypeLike` restringe l'analisi a un tipo di risorsa. | Sola lettura |
| `10-Get-AzKeyVaultExpiringSecrets.ps1` | Segreti e certificati dei Key Vault con scadenza entro N giorni (`-Days`, default 30). Esporta i nomi, non i valori. | Sola lettura |

## Prima di eseguirli

**PowerShell 5.1 oppure PowerShell 7.** È l'indicazione che accompagnava la raccolta: nessuno dei dieci script dichiara una versione minima con `#Requires -Version`, quindi su un host più vecchio non c'è niente che si fermi da sé.

**Modulo Az.** Il modo più semplice è il meta-modulo:

```powershell
Install-Module Az -Scope CurrentUser
```

In alternativa, soltanto i moduli effettivamente usati:

```powershell
Install-Module Az.Accounts, Az.Security, Az.Network, Az.Storage, Az.KeyVault, Az.Compute, Az.PolicyInsights, Az.Monitor, Az.Resources -Scope CurrentUser
```

Quale script usa cosa: `Az.Accounts` tutti e dieci; `Az.Security` 01 e 02; `Az.Network` 03 e 04; `Az.Storage` 05; `Az.KeyVault` 06 e 10; `Az.Compute` 07; `Az.PolicyInsights` 08; `Az.Monitor` e `Az.Resources` 09. Nessun `#Requires` fissa una versione minima di modulo.

**Autenticazione.** `Connect-AzAccount`, interattivo. Nel codice non c'è nessun'altra forma di autenticazione: nessuna app registration, nessuna credenziale salvata.

**Permessi.**

- Ruolo **Reader** sulla subscription: 03, 04, 05, 06 (control plane), 07, 08, 09.
- **Security Reader** e Defender for Cloud attivo sulla subscription: 01 e 02. Senza Defender for Cloud attivo i due report non hanno dati da leggere.
- Permessi **data-plane** sui Key Vault per 10: un access policy di lettura su segreti e certificati, oppure il ruolo Key Vault Reader / Key Vault Secrets User. Il ruolo Reader del control plane non basta.
- Nessuno script richiede permessi Microsoft Graph: la raccolta usa solo i moduli Az.

## ⚠️ Avvertenze

1. **Un risultato pari a zero non prova la conformità (09).** Lo script chiama `Get-AzDiagnosticSetting` una risorsa per volta e il blocco `catch` scarta l'errore senza contarlo: un tipo di risorsa che non supporta la diagnostica, un accesso negato per permessi mancanti e un 429 di rate limiting di ARM finiscono tutti nello stesso silenzio. Il messaggio finale stampa quindi un numeratore senza denominatore, e «0 risorse senza diagnostica» può voler dire che il logging è a posto oppure che non hai i permessi per vederlo. Restringi sempre l'ambito con `-ResourceTypeLike`, confronta il numero di righe del CSV con le risorse che ti aspettavi, e leggi il risultato come un minimo, non come un totale. Il rischio di throttling cresce proprio con il default `-ResourceTypeLike '*'`, che interroga tutte le risorse della subscription.

2. **L'ambito è la subscription già selezionata, e il report non dice quale.** Nessuno dei dieci script ha un parametro `-SubscriptionId` e nessuno invoca `Set-AzContext`: la riga `if (-not (Get-AzContext)) { Connect-AzAccount }` chiede le credenziali solo se un contesto non esiste, altrimenti riusa in silenzio quello aperto. Su un tenant con più subscription — o per un MSP che nella stessa sessione lavora su più clienti — l'audit gira su qualunque subscription sia correntemente attiva, e nel CSV non resta niente che permetta di capirlo a posteriori: un risultato parziale si legge come un risultato pulito e un report può finire attribuito al cliente sbagliato. Esegui `Get-AzContext` prima di ogni lancio e passa `-OutputCsv` con il nome della subscription nel nome del file.

3. **I CSV sono materiale sensibile e nascono nella directory corrente.** Nel loro insieme i report sono una mappa di attacco: 03 elenca le regole inbound aperte a Internet con porte e priorità, 04 gli indirizzi IP pubblici reali e la risorsa dietro a ciascuno, 05 gli storage account con blob pubblici o HTTP consentito, 10 i nomi di segreti e certificati con la data di scadenza. Il default di `-OutputCsv` è un percorso relativo, quindi se lanci gli script dentro il repository clonato o in una cartella sincronizzata quei file vengono committati o caricati sul cloud. Scrivili altrove con `-OutputCsv` e trattali come l'inventario di vulnerabilità che sono. Un dubbio da fugare: 10 invoca `Get-AzKeyVaultSecret` senza `-Name`, quindi legge solo i metadati — nel CSV finiscono i nomi dei segreti, mai i loro valori.

4. **Sette script su dieci si fermano al primo errore, e in quel caso non scrivono nessun CSV.** 01, 02, 03, 04, 05, 06 e 08 impostano `$ErrorActionPreference = 'Stop'` senza nessun `try/catch`, e l'`Export-Csv` è l'ultima istruzione: se una sola risorsa è inaccessibile l'eccezione interrompe l'esecuzione prima della scrittura, e tutta la raccolta già fatta va persa, senza nemmeno un file parziale. Lanciali uno alla volta, e rilancia quello che si è fermato dopo aver sistemato il permesso mancante. 07, 09 e 10 invece gestiscono l'errore e arrivano in fondo.

5. **07 chiede più permessi di quelli che usa.** Le `.NOTES` di `07-Get-AzVmDiskEncryption.ps1` scrivono «ruolo Reader/VM Contributor», ma lo script invoca soltanto `Get-AzVM` e `Get-AzVMDiskEncryptionStatus`: **Reader è sufficiente**. Virtual Machine Contributor è un ruolo di scrittura, che crea, riavvia e cancella VM e dischi: concederlo a sé stessi o a un service principal solo per produrre un report apre un permesso distruttivo che non verrà mai usato. Assegna solo Reader. Se nella colonna `OSCifrato` compare `n/d`, è un limite del cmdlet o dell'estensione ADE su quella VM, non un permesso di scrittura mancante.

6. **`-Days` accetta valori che invertono la finestra senza avvertire (10).** Il parametro è dichiarato `[int]$Days = 30` senza nessun attributo di validazione. Con `-Days -30` il limite calcolato cade nel passato e il report elenca soltanto ciò che è scaduto da oltre un mese, mentre il messaggio finale continua a dire «in scadenza entro -30 giorni»; con `-Days 0` la finestra si chiude su oggi. Passa sempre un intero positivo. Vale in generale: nessuno dei dieci script valida i propri parametri oltre al tipo.

## Dove finiscono i file

Tutti e dieci gli script esportano un CSV tramite `-OutputCsv`, il cui valore predefinito è un percorso **relativo** alla directory corrente e contiene solo la data: `.\Az-SecureScore-20261029.csv`, `.\Az-NsgOpenPorts-20261029.csv` e così via. Due conseguenze da tenere a mente ogni volta:

- **Il file nasce dove si trova il prompt, non dove si trova lo script.** Se hai clonato questo repository e lanci da lì, il CSV finisce dentro il clone. Il `.gitignore` nella radice esclude `*.csv`, ma non fidarti e controlla con `git status` prima di committare. Lo stesso vale per le cartelle sincronizzate su OneDrive, SharePoint o Dropbox: lì nessun `.gitignore` ti protegge.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente, senza chiedere.** Il nome contiene la data ma non l'ora. Se devi confrontare un prima e un dopo, passa `-OutputCsv` con due nomi diversi.

Il contenuto va protetto come un documento riservato: regole firewall aperte a Internet, indirizzi IP pubblici con la risorsa dietro a ognuno, storage account esposti, impostazioni di sicurezza dei Key Vault, nomi di segreti e certificati con la loro scadenza. Sono le informazioni che un attaccante userebbe per scegliere da dove iniziare.

## Esempi

```powershell
# Autenticarsi una volta, poi lanciare i report che servono
Connect-AzAccount
.\01-Get-AzSecureScore.ps1
.\03-Get-AzNsgOpenPorts.ps1

# Restringere l'analisi della diagnostica a un solo tipo di risorsa
.\09-Get-AzResourcesWithoutDiagnostics.ps1 -ResourceTypeLike '*Microsoft.KeyVault*'

# Finestra di scadenza a 60 giorni
.\10-Get-AzKeyVaultExpiringSecrets.ps1 -Days 60

# Scrivere il CSV fuori dal repository clonato e fuori dalle cartelle sincronizzate
.\04-Get-AzPublicExposure.ps1 -OutputCsv 'C:\Audit\sub-produzione-ip-pubblici.csv'
```

## Altro

Lo stesso contenuto si scarica come ZIP dalla pagina [synsphere.it/download/toolkit-powershell-azure-security/](https://synsphere.it/download/toolkit-powershell-azure-security/). La guida discorsiva alla raccolta è su [synsphere.it/notizie/script-powershell-azure-security-toolkit-pmi](https://synsphere.it/notizie/script-powershell-azure-security-toolkit-pmi).

Se serve aiuto a interpretare i report, o a rimediare a quello che hanno trovato: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
