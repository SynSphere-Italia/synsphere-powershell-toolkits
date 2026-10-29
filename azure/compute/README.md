# Azure Compute & VM Toolkit

Dieci script PowerShell che fotografano un parco di macchine virtuali Azure da riga di comando: inventario VM e dischi, VM senza backup, dischi orfani, stato delle patch, più un comando di avvio/spegnimento in blocco.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

La raccolta è rivolta ad amministratori IT interni e a MSP che gestiscono sottoscrizioni Azure per conto di PMI. Nove script leggono la sottoscrizione corrente e scrivono un CSV; il decimo accende o dealloca VM in blocco.

Rispondono alle domande che dal portale richiedono molti clic e nessuna vista d'insieme: quali VM sono spente ma ancora allocate (e quindi ancora fatturate), quali non hanno backup, quali dischi restano in fattura senza servire a nessuna VM, quali VM sono in modalità patch manuale.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-AzVmInventory.ps1` | Inventario delle VM: nome, resource group, region, SKU, sistema operativo e power state. Base per capacity planning. | Sola lettura |
| `02-Get-AzVmRightsizing.ps1` | Estrae le raccomandazioni di costo di Azure Advisor sulle VM: quali ridimensionare o spegnere, con problema e soluzione proposta. | Sola lettura |
| `03-Get-AzVmPowerState.ps1` | Le VM non in esecuzione, distinguendo le "stopped" (spente ma allocate: il compute si paga ancora) dalle "deallocated" (si pagano solo i dischi). | Sola lettura |
| `04-Get-AzVmsWithoutBackup.ps1` | Confronta tutte le VM con quelle protette dai Recovery Services vault ed elenca quelle senza backup. | Sola lettura |
| `05-Get-AzDiskInventory.ps1` | Inventario dei managed disk: dimensione, SKU, stato, tipo di cifratura e VM associata. | Sola lettura |
| `06-Get-AzUnattachedDisks.ps1` | I dischi non collegati a nessuna VM, con dimensione, SKU e data di creazione, e il totale dei GB ancora in fattura. | Sola lettura |
| `07-Get-AzVmExtensions.ps1` | Le estensioni installate su ogni VM con publisher, tipo e versione. Attenzione: una VM le cui estensioni non sono leggibili compare come `(nessuna)`, indistinguibile da una VM che non ne ha. | Sola lettura |
| `08-Get-AzVmsWithoutAutoShutdown.ps1` | Le VM prive della pianificazione di spegnimento automatico (vedi avvertenza 6 sul perimetro del controllo). | Sola lettura |
| `09-Set-AzVmStartStop.ps1` | Avvia oppure spegne (deallocate) in blocco le VM di un resource group o con un certo tag. | **SCRIVE** |
| `10-Get-AzVmPatchStatus.ps1` | La modalità di gestione patch di ogni VM (AutomaticByPlatform, AutomaticByOS, Manual/ImageDefault) e, su Windows, gli aggiornamenti automatici. | Sola lettura |

## Prima di eseguirli

**PowerShell.** PowerShell 5.1 oppure PowerShell 7. Nessuno script impone una versione minima nel codice: la verifica è a carico di chi esegue.

**Moduli.** Il metamodulo Az copre tutto:

```powershell
Install-Module Az -Scope CurrentUser
```

Se preferisci installare solo i moduli effettivamente usati:

```powershell
Install-Module Az.Accounts, Az.Compute, Az.Advisor, Az.RecoveryServices, Az.Resources -Scope CurrentUser
```

`Az.Accounts` serve a tutti e dieci; `Az.Compute` a tutti tranne il 02; `Az.Advisor` solo al 02; `Az.RecoveryServices` solo al 04; `Az.Resources` solo al 08.

**Autenticazione.** `Connect-AzAccount`. Ogni script apre la finestra di accesso solo se non trova un contesto già attivo nella sessione.

**Permessi.**

- **Reader** a livello di sottoscrizione per i nove report: è sufficiente e minimo per i cmdlet che usano.
- **Backup Reader** in aggiunta a Reader per il 04, che legge i Recovery Services vault.
- Per il 09 bastano tre azioni: `Microsoft.Compute/virtualMachines/read`, `/start/action`, `/deallocate/action`. Un ruolo personalizzato con queste tre è la strada consigliata. Il ruolo predefinito **Virtual Machine Contributor** funziona, ma è più ampio: concede anche la cancellazione delle VM e la gestione dei dischi e delle NIC associate.

## ⚠️ Avvertenze

1. **`09-Set-AzVmStartStop.ps1` senza `-ResourceGroupName` agisce su TUTTE le VM della sottoscrizione corrente, e per impostazione predefinita non chiede conferma.** Solo `-Action` è obbligatorio: lo scoping è opzionale. Lo script dichiara `SupportsShouldProcess` ma non alza `ConfirmImpact`, quindi il prompt non compare a meno di passare `-Confirm` esplicitamente; in più `Stop-AzVM` viene chiamato con `-Force`, che sopprime la sua conferma nativa. Lo Stop è un deallocate, quindi non distrugge dati, ma interrompe il servizio su tutte le VM selezionate. Esegui sempre prima con `-WhatIf`, e aggiungi `-Confirm` quando vuoi il prompt per ogni VM.

