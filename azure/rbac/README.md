# Azure RBAC e governance degli accessi

Dieci script PowerShell di sola lettura che fotografano chi ha quale ruolo RBAC su quale scope in una subscription Azure, ed esportano ogni risultato in un CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Serve a chi amministra Azure dall'interno e a chi lo fa per conto di altri (MSP), quando deve preparare un audit degli accessi, un offboarding o una revisione periodica dei privilegi senza acquistare uno strumento di governance.

Su Azure la risposta alla domanda «chi può fare cosa» non sta in un posto solo: le assegnazioni vivono su livelli di scope che si ereditano a cascata (management group, subscription, resource group, singola risorsa), un ruolo può arrivare da un gruppo invece che dall'utente, le automazioni hanno i loro principal e accanto a RBAC sopravvivono i classic administrator. Ciascuno dei dieci script risponde a una domanda sola e lascia il risultato in un CSV, che si filtra o si allega a un verbale.

## Script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-AzRoleAssignmentReport.ps1` | Tutte le assegnazioni di ruolo della subscription: chi ha quale ruolo e su quale scope (subscription, resource group, risorsa). È la base di ogni audit degli accessi. | Sola lettura |
| `02-Get-AzPrivilegedRoleAssignments.ps1` | Isola i ruoli ad alto privilegio — Owner, Contributor, User Access Administrator, Role Based Access Control Administrator — assegnati allo scope della subscription (vedi avvertenze). | Sola lettura |
| `03-Get-AzCustomRoleDefinitions.ps1` | Definizioni di ruolo custom, non built-in, con le azioni consentite e negate e gli scope assegnabili. | Sola lettura |
| `04-Get-AzOrphanedRoleAssignments.ps1` | Assegnazioni che Azure restituisce senza nome visualizzato, presentate come appartenenti a identità ormai eliminate (vedi avvertenze). | Sola lettura |
| `05-Get-AzServicePrincipalRoleAssignments.ps1` | Assegnazioni il cui principal è un service principal — app registration, managed identity, automazioni — con ruolo, scope e `ObjectId` di ciascuna. | Sola lettura |
| `06-Get-AzUserRoleAssignments.ps1` | Lookup inverso su un singolo utente: ogni assegnazione e su quale scope, comprese quelle ereditate dai gruppi, con una colonna che distingue «diretto» da «gruppo: *nome*». | Sola lettura |
| `07-Get-AzClassicAdministrators.ps1` | Classic administrator (Co-Administrator, Service Administrator, Account Administrator): privilegi ampi di Azure Service Management, da bonificare a favore del solo RBAC. | Sola lettura |
| `08-Get-AzManagementGroupRoleAssignments.ps1` | Assegnazioni fatte a livello di management group, che si ereditano su tutte le subscription sottostanti, elencate per ogni MG accessibile. | Sola lettura |
| `09-Get-AzGuestUserRoleAssignments.ps1` | Utenti guest B2B (UPN con `#EXT#`) che hanno assegnazioni di ruolo su risorse Azure. | Sola lettura |
| `10-Export-AzRbacMatrix.ps1` | Matrice completa principal × ruolo × scope, con il livello di scope (Subscription, ResourceGroup, Resource, ManagementGroup) in una colonna dedicata. | Sola lettura |

