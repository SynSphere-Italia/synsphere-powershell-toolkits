# Monitoring e operations su Azure

Dieci script PowerShell di sola lettura che fotografano lo stato di monitoring, alert, backup e diagnostica di una subscription Azure, ed esportano ogni report in CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Serve a chi amministra Azure dall'interno e a chi lo fa per conto di altri (MSP), quando deve rispondere in fretta a una domanda sola: su questa subscription, che cosa è monitorato e che cosa no.

Regole di alert, Action Group, workspace Log Analytics, diagnostic settings, autoscale e backup si configurano in punti diversi del portale, e nessuna schermata li mostra insieme: il pezzo che manca si scopre durante l'incidente. Ciascuno dei dieci script legge una di quelle superfici, senza modificare niente, e lascia il risultato in un CSV che si filtra o si allega a un verbale.

## Script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Export-AzActivityLog.ps1` | Activity Log degli ultimi N giorni: le operazioni di gestione (create, update, delete, azioni amministrative) con chi le ha eseguite, quando, su quale risorsa e con quale esito. L'Activity Log copre circa 90 giorni, oltre non si va. | Sola lettura |
| `02-Get-AzAlertRules.ps1` | Inventario delle regole di alert — metric alert e scheduled query alert — con la risorsa su cui vigilano, la severità e se sono abilitate: serve a capire cosa è monitorato e cosa no. | Sola lettura |
| `03-Get-AzActionGroups.ps1` | Action Group, cioè chi viene avvisato quando un alert scatta: nome breve, stato, e quanti destinatari email, SMS e webhook ha ciascuno. Se non ce n'è nessuno, gli alert non notificano nessuno. | Sola lettura |
| `04-Get-AzLogAnalyticsWorkspaces.ps1` | Workspace Log Analytics con SKU, giorni di retention e region: la retention lunga è un costo, i workspace duplicati sono telemetria sparsa in più posti. | Sola lettura |
| `05-Get-AzBackupJobStatus.ps1` | Job di backup recenti di ogni Recovery Services vault, con esito, inizio e durata, e il conteggio dei falliti. Un backup configurato ma fallito è peggio di nessun backup, perché dà falsa sicurezza. | Sola lettura |
| `06-Get-AzVmMetricSnapshot.ps1` | Utilizzo CPU di ogni VM nel periodo, con taglia e resource group: è pensato come base oggettiva per decidere il rightsizing. Solo le VM accese producono metriche. Leggi l'avvertenza 1 prima di usare la colonna del picco. | Sola lettura |
| `07-Get-AzAutoscaleSettings.ps1` | Impostazioni di autoscale con la risorsa target, se sono abilitate e quanti profili hanno: per verificare che cosa adatta davvero la capacità al carico e cosa invece resta fisso. | Sola lettura |
| `08-Get-AzDiagnosticSettingsReport.ps1` | Per le risorse che le hanno, le diagnostic settings e dove mandano i log (Log Analytics, Storage, Event Hub). Interroga una risorsa per volta, quindi su tenant grandi può metterci tempo; `-ResourceTypeLike` restringe il perimetro a un tipo. | Sola lettura |
| `09-Get-AzActivityLogAlerts.ps1` | Activity Log alert, comprese le notifiche di Service Health (incident Azure e manutenzioni programmate), con scope e stato. | Sola lettura |
| `10-Get-AzOperationalRecommendations.ps1` | Raccomandazioni di Azure Advisor nelle categorie eccellenza operativa e alta affidabilità, con impatto, problema e soluzione proposta: un backlog di miglioramento operativo già scritto. | Sola lettura |

Dieci su dieci sono di sola lettura: tutti i cmdlet Azure che compaiono nel codice sono `Get-Az*`, oltre a `Connect-AzAccount` per l'autenticazione, e non c'è nessun cmdlet con verbo `New-`, `Set-`, `Add-`, `Remove-` o equivalente. Non c'è quindi niente da confermare e `-WhatIf` non è previsto. Tutti e dieci, però, scrivono un file CSV su disco: vedi [Dove finiscono i file](#dove-finiscono-i-file).

## Prima di eseguirli

**PowerShell** 5.1 oppure PowerShell 7. Nessuno dei dieci script dichiara `#Requires -Version`: il controllo non è automatico.

**Moduli.** Ogni script dichiara i propri in `#Requires -Modules`, quindi un modulo mancante ferma l'esecuzione subito, prima di collegarsi:

