# Analisi e ottimizzazione dei costi Azure

Dieci script PowerShell di sola lettura che mostrano dove va la spesa Azure di una subscription, che cosa si può tagliare subito e dove sta andando il mese in corso: ognuno esporta un CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

La raccolta è rivolta ad amministratori IT, MSP e responsabili FinOps di piccole e medie imprese che hanno un ruolo di sola lettura su Azure (Cost Management Reader, Billing Reader o Reader) e vogliono i numeri in un CSV invece di navigare il portale.

Risponde a tre domande in sequenza: dove vanno i soldi (costo per resource group, per servizio, per singola risorsa, trend mensile), che cosa si può tagliare subito (dischi gestiti non collegati, IP pubblici non associati, dischi di VM deallocate, raccomandazioni di Azure Advisor) e dove si sta andando (stato dei budget, aumenti rispetto al mese precedente, proiezione di fine mese).

Ogni script è autonomo, prende i suoi parametri da riga di comando e lavora sulla subscription attiva nel contesto di `Connect-AzAccount`.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-AzCostByResourceGroup.ps1` | Somma il costo pre-tasse del periodo per resource group, ricavando il gruppo dall'`InstanceId` del consumo: la prima vista per capire dove vanno i soldi. Periodo predefinito dal primo giorno del mese corrente a oggi (`-StartDate`, `-EndDate`). | Sola lettura |
| `02-Get-AzCostByService.ps1` | Lo stesso consumo aggregato per servizio consumato (`ConsumedService`): quali servizi pesano di più sulla bolletta. Mostra a schermo le prime otto righe. | Sola lettura |
| `03-Get-AzCostTrend.ps1` | Andamento mensile della spesa sugli ultimi N mesi (`-Months`, predefinito 6), raggruppato per mese di consumo: serve a vedere se i costi crescono e di quanto. | Sola lettura |
| `04-Get-AzTopCostResources.ps1` | Classifica le singole risorse per costo del periodo e tiene le prime N (`-Top`, predefinito 25), con il loro resource group: individua i big spender su cui concentrare l'ottimizzazione. | Sola lettura |
| `05-Get-AzIdleCostlyResources.ps1` | Risorse che costano senza essere usate: dischi gestiti non collegati e indirizzi IP pubblici non associati, con dimensione, SKU, allocazione e location. È un elenco di candidati, vedi l'avvertenza 1. | Sola lettura |
| `06-Get-AzDeallocatedVmDiskCost.ps1` | Le VM in stato deallocato con i loro dischi gestiti, di sistema e dati, dimensione e SKU: una VM deallocata non paga il compute ma continua a pagare i dischi. | Sola lettura |
| `07-Get-AzCostAdvisorRecommendations.ps1` | Le raccomandazioni di Azure Advisor di categoria Cost (rightsizing e spegnimento di VM sottoutilizzate, reserved instance e altro), con impatto, problema, soluzione e risorsa interessata. | Sola lettura |
| `08-Get-AzBudgetStatus.ps1` | I budget configurati sulla subscription con limite, spesa corrente, percentuale di utilizzo, periodo (`TimeGrain`) e valuta: per sapere a colpo d'occhio se stai per sforare. | Sola lettura |
| `09-Get-AzCostAnomalies.ps1` | Confronta la spesa per servizio dall'inizio del mese con lo stesso numero di giorni del mese precedente e segnala gli aumenti oltre la soglia (`-ThresholdPercent`, predefinito 30). | Sola lettura |
| `10-Get-AzCostForecast.ps1` | Spesa dall'inizio del mese e proiezione a fine mese ottenuta dalla media giornaliera, con giorni trascorsi e valuta. L'header dichiara che la stima è lineare e non considera stagionalità o picchi. | Sola lettura |

«Sola lettura» qui è una misura, non una promessa. Sui dieci script non compare un solo cmdlet con verbo `Remove`, `Set`, `New`, `Update`, `Disable`, `Stop`, `Restart`, `Revoke`, `Reset`, `Clear`, `Add` o `Invoke`: tutti i cmdlet Azure usati sono `Get-*`, e gli unici verbi non di lettura in tutta la raccolta sono `Connect-AzAccount` per il login ed `Export-Csv` per scrivere il report. Nessuno script ha bisogno di `-WhatIf` perché nel tenant non c'è niente da proteggere. Il rischio di questa raccolta sta altrove: in ciò che i report ti fanno credere, e in dove finiscono i file.

## Prima di eseguirli

**PowerShell.** PowerShell 5.1 oppure PowerShell 7. Nessuno dei dieci script contiene `#Requires -Version`, quindi il requisito non viene verificato all'avvio: la versione indicata è quella del file di istruzioni che accompagnava la raccolta.

**Moduli.**

```powershell
Install-Module Az -Scope CurrentUser
```

