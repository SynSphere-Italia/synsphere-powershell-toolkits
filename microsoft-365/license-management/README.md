# Gestione licenze Microsoft 365

Dieci script PowerShell per vedere quali licenze di un tenant sono assegnate, a chi e per quale via, e per togliere quelle ridondanti: otto sono di sola lettura, due modificano le assegnazioni.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

La raccolta è rivolta ad amministratori IT interni e a MSP che hanno credenziali amministrative su un tenant Microsoft 365 e devono capire dove va la spesa per le licenze. Risponde a domande che richiedono di incrociare più elenchi: quali caselle condivise hanno una licenza che di norma non serve, quali utenti licenziati non accedono da mesi, quali licenze arrivano da un gruppo e quali sono assegnate direttamente, quale costo mensile corrisponde a ciascun utente.

Ogni script è autonomo, prende i suoi parametri da riga di comando e si autentica in modo interattivo con MFA. Gli otto script di sola lettura producono un CSV da filtrare o allegare a un assessment; i due di scrittura servono al passo successivo, cioè correggere le assegnazioni dirette ridondanti e assegnare o rimuovere SKU anche in massa.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-M365LicenseReport.ps1` | Ogni utente con licenza, gli SKU assegnati con il nome leggibile (skuPartNumber) e lo stato dell'account, abilitato o disabilitato. | Sola lettura |
| `02-Get-M365LicenseExpiryReport.ps1` | SKU sottoscritti dall'organizzazione: unità acquistate, consumate, in warning o sospese, e stato di capacità. Non riporta la data di rinnovo, perché `Get-MgSubscribedSku` non la espone. | Sola lettura |
| `03-Manage-M365Licenses.ps1` | Quattro azioni: `Report` elenca le licenze di un utente; `Assign` e `Remove` agiscono su un singolo SKU; `BulkCsv` applica un CSV con colonne UserPrincipalName, SkuPartNumber, Operation. | `Report` sola lettura; `Assign`, `Remove`, `BulkCsv` **SCRIVE** |
| `04-Get-M365LicensedSharedMailboxes.ps1` | Caselle condivise che hanno una licenza assegnata, incrociando Exchange Online e Graph: una shared mailbox di norma non richiede licenza fino a 50 GB, quindi è spesa quasi sempre recuperabile. | Sola lettura |
| `05-Get-M365LicensedGroups.ps1` | Gruppi che hanno una o più licenze assegnate (group-based licensing), con il numero di membri. | Sola lettura |
| `06-Get-M365LicenseAssignmentPath.ps1` | Per ogni licenza di ogni utente, se è assegnata direttamente o ereditata da un gruppo, con il nome del gruppo. Legge `licenseAssignmentStates`. Da usare prima di rimuovere: una licenza ereditata si toglie dal gruppo, non dall'utente. | Sola lettura |
| `07-Get-M365GroupBasedLicenseReport.ps1` | Solo le assegnazioni ereditate da gruppo, con gruppo di origine, `State` ed eventuale errore di assegnazione. | Sola lettura |
| `08-Remove-M365OverlappedLicenses.ps1` | Utenti che hanno lo stesso SKU sia direttamente sia da gruppo: la diretta è ridondante. Senza parametri produce solo il report; con `-RemoveDirect` rimuove l'assegnazione diretta. | Sola lettura per impostazione predefinita; con `-RemoveDirect` **SCRIVE** |
| `09-Get-M365UnusedLicenses.ps1` | Utenti licenziati che non accedono da più di N giorni (`-InactiveDays`, predefinito 90) o mai, incrociando le licenze con `signInActivity`. | Sola lettura |
| `10-Get-M365LicenseCostReport.ps1` | Costo mensile per utente, sommando il prezzo dei suoi SKU preso da un listino interno allo script o da `-PriceCsv` (colonne SkuPartNumber, MonthlyPrice). | Sola lettura |

## Prima di eseguirli

**PowerShell.** PowerShell 5.1 oppure PowerShell 7. Nessuno degli script contiene `#Requires -Version`, quindi il requisito non viene verificato all'avvio.

