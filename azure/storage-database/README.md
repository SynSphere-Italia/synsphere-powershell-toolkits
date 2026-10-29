# Azure Storage & Database Toolkit

Dieci script PowerShell di sola lettura che fotografano storage account e database SQL di una subscription Azure ed esportano ogni risultato in un CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Serve a produrre un assessment di sicurezza, conformità e costi su una subscription Azure senza installare nulla oltre al modulo Az: ridondanza e capacità degli storage, container blob aperti al pubblico, regole di rete e firewall, lifecycle policy mancanti, inventario dei database e degli elastic pool, cifratura TDE, auditing e retention dei backup.

È pensato per amministratori IT, MSP e DBA che devono mettere nero su bianco lo stato di un tenant senza montare un tool di assessment. Ogni script risponde a una sola domanda e lascia un CSV che si può allegare a un verbale o confrontare con la rilevazione precedente.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-AzStorageInventory.ps1` | Fotografia di tutti gli storage account: ridondanza (LRS/ZRS/GRS), kind, access tier e impostazioni di sicurezza di base (solo HTTPS, blob pubblici consentiti). | Sola lettura |
| `02-Get-AzStorageContainerPublicAccess.ps1` | Verifica container per container quali consentono accesso anonimo (`PublicAccess` Blob o Container), una delle cause più comuni di esposizione dati su Azure. | Sola lettura (serve accesso data-plane) |
| `03-Get-AzStorageNetworkRules.ps1` | Per ogni storage account: azione di default del firewall (Allow/Deny), accesso di rete pubblico e quante regole IP e VNet sono configurate. | Sola lettura |
| `04-Get-AzStorageWithoutLifecycle.ps1` | Elenca gli storage account privi di criterio di lifecycle management, dove i blob vecchi restano nel tier caldo e non vengono mai eliminati. | Sola lettura |
| `05-Get-AzSqlDatabaseInventory.ps1` | Elenca i SQL Server logici e i loro database con edizione, service objective, dimensione massima e stato (esclude `master`). | Sola lettura |
| `06-Get-AzSqlFirewallRules.ps1` | Elenca le regole firewall dei server logici e classifica il rischio: «Allow Azure services» (0.0.0.0) e l'intervallo aperto a tutti. | Sola lettura |
| `07-Get-AzSqlSecurity.ps1` | Stato della Transparent Data Encryption database per database e stato dell'auditing a livello di server. | Sola lettura |
| `08-Get-AzStorageCapacity.ps1` | Spazio occupato da ogni storage account, letto dalla metrica `UsedCapacity`. | Sola lettura |
| `09-Get-AzSqlBackupRetention.ps1` | Giorni di retention dei backup a breve termine e policy di long-term retention (settimanale, mensile, annuale) per ogni database. | Sola lettura |
| `10-Get-AzSqlElasticPools.ps1` | Elenca gli elastic pool con edizione, capacità e numero di database contenuti. | Sola lettura |

Nessuno dei dieci script modifica il tenant: non contengono una sola chiamata diversa da un `Get-`. Per eseguirli non serve alcun permesso di scrittura.

## Prima di eseguirli

**PowerShell** 5.1 o PowerShell 7. Nessuno script dichiara `#Requires -Version`, quindi la versione non viene verificata all'avvio: su una versione non supportata l'errore arriva dal cmdlet, non dallo script.

**Moduli.** Ogni script dichiara i propri `#Requires -Modules` e si ferma se mancano.

```powershell
Install-Module Az -Scope CurrentUser
```

Oppure solo i quattro moduli effettivamente usati:

```powershell
Install-Module Az.Accounts, Az.Storage, Az.Sql, Az.Monitor -Scope CurrentUser
```

- `Az.Accounts` — tutti e dieci
- `Az.Storage` — 01, 02, 03, 04, 08
- `Az.Sql` — 05, 06, 07, 09, 10
- `Az.Monitor` — solo 08

**Autenticazione.** `Connect-AzAccount`. Se non trova un contesto Azure, ogni script lo invoca da sé e apre un login interattivo.

**Permessi.**

- ruolo **Reader** sulla subscription: otto script su dieci (01, 03, 04, 05, 06, 07, 09, 10)
- **02** richiede in più un ruolo data-plane sullo storage: **Storage Blob Data Reader**
- **08** richiede **Monitoring Reader** per leggere la metrica `UsedCapacity`
- il `.NOTES` di **07** cita «Reader/SQL Security Manager»: è sbagliato, vedi le avvertenze

## ⚠️ Avvertenze

1. **Uno zero di `02` non prova che non ci siano container pubblici.** Quando l'accesso data-plane viene negato su uno storage account, lo script emette un `Write-Warning` e passa al successivo; alla fine stampa comunque «0 container con accesso pubblico». Un errore di permessi e un tenant davvero pulito producono lo stesso messaggio rassicurante, proprio sullo script che serve a trovare i dati esposti. Prima di fidarti di quello zero, verifica che l'identità che esegue l'audit abbia Storage Blob Data Reader su **tutti** gli account, e conta i warning: uno zero senza il suo denominatore non dice nulla.