Dieci su dieci sono di sola lettura: nel codice non compare nessun cmdlet con verbo `New-`, `Set-`, `Add-` o `Remove-`. L'unica occorrenza di `Remove-AzRoleAssignment` in tutta la cartella è dentro un messaggio a schermo dello script 04 (avvertenza 1). Non c'è quindi niente da confermare e `-WhatIf` non è previsto da nessuno dei dieci. Tutti e dieci, però, scrivono un file CSV su disco: vedi [Dove finiscono i file](#dove-finiscono-i-file).

## Prima di eseguirli

**PowerShell** 5.1 oppure PowerShell 7. Nessuno dei dieci script dichiara `#Requires -Version`: il controllo non è automatico.

**Moduli.** Tutti e dieci dichiarano `#Requires -Modules Az.Accounts, Az.Resources`, e sono i due soli moduli che il codice usa:

```powershell
Install-Module Az.Accounts -Scope CurrentUser
Install-Module Az.Resources -Scope CurrentUser
```

Il meta-modulo `Az` li contiene entrambi, ma scarica l'intero set: installalo solo se usi anche gli altri toolkit Azure. Microsoft Graph non serve — il modulo `Microsoft.Graph` non è importato né usato da nessuno dei dieci script.

**Autenticazione.** `Connect-AzAccount`. Gli script lo invocano da soli soltanto se non trovano già un contesto aperto: se un contesto esiste, lavorano sulla subscription che vi è selezionata, qualunque sia, senza chiedere e senza dirlo (avvertenza 5).

**Permessi.**

- script 01, 02, 04, 05, 06, 07, 09, 10: ruolo **Reader** sulla subscription, più `Microsoft.Authorization/roleAssignments/read`
- script 03: **Reader** più `Microsoft.Authorization/roleDefinitions/read`
- script 08: **Reader** a livello di **management group**, non solo di subscription
- script 01, 04, 05, 06, 09, 10, in aggiunta e **non dichiarato nel loro help**: la lettura della directory Entra ID (ruolo **Directory Readers**, oppure **Global Reader**). Serve allo script 06 per espandere l'appartenenza ai gruppi, e serve agli altri perché le colonne `Principal`, `SignInName` e `Tipo` siano popolate: con il solo Reader ARM quei campi tornano vuoti, e quattro script (04, 05, 07, 09) ci costruiscono sopra un filtro. È la causa delle avvertenze 1 e 2.

**Chiusura della sessione.** Nessuno dei dieci esegue `Disconnect-AzAccount`: a script finito la sessione Azure resta disponibile nella console. Chiudila a mano quando hai terminato, soprattutto su una macchina condivisa:

```powershell
Disconnect-AzAccount
```

## ⚠️ Avvertenze

Regola comune a tutti i punti che seguono: con questi dieci script un report vuoto, o un conteggio a zero, non è una buona notizia finché non hai verificato di aver avuto i permessi per leggere tutto quello che lo script ha interrogato. Nove su dieci scrivono il CSV anche quando non hanno trovato niente, e il messaggio finale stampa il numeratore senza il denominatore: un numero senza il suo denominatore inganna.

1. **`04-Get-AzOrphanedRoleAssignments.ps1` può elencare come orfane assegnazioni ancora vive, e il suo messaggio finale invita a cancellarle.** Lo script classifica come orfana ogni assegnazione in cui `DisplayName` e `ObjectType` sono entrambi vuoti. Quei due campi sono vuoti anche quando chi esegue non ha la lettura della directory Entra ID — cioè esattamente con i soli permessi che l'help dichiara — non solo quando l'identità è stata davvero eliminata. Con il solo Reader ARM il CSV può quindi contenere assegnazioni perfettamente attive, e a schermo compare «N assegnazioni ORFANE → ... Rimuovile con `Remove-AzRoleAssignment`», senza nominare `-WhatIf`. Lo script non rimuove niente da sé, ma seguirne il consiglio su un risultato non validato significa togliere accessi in uso, e un'assegnazione rimossa non si annulla: va ricreata a mano. Prima di toccare qualcosa, verifica per ogni riga che quell'`ObjectId` non sia più risolvibile su Entra ID, e in ogni caso parti da `-WhatIf`:

   ```powershell
   Remove-AzRoleAssignment -ObjectId <ObjectId> -RoleDefinitionName <Ruolo> -Scope <Scope> -WhatIf
   ```

2. **Gli script 06 e 09 possono restituire zero senza alcun errore per mancanza di permessi, e in un audit quello zero si legge «non ha ruoli».** Lo script 06 espande l'appartenenza ai gruppi con `-ExpandPrincipalGroups`, operazione che richiede la lettura della directory Entra ID, mentre il suo help dichiara solo «Reader + lettura roleAssignments»: con i soli permessi dichiarati lo script o fallisce o restituisce un risultato incompleto. Lo script 09 filtra gli ospiti su `SignInName -match '#EXT#'`: senza lettura della directory, `SignInName` è vuoto, il filtro non aggancia nessun guest e il CSV esce vuoto con un conteggio a zero e nessun messaggio di errore. Lo stesso meccanismo riguarda la colonna `ObjectType`, su cui filtrano 05, 07 e 09. Aggiungi la lettura della directory ai prerequisiti e, prima di fidarti di un risultato, apri il CSV e controlla che `Principal` e `SignInName` siano davvero popolate: se sono vuote, il perimetro che hai letto non è quello che credi.

3. **`02-Get-AzPrivilegedRoleAssignments.ps1` non vede i privilegi ereditati dall'alto né quelli dati più in basso.** Il filtro confronta lo scope dell'assegnazione con quello della subscription in modo esatto. Un Owner assegnato su un management group — che la subscription eredita — e un Owner o Contributor assegnato su un resource group o su una singola risorsa non compaiono nel report, pur avendo quei privilegi sulle risorse. Lo script si presenta come «il primo controllo di sicurezza degli accessi» e risponde alla domanda «chi ha il controllo totale sulla subscription?»: letto da solo, può far concludere che nessuno è Owner quando qualcuno lo è. Leggilo sempre insieme a `08-Get-AzManagementGroupRoleAssignments.ps1` per il livello superiore e a `10-Export-AzRbacMatrix.ps1`, che riporta ogni assegnazione con il suo livello di scope.

4. **`08-Get-AzManagementGroupRoleAssignments.ps1` conta zero per i management group che non riesce a leggere, e non li distingue da quelli senza assegnazioni.** La lettura di ogni MG gira con `-ErrorAction SilentlyContinue`: se su un management group non hai Reader, quel MG contribuisce zero righe e il totale stampato alla fine sembra completo. E se è l'elenco dei management group a non essere leggibile, lo script stampa «Management group non accessibili o non configurati» e termina senza scrivere il CSV, confondendo i due casi — una gerarchia che esiste ma che non puoi leggere e una gerarchia che non esiste. Poiché le assegnazioni su MG sono quelle che si ereditano su tutte le subscription sottostanti, un'assenza a questo livello è la più costosa: confronta l'elenco dei MG presenti nel CSV con la gerarchia reale del tenant prima di dichiarare pulito quel livello.

5. **Il perimetro è la subscription selezionata nel contesto corrente, e nessun CSV ha una colonna che dica quale.** Otto dei dieci script leggono le assegnazioni senza passare uno scope, quindi coprono la subscription del contesto; lo 03 legge le definizioni di ruolo nello stesso contesto; solo lo 08 esce da quel perimetro, passando lo scope dei management group. Nessuno dei dieci cambia subscription né itera sulle altre. Se il tenant ne ha più di una, un'esecuzione ne fotografa una sola, e la scelta la fa il contesto già aperto: con una sessione `Connect-AzAccount` in corso non ti viene chiesto niente. Verifica il contesto prima di lanciare, e se devi coprire tutto il tenant ripeti su ogni subscription dando a ciascun CSV un nome diverso con `-OutputCsv`:

   ```powershell
   Get-AzContext | Select-Object -ExpandProperty Subscription
   Set-AzContext -Subscription '<nome o id della subscription>'
   ```

## Dove finiscono i file

Tutti e dieci gli script esportano un CSV. Il percorso è parametrizzato — ognuno espone `-OutputCsv` — ma il valore predefinito è relativo e contiene solo la data, non l'ora: `.\Az-<report>-<data>.csv`.

- **Il file nasce dove si trova il prompt**, non dove sta lo script. Da una console aperta come amministratore è tipicamente `C:\Windows\System32`; se hai clonato il repository e lanci dalla cartella clonata, il CSV nasce dentro il clone. Il `.gitignore` della radice esclude `*.csv`, ma non fidarti: guarda `git status` prima di committare.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente senza chiedere niente**: nessuno dei dieci usa `-NoClobber` o `-Append`, e il nome predefinito resta identico per tutta la giornata. Se devi conservare i report — per esempio il «prima» e il «dopo» di una bonifica dei privilegi — passa un percorso e un nome tuoi con `-OutputCsv`.
- **Il contenuto descrive chi ha accesso a che cosa.** Nei CSV finiscono nome visualizzato, UPN e indirizzo email degli utenti interni e degli ospiti esterni, gli `ObjectId` dei principal, gli identificativi completi delle assegnazioni, i service principal delle automazioni con il loro ruolo e la mappa dei privilegi amministrativi della subscription, classic administrator compresi. Per chi cercasse un bersaglio è esattamente l'elenco utile. Scrivi questi file fuori dal repository, in un percorso ad accesso limitato, e cancellali quando il report ha smesso di servire.

## Esempi

```powershell
# Tutte le assegnazioni di ruolo della subscription selezionata
.\01-Get-AzRoleAssignmentReport.ps1

# Ruoli di un singolo utente, diretti e da gruppi (tipico prima di un offboarding)
.\06-Get-AzUserRoleAssignments.ps1 -SignInName mario.rossi@azienda.it

# Privilegi ereditati dal livello superiore, con il CSV fuori dalla cartella clonata
.\08-Get-AzManagementGroupRoleAssignments.ps1 -OutputCsv "$env:USERPROFILE\Documents\Az-MgRoleAssignments.csv"

# Matrice completa principal x ruolo x scope
.\10-Export-AzRbacMatrix.ps1
```

---

Gli stessi script si scaricano come ZIP da [synsphere.it/download/toolkit-powershell-azure-rbac](https://synsphere.it/download/toolkit-powershell-azure-rbac/). Se ti serve una mano a leggere un report o a impostare la governance degli accessi su Azure, scrivici da [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
