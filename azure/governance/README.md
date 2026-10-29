# Azure Governance & Resource Management Toolkit

Dieci script PowerShell che fotografano un ambiente Microsoft Azure — risorse, tag, resource group vuoti, lock, sprechi in fattura, chi ha creato cosa — ed esportano il risultato in CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Gli script interrogano Azure con il modulo Az e restituiscono in forma tabellare lo stato di una o più subscription: inventario completo delle risorse, risorse a cui mancano i tag obbligatori, resource group rimasti vuoti, resource lock in essere, dischi e indirizzi IP e schede di rete che restano in fattura senza essere collegati a nulla, distribuzione per region, timeline delle operazioni di scrittura dall'Activity Log. Sono rivolti ad amministratori IT e a MSP che devono fotografare un tenant Azure, allocare i costi per centro di costo e trovare gli sprechi senza installare nulla oltre al modulo Az. Nove script su dieci sono di sola lettura; uno solo scrive sul tenant, e scrive soltanto tag.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-AzResourceInventory.ps1` | Inventario completo: ogni risorsa con nome, tipo, resource group, region e tag, più la subscription di appartenenza. È la fotografia di base per governance, audit e capacity planning. Senza `-SubscriptionId` itera tutte le subscription accessibili. | Sola lettura |
| `02-Get-AzUntaggedResources.ps1` | Le risorse senza alcun tag oppure, con `-RequiredTags`, quelle a cui manca uno dei tag obbligatori indicati, nominando quali mancano. I tag sono la base di cost allocation, ownership e automazione. | Sola lettura |
| `03-Set-AzResourceTagsBulk.ps1` | Propaga un set di tag (per esempio CostCenter, Owner, Environment) a tutte le risorse di un resource group, in modalità merge: i tag esistenti con altre chiavi restano. Supporta `-WhatIf`. | **SCRIVE** (tag sulle risorse) |
| `04-Get-AzEmptyResourceGroups.ps1` | I resource group che non contengono alcuna risorsa, con region e provisioning state: residui di progetti chiusi o di deploy falliti, candidati alla dismissione. Li elenca, non cancella niente. | Sola lettura |
| `05-Get-AzResourceLocks.ps1` | Tutti i resource lock della subscription con livello (`CanNotDelete` o `ReadOnly`), note e ambito su cui sono applicati: dove le risorse sono protette da cancellazioni e modifiche accidentali, e per differenza dove non lo sono. | Sola lettura |
| `06-Get-AzOrphanedResources.ps1` | Le risorse orfane che restano in fattura senza dare valore: dischi managed non collegati, IP pubblici senza associazione, NIC non collegate a una VM, NSG non associati a subnet o NIC. | Sola lettura |
| `07-Get-AzResourcesByRegion.ps1` | Quante risorse hai in ogni region, con i tre tipi più numerosi in ciascuna: utile per data residency, latenza e per individuare risorse sparse in region non previste. | Sola lettura |
| `08-Get-AzResourceCreationTimeline.ps1` | Dalle operazioni di scrittura riuscite dell'Activity Log: data, autore (`Caller`), operazione e resource id. Chi ha creato o modificato cosa, e quando. Finestra `-Days`, massimo 90, perché l'Activity Log copre circa 90 giorni. | Sola lettura |
| `09-Get-AzSubscriptionSummary.ps1` | Per ogni subscription accessibile: stato, numero di risorse, di resource group e di region. Vista d'insieme per orientarsi nei tenant con molte subscription. | Sola lettura |
| `10-Export-AzResourceGraph.ps1` | Export di nome, tipo, region, resource group, subscription e tag con una sola query KQL ad Azure Resource Graph, con paginazione automatica: su tenant grandi è molto più veloce di `Get-AzResource`. | Sola lettura |

## Prima di eseguirli

**PowerShell.** PowerShell 5.1 (quello preinstallato su Windows) oppure PowerShell 7. Nessuno dei dieci script dichiara una versione minima con `#Requires -Version`: il prerequisito è dichiarato dalla raccolta, non imposto dal codice.