**Moduli.**

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser   # solo per lo script 04
```

Installa il modulo `Microsoft.Graph` completo, oppure tutti i sottomoduli elencati qui sotto. La direttiva `#Requires` degli script dichiara solo `Microsoft.Graph.Authentication` (e `Microsoft.Graph.Users.Actions` in `03` e `08`), ma i cmdlet usati stanno anche altrove: `Microsoft.Graph.Identity.DirectoryManagement` per `Get-MgSubscribedSku`, usato da tutti e dieci gli script; `Microsoft.Graph.Users` per `Get-MgUser` e `Get-MgUserLicenseDetail`, usati da `01`, `03`, `04`, `06`, `07`, `08`, `09`, `10`; `Microsoft.Graph.Groups` per `Get-MgGroup` e `Get-MgGroupMember`, usati da `05`, `06`, `07`. Se installi i soli sottomoduli dichiarati, il controllo `#Requires` passa e lo script si interrompe più tardi su `Get-MgSubscribedSku` con un errore di termine non riconosciuto.

**Scope Graph delegati.** `User.Read.All` (tutti gli script che leggono utenti), `Organization.Read.All` (tutti e dieci gli script), `Group.Read.All` (`05`, `06`, `07`), `AuditLog.Read.All` (solo `09`), `User.ReadWrite.All` (solo `03` e `08`). Gli scope richiesti a runtime da `Connect-MgGraph` sono quelli dichiarati nell'header `.NOTES` di ogni script.

**Ruoli Entra ID.** Global Reader è sufficiente per gli otto script di sola lettura. Per `03` e `08` serve License Administrator, oppure User Administrator.

**Exchange Online.** Solo per `04`: un ruolo che consenta `Get-EXOMailbox`, cioè View-Only Recipients o Recipient Management.

**Licenza del tenant.** `09` usa `signInActivity`, che richiede Microsoft Entra ID P1 o P2.

**Autenticazione.** Interattiva con MFA: si apre il browser. Nessuno script contiene app registration, client secret o certificati, e nessuno chiede una password sulla riga di comando.

## ⚠️ Avvertenze

1. **Togliere una licenza avvia la cancellazione dei dati.** Quando `03` rimuove uno SKU (`-Action Remove` o `BulkCsv`) e l'utente resta senza licenza, la sua casella Exchange Online e il suo OneDrive passano in stato soft-deleted: i contenuti restano recuperabili per 30 giorni, poi non più. Su una rimozione in massa questo non è un risparmio di spesa, è un evento di perdita dati. Prima di rimuovere, controlla con `06` se la licenza è diretta o ereditata, ed esporta o metti in hold casella e OneDrive degli utenti interessati.

2. **`08 -RemoveDirect` agisce su tutto il tenant e non chiede conferma.** Lo script itera su tutti gli utenti (`Get-MgUser -All`) e rimuove ogni assegnazione diretta sovrapposta in un'unica esecuzione. `SupportsShouldProcess` è dichiarato, ma senza `ConfirmImpact = 'High'`: con il valore predefinito di `$ConfirmPreference` il prompt di conferma non compare, quindi l'unica barriera fra il report e la rimozione di massa è lo switch. Esegui sempre prima con `-WhatIf`, e aggiungi `-Confirm` se vuoi il prompt. Lo script inoltre giudica la sovrapposizione dalla sola esistenza dell'assegnazione da gruppo, non dal suo `State`: se quella da gruppo è in errore, e lo vedi con `07`, rimuovere la diretta lascia l'utente senza licenza.

3. **`03 -Action BulkCsv` può fermarsi a metà senza lasciare traccia.** Applica ogni riga del CSV senza prompt e con `$ErrorActionPreference = 'Stop'`: la prima riga che fallisce interrompe l'esecuzione, le righe già applicate restano applicate e nessun log dice quali. Rilanciare lo stesso CSV ripete le operazioni iniziali. Esegui prima con `-WhatIf`, lavora su file piccoli e rileggi lo stato reale con `01` o `06` prima di rilanciare.