Il meta-modulo `Az` è la via breve e copre tutto. Se preferisci installare solo quello che serve, i `#Requires` degli script dichiarano cinque moduli: `Az.Accounts` (tutti e dieci), `Az.Billing` (`01`, `02`, `03`, `04`, `09`, `10`: è il modulo che esporta `Get-AzConsumptionUsageDetail` e `Get-AzConsumptionBudget`), `Az.Compute` (`05`, `06`), `Az.Network` (`05`), `Az.Advisor` (`07`).

```powershell
Install-Module Az.Accounts, Az.Billing, Az.Compute, Az.Network, Az.Advisor -Scope CurrentUser
```

**Una dipendenza è dichiarata male, e lo diciamo noi.** `08` apre con `#Requires -Modules Az.Accounts, Az.Consumption`, ma `Az.Consumption` non esiste come modulo installabile: il cmdlet che quello script usa, `Get-AzConsumptionBudget`, è esportato da `Az.Billing` (verificato con `Get-Command`). Dove `Az.Consumption` non è presente, `08` non parte affatto, perché `#Requires` blocca lo script prima della prima riga di codice. Se vedi quell'errore di modulo mancante non è il tuo ambiente: è la riga `#Requires` da correggere.

**Ruoli Azure.** Cost Management Reader, oppure Billing Reader, per i dati di consumo (`01`, `02`, `03`, `04`, `09`); Cost Management Reader per budget e forecast (`08`, `10`); ruolo Reader sulla subscription per l'inventario di dischi, IP e VM (`05`, `06`) e per Azure Advisor (`07`). Nessuno script chiede un ruolo con privilegi di scrittura: su tutta la raccolta non c'è nessun riferimento a Contributor, Owner o Administrator.

**Microsoft Graph: nessun permesso.** Il toolkit non usa Graph. Non c'è `Connect-MgGraph`, non ci sono scope da far approvare e non c'è nessun consenso applicativo da concedere in Entra ID.

**Autenticazione.** `Connect-AzAccount` prima di eseguire. È l'autenticazione interattiva del modulo `Az`, con MFA se il tenant la richiede; nessuno script contiene credenziali, client secret o certificati.

**Tipo di sottoscrizione.** I dati di consumo arrivano da `Get-AzConsumptionUsageDetail`, supportato sulle sottoscrizioni PAYG, EA e MCA con alcuni limiti; su tenant molto grandi le query possono richiedere tempo.

## ⚠️ Avvertenze

1. **`05` produce un elenco di candidati, non di risorse da cancellare.** Il filtro sui dischi è `DiskState -eq 'Unattached' -or -not $_.ManagedBy`: quell'`-or` rende l'insieme più largo del solo stato `Unattached`. Un disco che non è in stato `Unattached` ma ha `ManagedBy` vuoto viene comunque etichettato «Disco non collegato», ed è il caso dei dischi condivisi (con `maxShares` maggiore di 1 le VM che li usano stanno in `ManagedByExtended`) e dei dischi esposti via SAS o con un lease attivo. Il CSV non riporta né `DiskState` né `ManagedByExtended`, quindi il falso positivo non è visibile nel report, e il messaggio finale chiude con «Valuta l'eliminazione». Lo script non cancella nulla, ma la cancellazione di un disco non si annulla: verifica ogni riga nel portale prima di eliminare. Vale anche per gli IP pubblici, dove il filtro è la sola assenza di `IpConfiguration`, senza distinguere SKU né metodo di allocazione, mentre l'header dello script parla di IP Standard: leggi la colonna `Dettaglio` prima di trattare una riga come spesa recuperabile.

2. **L'ambito è una sola subscription, e nessun report lo dice.** Ogni script lavora sul contesto corrente e nessuno dei dieci cicla sulle subscription né stampa quale ha interrogato. Su un tenant con più subscription il CSV copre solo quella attiva, ma non c'è niente nell'output che lo segnali: «3 risorse idle» si legge come il totale del tenant mentre è il totale di una subscription. Seleziona l'ambito prima di eseguire, con `Set-AzContext -Subscription <nome-o-id>`, e se le subscription sono più di una fai il ciclo tu, mettendo l'identificativo nel nome del file:

   ```powershell
   foreach ($s in Get-AzSubscription) {
       Set-AzContext -Subscription $s.Id | Out-Null
       .\01-Get-AzCostByResourceGroup.ps1 -OutputCsv ".\Az-CostByRG-$($s.Id)-$(Get-Date -Format 'yyyyMMdd').csv"
   }
   ```

3. **I CSV sono una mappa dell'infrastruttura del cliente.** I report contengono nomi di risorse, resource group, location, nomi di VM e di dischi con SKU e dimensione, i `ResourceId` delle raccomandazioni Advisor e gli importi di spesa. Per chi li riceve sono l'inventario di un ambiente e il suo profilo di spesa: non allegarli a un ticket, non spedirli senza cifratura, non lasciarli in cartelle condivise. C'è anche un effetto operativo: `05` chiama `Get-AzDisk` e `Get-AzPublicIpAddress` senza `-ResourceGroupName`, e `06` chiama `Get-AzVM -Status`, cioè una query di stato per ogni VM. Entrambi enumerano l'intera subscription e su ambienti grandi possono richiedere minuti ed essere rallentati dal throttling delle API.