2. **Senza un contesto esplicito l'audit gira sulla subscription corrente, qualunque essa sia.** Nessuno dei dieci script accetta `-SubscriptionId` e nessuno chiama `Set-AzContext`: interrogano la subscription del contesto attivo. Il CSV prodotto non contiene né TenantId né SubscriptionId, quindi a posteriori non si sa a quale cliente si riferisce. Esegui `Get-AzContext` prima di partire, seleziona la subscription con `Set-AzContext` e passa `-OutputCsv` con il nome del cliente nel percorso. Nota anche che il `Connect-AzAccount` automatico apre un login interattivo: così come sono, questi script non si possono pianificare.

3. **`04` segnala come «ASSENTE» anche una lifecycle policy che esiste ma non è leggibile.** Il `catch` converte qualunque eccezione — compreso un 403/AuthorizationFailed su `Get-AzStorageAccountManagementPolicy` — in «policy assente», e lo storage account finisce nel CSV con `Lifecycle = ASSENTE`. Il report costi propone così interventi su risorse già a norma. Prima di agire su una riga, verifica la policy sul portale oppure ripeti l'esecuzione con un'identità che abbia Reader su quel resource group.

4. **Non usare la chiave dello storage account per eseguire `02`.** L'help dello script e il vecchio LEGGIMI la presentano come alternativa per l'accesso data-plane, e il messaggio a runtime la ripropone. La chiave dà pieno accesso in lettura **e in scrittura** a tutti i dati dell'account: è la credenziale più ampia che esista, maneggiata in chiaro, per un controllo di sola lettura. Assegna invece il ruolo RBAC Storage Blob Data Reader all'identità che esegue l'audit e lascia stare le chiavi.

5. **`07` chiede più permessi di quelli che usa.** Il suo `.NOTES` indica «Reader/SQL Security Manager», ma SQL Security Manager è un ruolo di **scrittura**: consente di modificare auditing, policy di sicurezza, regole firewall e impostazioni TDE. Lo script esegue solo `Get-AzSqlServerAudit` e `Get-AzSqlDatabaseTransparentDataEncryption`, entrambi coperti dal solo Reader. Chi segue quella nota concede permessi di scrittura sul SQL del cliente per produrre un report di sola lettura: chiedi Reader e nient'altro.

6. **Una colonna di soli «n/d» in `08` è quasi sempre un errore, non un dato.** Il `catch` attorno a `Get-AzMetric` è vuoto: qualsiasi fallimento — Monitoring Reader mancante, metrica non ancora popolata, risorsa non supportata — produce `UsataGB = 'n/d'` senza alcun messaggio. Se vedi «n/d», controlla il ruolo Monitoring Reader prima di concludere che lo storage è vuoto; tieni presente che la metrica `UsedCapacity` viene aggiornata circa una volta al giorno, quindi un account appena creato può legittimamente non averla ancora.

## Dove finiscono i file

Tutti e dieci gli script esportano un CSV. Il percorso è parametrizzato (`-OutputCsv`), ma il valore di default è **relativo alla directory corrente** e il nome contiene solo la data: `.\Az-StorageInventory-<data>.csv`, `.\Az-SqlSecurity-<data>.csv` e così via. Due conseguenze:

- **Il file nasce dove si trova il prompt.** Se hai clonato il repository e lanci gli script da lì, il CSV finisce dentro il clone. Il `.gitignore` della radice esclude i `*.csv`, ma non fidarti di quella rete: passa sempre `-OutputCsv` verso una cartella che hai scelto tu.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente, in silenzio.** `Export-Csv` è invocato senza `-NoClobber` e senza `-Confirm`. Se vuoi conservare un confronto, cambia percorso a ogni passaggio.

Il contenuto non è innocuo: nomi degli storage account, nomi dei SQL Server logici, regole firewall con gli intervalli IP ammessi a raggiungere i database, stato della cifratura TDE e dell'auditing, container aperti al pubblico, retention dei backup. Messi insieme sono la mappa dei punti deboli dell'infrastruttura del cliente. Trattali come documento riservato, non lasciarli in una cartella sincronizzata o di rete se non è quello che vuoi, e cancellali quando l'assessment è chiuso.

Un CSV vuoto o assente non è di per sé una buona notizia: solo `10` protegge l'esportazione con un controllo sui risultati e, se non trova nulla, lo scrive a schermo. Gli altri nove passano il risultato direttamente a `Export-Csv`: con zero righe ottieni un file vuoto senza spiegazioni, indistinguibile da un'esecuzione fallita.

## Esempi

```powershell
# Autenticazione: una volta per sessione
Connect-AzAccount

# Inventario degli storage account
.\01-Get-AzStorageInventory.ps1

# Inventario dei database SQL
.\05-Get-AzSqlDatabaseInventory.ps1

# Container blob con accesso anonimo, CSV in una cartella scelta
.\02-Get-AzStorageContainerPublicAccess.ps1 -OutputCsv 'C:\Audit\subscription-produzione\container-pubblici.csv'
```

## Download e supporto

Lo stesso contenuto è scaricabile come ZIP dalla pagina [synsphere.it/download/toolkit-powershell-azure-storage-db](https://synsphere.it/download/toolkit-powershell-azure-storage-db/). Se ti serve una mano a leggere i risultati o a rimettere a posto quello che emerge, scrivici da [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