4. **Un report vuoto, o tutto negativo, può essere un permesso mancante e non un tenant pulito.** Due casi concreti. `09` considera inattivo chi non ha una data di ultimo accesso, e la stampa come `Mai`: su un tenant senza Microsoft Entra ID P1 o P2, o senza il consenso a `AuditLog.Read.All`, `signInActivity` arriva vuoto per tutti e ogni utente licenziato risulta recuperabile. `04`, `05`, `06` e `07` risolvono utenti e gruppi con `-ErrorAction SilentlyContinue`: se `Group.Read.All` non è concesso, la risoluzione fallisce in silenzio e il CSV esce con il nome del gruppo vuoto (`Gruppo: ` in `06`, `SourceGroup` vuoto in `07`), che si legge come "nessuna assegnazione da gruppo". È la premessa sbagliata per una rimozione, e `06` serve esattamente a prepararla. Confronta sempre il numero di righe esportate con il numero di utenti o di gruppi del tenant: un numero senza il suo denominatore non dice niente.

5. **Il listino di `10` è di esempio: i totali che produce non sono i tuoi costi.** La mappa `$PriceMap` nello script contiene cinque prezzi di esempio che non corrispondono a nessun contratto, perché i prezzi reali dipendono dal tuo accordo CSP o EA. Inoltre uno SKU assente dal listino viene conteggiato come zero: il costo per utente e il totale finale escono più bassi del vero, senza alcun avviso. Passa `-PriceCsv` con il tuo listino prima di mostrare quei numeri a chiunque.

6. **I due script di scrittura chiedono più permessi di quanti usino.** `03` e `08` passano `User.ReadWrite.All` a `Connect-MgGraph`, cioè la scrittura su ogni attributo di ogni utente del tenant, mentre a loro serve solo assegnare e rimuovere licenze. `03` lo richiede anche con `-Action Report`, che è di sola lettura. Per l'assegnazione di licenze Microsoft documenta un permesso a privilegio minore, `LicenseAssignment.ReadWrite.All`, che questi script non usano: concedendo il consenso concedi più di quanto serva. Se ti serve solo leggere, usa gli otto script di sola lettura, nessuno dei quali chiede scrittura.

## Dove finiscono i file

Nove script su dieci esportano un CSV; l'unico che non scrive su disco è `03`. Il percorso predefinito è relativo (`.\M365-<nome>-<data>.csv`), quindi il file nasce nella directory in cui si trova il prompt e non accanto allo script: da una console aperta come amministratore può finire in `C:\Windows\System32`, e se hai clonato il repository e lanci da lì finisce dentro il clone. Il `.gitignore` del repository esclude `*.csv`, ma guarda il `git status` prima di committare invece di fidarti.

Il nome del file contiene solo la data (`yyyyMMdd`) e nessuno dei nove `Export-Csv` usa `-NoClobber`: una seconda esecuzione nello stesso giorno sovrascrive la precedente senza chiedere niente. Se devi conservare due esecuzioni, passa `-OutputCsv` con un percorso esplicito.

Il contenuto è dato personale: nome e UserPrincipalName di tutti gli utenti licenziati del tenant, la data dell'ultimo accesso (`09`), gli indirizzi delle caselle condivise (`04`) e i gruppi attraverso cui passano le licenze (`06`, `07`). Trattalo come un'estrazione dalla rubrica aziendale: non lasciarlo in cartelle condivise e non spedirlo senza cifratura. L'unico export privo di dati personali è quello di `02`, che si ferma al livello di SKU.

## Esempi

```powershell
# Inventario di tutti gli utenti licenziati, con gli SKU assegnati
.\01-Get-M365LicenseReport.ps1

# Utenti licenziati che non accedono da oltre 60 giorni
.\09-Get-M365UnusedLicenses.ps1 -InactiveDays 60

# Assegna uno SKU a un utente, in simulazione
.\03-Manage-M365Licenses.ps1 -Action Assign -UserPrincipalName mario.rossi@azienda.it -SkuPartNumber SPE_E3 -WhatIf

# Simula la rimozione delle licenze dirette sovrapposte, su tutto il tenant
.\08-Remove-M365OverlappedLicenses.ps1 -RemoveDirect -WhatIf
```

## Download e supporto

Lo stesso contenuto è scaricabile come ZIP dalla pagina [synsphere.it/download/toolkit-powershell-licenze-microsoft-365](https://synsphere.it/download/toolkit-powershell-licenze-microsoft-365/). Se ti serve una mano a leggere i report, o a impostare una rimozione in sicurezza, scrivici da [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