4. **L'auto-login apre una finestra interattiva.** Tutti e dieci gli script iniziano con `if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }`: in esecuzione non interattiva, come un job pianificato o una pipeline, lo script resta in attesa di un login che nessuno farà invece di uscire subito con un errore chiaro, e quell'`| Out-Null` scarta anche l'esito del login. Sono pensati per l'uso interattivo: per automatizzarli autentica prima una service principal con `Connect-AzAccount -ServicePrincipal` e verifica tu `Get-AzContext` nello script che li richiama.

5. **In `08` un esito vuoto non prova niente, e la prima riga non è il budget più a rischio.** Se `Get-AzConsumptionBudget` non restituisce nulla, lo script stampa «Nessun budget configurato sulla subscription» ed esce senza scrivere il CSV: quel messaggio significa «nessun budget visibile sulla subscription del contesto, con il ruolo che hai», non «nessun budget nel tenant». Prima di concludere che non ci sono controlli di spesa, verifica il ruolo e l'ambito dell'avvertenza 2. Nello stesso report la colonna `Percent` è una stringa (`"95%"`) e l'ordinamento è testuale, non numerico: un budget al 100% finisce sotto uno al 95%. Non fermarti alla prima riga, riordina le righe sul rapporto fra speso e limite.

6. **In `09` e `10` ci sono numeri che non sono misure.** `09` assegna `999%` ai servizi che il mese precedente non avevano spesa confrontabile: è un segnaposto per «nessun termine di confronto», non una variazione calcolata. Lo stesso script segnala solo gli aumenti che superano sia la soglia percentuale sia un'unità di valuta in valore assoluto, e scorre i soli servizi del mese in corso, quindi un servizio in calo o scomparso non compare: il report risponde a «che cosa è cresciuto», non a «che cosa è cambiato». Il forecast di `10` è la media giornaliera del mese in corso moltiplicata per i giorni del mese, come dichiara il suo header: un picco nei primi giorni gonfia la proiezione per tutto il resto del mese. Usa questi due come segnale per andare a guardare, non come dato da girare a terzi.

Una cosa che non è un rischio, e vale saperla: nessuno dei dieci script ha un `try/catch`, e tutti impostano `$ErrorActionPreference = 'Stop'`. Un permesso mancante o una chiamata rifiutata interrompono l'esecuzione mostrando l'errore di Azure, invece di produrre un report a metà. Il caso insidioso non è l'errore: è l'esito legittimamente vuoto dell'avvertenza 5.

## Dove finiscono i file

Tutti e dieci gli script dichiarano un parametro `-OutputCsv` e il suo valore predefinito è un percorso relativo, `.\Az-<nome>-<yyyyMMdd>.csv`. Non ci sono percorsi assoluti nella raccolta, e nessuno script usa `Out-File`, `Set-Content` o `New-Item`: l'unica scrittura su disco è l'`Export-Csv` del report.

Due conseguenze da tenere a mente. Il file nasce nella directory in cui si trova il prompt, non accanto allo script: se hai clonato questo repository e lanci da lì, il CSV finisce dentro il clone, e il `.gitignore` esclude `*.csv` ma guarda il `git status` prima di committare invece di fidarti. E il nome contiene solo la data, senza ora: una seconda esecuzione nello stesso giorno sovrascrive la precedente senza chiedere niente. Se devi conservare due esecuzioni, o distinguere due subscription, passa `-OutputCsv` con un percorso esplicito.

Il contenuto non comprende credenziali né elenchi di utenti, ma è materiale riservato del cliente: l'inventario delle risorse con i loro nomi, i resource group, le location, i dischi con SKU e dimensione, le VM, i `ResourceId` delle raccomandazioni Advisor, e gli importi di spesa in valuta, compresi i limiti dei budget e le proiezioni. Trattalo come tratteresti la fattura e lo schema infrastrutturale di quel cliente. L'unico script che può non produrre nessun file è `08`, quando non trova budget.

## Esempi

```powershell
# Costo del mese corrente per resource group
.\01-Get-AzCostByResourceGroup.ps1

# Trend della spesa sugli ultimi 12 mesi
.\03-Get-AzCostTrend.ps1 -Months 12

# Le 50 risorse più costose del periodo
.\04-Get-AzTopCostResources.ps1 -Top 50

# Servizi cresciuti almeno del 25% rispetto allo stesso numero di giorni del mese scorso
.\09-Get-AzCostAnomalies.ps1 -ThresholdPercent 25
```

## Download e supporto

Lo stesso contenuto è scaricabile come ZIP dalla pagina [synsphere.it/download/toolkit-powershell-azure-cost-management](https://synsphere.it/download/toolkit-powershell-azure-cost-management/). Se ti serve una mano a leggere i report, o a decidere che cosa si può spegnere davvero, scrivici da [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