**Moduli.**

```powershell
Install-Module Az -Scope CurrentUser
Install-Module Az.ResourceGraph -Scope CurrentUser   # solo per lo script 10
```

Il rollup `Az` copre i moduli dichiarati in testa agli script: `Az.Accounts` (tutti e dieci), `Az.Resources` (01, 02, 03, 04, 05, 07, 09), `Az.Compute` e `Az.Network` (06), `Az.Monitor` (08). `Az.ResourceGraph` non fa parte del rollup e va installato a parte: serve solo allo script 10.

**Autenticazione.** Interattiva. Ogni script apre il browser con `Connect-AzAccount` se non trova già un contesto Az. Nel codice non ci sono password, segreti, certificati né service principal: autenticati una volta per sessione, poi lancia gli script.

**Permessi.** Il ruolo Reader sulla o sulle subscription è sufficiente per i nove script di report. Per lo script 03 basta **Tag Contributor** sul resource group: scrive solo tag, sulle singole risorse, e non tocca né il resource group né la subscription. Contributor funziona, ma è più ampio del necessario (vedi avvertenza 6).

## ⚠️ Avvertenze

1. **Lo script 03 è l'unico che scrive, e per impostazione predefinita non chiede conferma.** `-WhatIf` funziona davvero — lo script è dichiarato `SupportsShouldProcess` e passa per `ShouldProcess` a ogni risorsa — ma manca `ConfirmImpact = 'High'`: senza `-WhatIf` o `-Confirm` espliciti parte subito e tagga in sequenza tutte le risorse del resource group, senza una sola interazione. Esegui sempre `-WhatIf` la prima volta. E «merge» non significa che non si perde niente: i tag con chiavi diverse restano, ma una chiave già presente viene **sovrascritta nel valore**, quindi se le risorse hanno già un `Owner` il tuo prende il posto del loro.

2. **Senza `-SubscriptionId` lo script 01 copre ogni subscription visibile all'account, e lo script 09 non ha quel parametro: le copre sempre tutte.** Lo script 10, via Resource Graph, interroga per costruzione tutte le subscription accessibili. Se hai accesso delegato a più clienti, una singola esecuzione raccoglie il parco di tutti in un unico CSV, con dati di clienti diversi nello stesso file. In più 01 e 09 cambiano il contesto Az a ogni giro e non ripristinano quello iniziale: a fine esecuzione la sessione è puntata sull'ultima subscription iterata, e gli altri script (02, 04, 05, 06, 07, 08) leggono **solo** la subscription del contesto corrente. Un report lanciato subito dopo nella stessa console descrive quindi quella subscription, non quella che credi. Passa `-SubscriptionId` al 01, e prima dei report controlla `Get-AzContext` — o salvalo all'inizio e ripristinalo con `Set-AzContext`.

3. **Il CSV dello script 08 è un elenco nominativo.** Il campo `Caller` dell'Activity Log contiene lo UPN — l'indirizzo di posta aziendale — della persona che ha eseguito l'operazione: l'export è un «chi ha fatto cosa e quando» con nome e cognome, ed è un dato personale a tutti gli effetti. Trattalo come tale: finalità dichiarata, accesso limitato a chi deve averlo, conservazione limitata nel tempo. Non girarlo a terzi senza averlo valutato.

4. **Un errore su una sola subscription interrompe tutta l'esecuzione e non lascia alcun file.** `$ErrorActionPreference` è impostato su `Stop` in tutti e dieci gli script e nessuno intercetta l'eccezione: in 01 e 09 il report si costruisce in memoria e viene esportato solo alla fine, quindi una subscription senza permessi o una chiamata in throttling fa perdere l'intera raccolta, non soltanto la subscription che ha fallito. L'assenza del CSV è l'unico segnale. Nello 03 lo stesso meccanismo lascia il resource group taggato a metà, senza riepilogo di che cosa sia stato applicato: rilancia con gli stessi parametri — il merge è ripetibile — e verifica il risultato con il 02.