2. **`-TagName` senza `-TagValue` seleziona le VM che NON hanno quel tag: l'opposto dell'intenzione, senza nessun avviso.** Il filtro si attiva alla sola presenza di `-TagName` e confronta il valore del tag con `$TagValue`, che se non è stato passato vale `$null`. Unito al punto 1 il perimetro diventa "tutte le VM della sottoscrizione prive di quel tag". Passa sempre i due parametri in coppia.

3. **Nessuno script fissa la sottoscrizione: lavorano su quella corrente nella sessione.** In tutti e dieci non c'è `Set-AzContext`, `Select-AzSubscription` né un parametro `-SubscriptionId`. Su un tenant con più sottoscrizioni i report risultano parziali in silenzio, e per il 09 il bersaglio dipende da uno stato di sessione che non si vede nel comando digitato. Controlla `Get-AzContext` prima di ogni esecuzione, e in particolare prima del 09.

4. **Il 04 confronta le VM per NOME, non per resource ID: due VM omonime in resource group diversi si coprono a vicenda.** Se `vm-sql01` nel resource group A è sotto backup, la `vm-sql01` del resource group B risulta protetta pur non essendolo, e non compare nel report. È il verso pericoloso dell'errore, perché una VM realmente senza backup non viene segnalata. Se nel parco ci sono nomi ripetuti, verifica quelle VM a mano.

5. **Sempre nel 04, se la lettura di un vault fallisce l'errore non si vede e OGNI VM risulta `Backup = 'ASSENTE'`.** L'eccezione di `Get-AzRecoveryServicesBackupItem` finisce in un catch vuoto: se manca il permesso Backup Reader, se i vault stanno in un'altra sottoscrizione o se la chiamata viene limitata, l'elenco delle VM protette resta vuoto, lo script esce senza errori e il CSV dichiara l'intero parco senza backup. Un report in cui *tutte* le VM risultano scoperte va letto come probabile difetto di permessi, non come esito: il numero delle VM senza backup non significa niente senza il numero dei vault che sono stati letti davvero. Verificane almeno uno nel portale prima di dare per buono il CSV.

6. **Il 08 riconosce solo l'auto-shutdown nativo di DevTestLab.** Cerca le risorse `Microsoft.DevTestLab/schedules` con nome `shutdown-computevm-<vm>`: uno spegnimento pianificato realizzato con un Automation Account, con Azure Policy o con *start/stop VMs during off-hours* non viene visto, e quelle VM compaiono come `AutoShutdown ASSENTE` pur essendo gestite. Anche qui il confronto è per nome, quindi VM omonime in resource group diversi si coprono a vicenda.

## Dove finiscono i file

I nove report accettano `-OutputCsv`, il cui default è un percorso **relativo alla directory corrente**, per esempio `.\Az-VmInventory-20261029.csv`. Due conseguenze da tenere a mente:

- **Il file nasce dove si trova il prompt**, non accanto allo script. Se hai clonato questo repository e lanci gli script da qui, il CSV finisce dentro il clone. Il `.gitignore` nella radice esclude `*.csv`, ma non fidarti dell'automatismo: controlla `git status` prima di committare, e sposta i report fuori dal clone se lavori su un tenant di un cliente.
- **Il nome contiene solo la data**, non l'ora: una seconda esecuzione nello stesso giorno sovrascrive il CSV precedente senza chiedere niente. Nessuno script verifica se il file esiste già. Se vuoi conservare le due versioni, passa `-OutputCsv` con un nome tuo.

I CSV di questa raccolta non contengono dati personali: sono nomi di risorse, dimensioni, SKU e stati. Contengono però la mappa dei punti deboli del parco — quali VM sono senza backup (04), quali senza spegnimento pianificato (08), quali in modalità patch manuale (10) — quindi trattali come documentazione infrastrutturale riservata e non lasciarli su condivisioni aperte.

## Esempi

```powershell
# Accesso (una volta per sessione) e verifica della sottoscrizione attiva
Connect-AzAccount
Get-AzContext

# Inventario completo delle VM
.\01-Get-AzVmInventory.ps1

# VM non protette da backup
.\04-Get-AzVmsWithoutBackup.ps1

# Spegnimento in blocco di un resource group: prima in simulazione
.\09-Set-AzVmStartStop.ps1 -Action Stop -ResourceGroupName rg-devtest -WhatIf

# Avvio delle VM con tag Environment=Dev (i due parametri sempre in coppia)
.\09-Set-AzVmStartStop.ps1 -Action Start -TagName Environment -TagValue Dev
```

## Download e supporto

Lo stesso contenuto si scarica come ZIP dalla pagina [synsphere.it/download/toolkit-powershell-azure-compute/](https://synsphere.it/download/toolkit-powershell-azure-compute/).

Se ti serve aiuto sull'uso o sulla gestione delle VM Azure: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