```powershell
Install-Module Az.Accounts -Scope CurrentUser             # tutti e dieci
Install-Module Az.Monitor -Scope CurrentUser              # script 01, 02, 03, 06, 07, 08, 09
Install-Module Az.OperationalInsights -Scope CurrentUser  # script 04
Install-Module Az.RecoveryServices -Scope CurrentUser     # script 05
Install-Module Az.Compute -Scope CurrentUser              # script 06
Install-Module Az.Resources -Scope CurrentUser            # script 08
Install-Module Az.Advisor -Scope CurrentUser              # script 10
```

In alternativa il modulo cumulativo `Install-Module Az -Scope CurrentUser`, che però scarica l'intero set; verifica poi con `Get-Module -ListAvailable Az.*` che quelli dell'elenco ci siano tutti.

**Autenticazione.** `Connect-AzAccount`, una volta per sessione. Ogni script la invoca da sé se non trova già un contesto aperto.

**Permessi.** Il ruolo **Reader** sulla subscription basta per otto script su dieci. Fanno eccezione:

- `05-Get-AzBackupJobStatus.ps1`: ruolo **Backup Reader**;
- `06-Get-AzVmMetricSnapshot.ps1`: Reader per l'elenco delle VM e **Monitoring Reader** per la lettura delle metriche, come indica il suo help.

Nessuno script chiede permessi su Microsoft Graph: non c'è nessun `Connect-MgGraph` e nessuno scope da far approvare a un amministratore. I ruoli richiesti sono il minimo necessario per cmdlet di sola lettura.

## ⚠️ Avvertenze

Due regole valgono per tutti i punti che seguono. Un report vuoto, o tutto a zero, non è una buona notizia finché non hai verificato di aver avuto i permessi per leggere tutto quello che lo script ha interrogato: un numero senza il suo denominatore inganna. E il perimetro di ogni report è una sola subscription, anche quando il tenant ne ha dodici.

1. **`06-Get-AzVmMetricSnapshot.ps1`: la colonna `CPUPiccoPct` non è il picco.** Lo script chiede ad Azure Monitor la sola aggregazione `Average` con granularità di un'ora, e poi prende il massimo di quelle medie orarie: il valore in colonna è la media oraria più alta, non il massimo rilevato. Una VM che gira al 100% per cinque minuti in un'ora altrimenti scarica viene riportata intorno al 10%. L'errore è nella direzione che costa: sottostima gli spike, e lo scopo dichiarato dello script è il rightsizing, quindi spinge a ridurre la taglia proprio alle VM che i picchi li hanno. Non decidere un ridimensionamento su questa colonna. Leggi `CPUMediaPct` per quello che è, una media, e verifica i picchi veri sulla metrica `Percentage CPU` con aggregazione Max, dal portale o chiedendo `-AggregationType Maximum` a `Get-AzMetric`.

2. **Ogni report copre una sola subscription, e non lo dice da nessuna parte.** Nessuno dei dieci script accetta `-SubscriptionId` e nessuno itera su `Get-AzSubscription`: il perimetro è sempre la subscription del contesto corrente. Su un tenant con più subscription ottieni l'inventario di una sola, e il messaggio finale resta verde — l'omissione non produce nessun errore, quindi «nessun alert configurato» in realtà significa «nessun alert in questa subscription». Prima di lanciare, guarda dove sei con `Get-AzContext`; per coprire tutto, cicla a mano con `Set-AzContext -Subscription <id>` e tieni i CSV separati, perché il nome predefinito non contiene la subscription e il secondo giro sovrascriverebbe il primo.

3. **Il CSV dell'Activity Log è un elenco nominativo di attività lavorative.** La colonna `Caller` di `01-Export-AzActivityLog.ps1` contiene l'identità — UPN o indirizzo email — della persona che ha eseguito ogni singola operazione, con data, ora e risorsa. Il file che resta sul disco è un dato personale a tutti gli effetti, in chiaro, e la finalità è un audit: conservalo per il tempo dell'analisi e non oltre, scrivilo in un percorso ad accesso limitato, non allegarlo a un ticket o a una email. Se devi condividere il risultato, togli o sostituisci la colonna `Caller` prima di passarlo a qualcuno.