5. **Un report vuoto, o un totale più basso di quello che ti aspetti, è un numero da spiegare, non una buona notizia.** Gli script fotografano quello che Azure restituisce all'account con cui ti sei connesso, nel contesto corrente, e non verificano che il risultato sia completo: con il ruolo Reader su una sola subscription il 06 può scrivere «0 risorse orfane» soltanto perché non vede il resto del tenant. Confronta il totale con la consistenza che conosci — il 09 serve anche a questo — prima di concludere che non c'è niente da fare.

6. **Il permesso chiesto dalla documentazione interna dello script 03 è più ampio del necessario.** L'header dello script, come il vecchio `00-LEGGIMI.txt`, indica Contributor sul resource group: Contributor dà pieno controllo in scrittura su ogni risorsa del gruppo, mentre lo script tocca soltanto i tag delle singole risorse. Il ruolo built-in **Tag Contributor** copre esattamente questo perimetro: assegna quello, non Contributor.

## Dove finiscono i file

Tutti e dieci gli script espongono `-OutputCsv`, e nessuno scrive altrove: nel toolkit non c'è nessun `Out-File`, `Set-Content`, `Add-Content` o `New-Item`. Il valore predefinito è però un percorso **relativo**, nella forma `.\Az-<contenuto>-<aaaammgg>.csv`. Lo script 04 crea il file solo se trova almeno un resource group vuoto; altrimenti scrive l'esito a video e non esporta niente.

Due conseguenze, sempre valide:

- **Il file nasce dove si trova il prompt, non dove sta lo script.** Se hai clonato il repository e lanci gli script da lì, il CSV finisce dentro il clone; se hai aperto la console come amministratore, finisce nella directory di quella console, tipicamente `C:\Windows\System32`. Il `.gitignore` della radice esclude `*.csv`, ma non fidarti del filtro: controlla con `git status` prima di committare, oppure passa `-OutputCsv` con un percorso assoluto fuori dal repository.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente, senza chiedere.** Il nome predefinito contiene solo la data, non l'ora. Se i CSV ti servono come evidenza da conservare, passa `-OutputCsv` con un nome tuo, o sposta il file prima di rilanciare.

**Che cosa c'è dentro quei file.** Lo 08 esporta gli UPN degli operatori (avvertenza 3). Lo 01 e il 10 esportano i tag così come sono: se un tag contiene il nome di un referente o un riferimento interno, quel valore finisce nel CSV. Il 05 e il 06 non contengono dati personali, ma descrivono per nome le protezioni e le risorse scollegate dell'ambiente. Sono tutti file interni, e valgono le regole che valgono per qualsiasi documento che descrive l'infrastruttura di un cliente.

## Esempi

```powershell
# Autenticazione: una volta per sessione
Connect-AzAccount

# Inventario completo delle risorse (tutte le subscription accessibili)
.\01-Get-AzResourceInventory.ps1

# Risorse a cui manca uno dei tag obbligatori
.\02-Get-AzUntaggedResources.ps1 -RequiredTags CostCenter,Owner,Environment

# Chi ha creato o modificato risorse negli ultimi 60 giorni
.\08-Get-AzResourceCreationTimeline.ps1 -Days 60

# Prova a vuoto del tagging in bulk: elenca le risorse, non applica niente
.\03-Set-AzResourceTagsBulk.ps1 -ResourceGroupName rg-prod -Tags @{CostCenter='IT';Environment='Prod'} -WhatIf
```

## Altro

Lo stesso contenuto è scaricabile come archivio ZIP dalla pagina del toolkit sul sito: [synsphere.it/download/toolkit-powershell-azure-governance](https://synsphere.it/download/toolkit-powershell-azure-governance/).

Se la governance di Azure ti serve come servizio, o se uno script non si comporta come descritto qui: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