4. **L'help di `01-Export-AzActivityLog.ps1` promette un filtro che nel codice non c'è.** La `.DESCRIPTION` dichiara che lo script esporta «filtrando le operazioni riuscite»: non è così, nessun filtro viene applicato. Il CSV contiene tutte le operazioni, riuscite e fallite, e l'esito sta nella colonna `Stato`. Chi legge l'help in un contesto di audit crede che i fallimenti siano già stati esclusi, e conta come riuscito quello che non lo è — per esempio una cancellazione tentata e respinta. Filtra tu sulla colonna `Stato` secondo cosa ti serve dimostrare.

5. **In `08` e in `06` gli errori per singola risorsa vengono ignorati in silenzio, e uno zero non si distingue da un fallimento.** `08-Get-AzDiagnosticSettingsReport.ps1` enumera tutte le risorse della subscription e interroga le diagnostic settings una per una dentro un `catch` vuoto: se su una classe di risorse ti mancano i permessi, o se quel tipo di risorsa non supporta le diagnostic settings, il risultato è identico a «nessuna diagnostica configurata», e il conteggio finale viene stampato comunque in verde come un successo. Lo stesso meccanismo in `06-Get-AzVmMetricSnapshot.ps1` fa apparire `n/d` sia per una VM spenta sia per una VM su cui la chiamata alle metriche è fallita. Confronta le righe del CSV con il numero di risorse esaminate — `(Get-AzResource).Count` — e se il report è vuoto o quasi, verifica i permessi prima di concludere che la diagnostica non c'è.

6. **In `05` e in `06` un `-Days` negativo produce un report vuoto senza nessun errore.** Il parametro è un `[int]` senza validazione: con un valore negativo la data di inizio finisce nel futuro, l'intervallo richiesto è vuoto, e lo script termina con il suo messaggio di successo e zero righe. Su `05` vuol dire «zero job di backup, zero falliti», che letto di fretta sembra una buona notizia. Passa sempre un numero positivo. `01-Export-AzActivityLog.ps1` è l'unico che si difende da sé, con un intervallo ammesso di 1-90 giorni allineato alla retention dell'Activity Log.

## Dove finiscono i file

Tutti e dieci gli script esportano un CSV. Il nome predefinito è relativo e contiene solo la data, non l'ora: `.\Az-<report>-<aaaammgg>.csv`.

- **Il file nasce dove si trova il prompt**, non dove sta lo script. Se hai clonato il repository e lanci dalla cartella clonata, il CSV nasce dentro il clone. Il `.gitignore` della radice esclude `*.csv`, ma non fidarti: guarda `git status` prima di committare.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente senza chiedere niente**: il nome contiene la data e nessuno script usa `-NoClobber`. Se devi conservare i report, o confrontare due subscription, passa percorso e nome tuoi con `-OutputCsv`.
- **Il contenuto va trattato come dato del cliente.** Il CSV di `01` contiene identità di persone fisiche: vedi l'avvertenza 3. Gli altri nove non esportano identità — `03`, in particolare, riporta quanti destinatari ha un Action Group, non i loro indirizzi — ma descrivono l'infrastruttura: nomi e taglie delle VM, nomi dei vault e dei workspace, resource group, e soprattutto quali risorse non sono monitorate e dove i log vanno o non vanno. Scrivili fuori dal repository, in un percorso ad accesso limitato, e cancellali quando il report ha smesso di servire.

## Esempi

```powershell
# Autenticazione e verifica di dove sei (vedi avvertenza 2)
Connect-AzAccount
Get-AzContext

# Activity Log degli ultimi 30 giorni
.\01-Export-AzActivityLog.ps1 -Days 30

# Job di backup delle ultime due settimane
.\05-Get-AzBackupJobStatus.ps1 -Days 14

# Snapshot CPU delle VM su 14 giorni (la colonna del picco: avvertenza 1)
.\06-Get-AzVmMetricSnapshot.ps1 -Days 14

# Diagnostic settings delle sole risorse di rete
.\08-Get-AzDiagnosticSettingsReport.ps1 -ResourceTypeLike '*Microsoft.Network*'
```

---

Gli stessi script si scaricano come ZIP da [synsphere.it/download/toolkit-powershell-azure-monitoring](https://synsphere.it/download/toolkit-powershell-azure-monitoring/). Se ti serve una mano a leggere un report, o a far sì che gli alert e i backup avvisino qualcuno davvero, scrivici da [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
