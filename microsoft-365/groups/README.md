# Gruppi e appartenenze Microsoft 365

Dieci script PowerShell di sola lettura che inventariano gruppi, liste di distribuzione e appartenenze di un tenant Microsoft 365, ed esportano ogni report in CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Serve a chi amministra un tenant Microsoft 365 dall'interno e a chi lo fa per conto di altri (MSP), quando deve fare pulizia sui gruppi, un audit degli accessi o un offboarding.

Su Microsoft 365 la stessa informazione è sparsa su due superfici: i gruppi Microsoft 365 e di sicurezza stanno su Microsoft Graph, le liste di distribuzione su Exchange Online — e le DL non si vedono dalla scheda dell'utente. I primi cinque script leggono da Graph, gli altri cinque da Exchange Online. Ciascuno risponde a una domanda sola e lascia il risultato in un CSV, che si filtra o si allega a un verbale.

## Script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-M365AllGroupsReport.ps1` | Inventario di tutti i gruppi del tenant — Microsoft 365, sicurezza, mail-enabled security, distribution, dinamici — classificati per tipo, con il conteggio dei membri. | Sola lettura |
| `02-Get-M365GroupMembersReport.ps1` | Per ogni gruppo Microsoft 365, proprietari e membri: una riga per appartenenza, con il ruolo e il tipo (interno oppure ospite). | Sola lettura |
| `03-Get-M365UserMembershipReport.ps1` | Lookup inverso: dato un utente, i gruppi di cui risulta membro diretto (vedi avvertenze). | Sola lettura |
| `04-Get-M365EmptyGroups.ps1` | Gruppi senza membri, elencati come candidati alla dismissione. | Sola lettura |
| `05-Get-M365OwnerlessM365Groups.ps1` | Gruppi Microsoft 365 senza proprietario: nessuno risponde della membership e dei contenuti collegati (Teams, SharePoint, Planner). | Sola lettura |
| `06-Get-M365DistributionGroupReport.ps1` | Liste di distribuzione con una riga per membro: nome, email, tipo. | Sola lettura |
| `07-Get-M365DynamicDLMembers.ps1` | Gruppi di distribuzione dinamici: valuta il filtro di ciascuno e mostra i destinatari che vi rientrano in quel momento. | Sola lettura |
| `08-Get-M365UserDistributionGroups.ps1` | Lookup inverso sulle DL: dato un utente, le liste di distribuzione che lo contengono. | Sola lettura |
| `09-Get-M365GroupMailboxSize.ps1` | Dimensione e numero di elementi della casella di conversazione di ogni gruppo Microsoft 365. Lo storage del sito SharePoint collegato è separato e non è compreso. | Sola lettura |
| `10-Get-M365NestedDistributionGroups.ps1` | Espansione ricorsiva delle DL annidate: elenco piatto dei membri finali con il percorso di annidamento, con protezione anti-loop. | Sola lettura |

Dieci su dieci sono di sola lettura: nel codice non compare nessun cmdlet con verbo `New-`, `Set-`, `Add-`, `Remove-` o equivalente, quindi non c'è niente da confermare e `-WhatIf` non è previsto. Tutti e dieci, però, scrivono un file CSV su disco: vedi [Dove finiscono i file](#dove-finiscono-i-file).

## Prima di eseguirli

**PowerShell** 5.1 oppure PowerShell 7. Nessuno dei dieci script dichiara `#Requires -Version`: il controllo non è automatico.

**Moduli, script 01-05 (Microsoft Graph):**

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Groups -Scope CurrentUser    # script 01, 02, 04, 05
Install-Module Microsoft.Graph.Users -Scope CurrentUser     # script 03
```

Il `#Requires` degli script 01-05 nomina solo `Microsoft.Graph.Authentication`, ma i cmdlet che usano stanno altrove: `Get-MgGroup`, `Get-MgGroupMember` e `Get-MgGroupOwner` in `Microsoft.Graph.Groups`, `Get-MgUser` e `Get-MgUserMemberOf` in `Microsoft.Graph.Users`. Con il solo modulo di autenticazione installato il controllo `#Requires` passa, `Connect-MgGraph` riesce e lo script si interrompe al primo `Get-Mg*` con «term is not recognized». Installa i sotto-moduli qui sopra; il meta-modulo `Microsoft.Graph` li contiene tutti, ma scarica l'intero SDK.

**Moduli, script 06-10 (Exchange Online):**

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

**Permessi.** Gli script Graph chiedono gli scope delegati all'avvio, con `Connect-MgGraph`; sono tutti in sola lettura.

- script 01, 02, 04: `Group.Read.All` e `GroupMember.Read.All`
- script 03: `User.Read.All` e `GroupMember.Read.All`
- script 05: `Group.Read.All`
- script 06-10: Exchange Online, ruolo **View-Only Recipients**. Copre anche `Get-EXOMailbox` e `Get-EXOMailboxStatistics` dello script 09 e la scansione delle DL dello script 08, il cui help cita solo «Exchange Online» senza nominare il ruolo.

**Chiusura della sessione.** Nessuno dei dieci script si disconnette: la connessione e il token restano aperti per tutta la vita della console e le sessioni si accumulano se ne esegui più di uno di seguito — che è l'uso previsto da un toolkit numerato. Chiudi a mano quando hai finito:

```powershell
Disconnect-MgGraph
Disconnect-ExchangeOnline -Confirm:$false
```

## ⚠️ Avvertenze

Regola comune a tutti i punti che seguono: un report vuoto, o tutto a zero, non è una buona notizia finché non hai verificato di aver avuto i permessi per leggere tutto quello che lo script ha interrogato. Un numero senza il suo denominatore inganna.

1. **`04-Get-M365EmptyGroups.ps1` elenca come «vuoto» anche un gruppo che non è riuscito a leggere.** Il conteggio dei membri gira con `-ErrorAction SilentlyContinue`: se la lettura della membership fallisce — permesso negato su quel gruppo, throttling di Graph, membro cancellato — il conteggio vale 0 esattamente come per un gruppo davvero vuoto, e il gruppo finisce nel CSV sotto l'etichetta che lo script stampa a schermo, «gruppi VUOTI (candidati alla pulizia)». Chi cancella basandosi su quella lista può cancellare un gruppo che ha membri. Verifica ogni gruppo prima di dismetterlo, riaprendo la sua membership dal portale o con una lettura dedicata. Lo script fa inoltre una chiamata per ogni gruppo del tenant: su tenant grandi il throttling è atteso, quindi eseguilo fuori orario — e il throttling è proprio una delle cause che producono quegli zero.

2. **`08-Get-M365UserDistributionGroups.ps1` può restituire zero righe per un utente che è in molte liste.** Il confronto avviene fra lo UPN che passi e il `PrimarySmtpAddress` dei membri, e i due coincidono solo per convenzione: con UPN su dominio non routable, UPN `*.onmicrosoft.com` o indirizzo primario diverso dallo UPN, il confronto non combacia mai e lo script esce con successo e un CSV vuoto. Gli alias (gli altri indirizzi in `EmailAddresses`) sono comunque ignorati. L'uso dichiarato è l'offboarding: un vuoto falso significa un utente che esce dall'azienda e resta in tutte le liste di distribuzione. Prima di fidarti di un risultato vuoto, verifica con `Get-Recipient -Identity <UPN>` qual è l'indirizzo primario reale e rilancia con quello.

3. **`05-Get-M365OwnerlessM365Groups.ps1` può dichiarare ownerless un gruppo che ha un proprietario.** La lettura degli owner gira con `-ErrorAction SilentlyContinue`: se fallisce, l'elenco risulta vuoto e il gruppo viene stampato in rosso con «ATTENZIONE: ... gruppi M365 SENZA owner ... Assegna un proprietario». Controlla i gruppi segnalati uno per uno prima di aprire un'attività di governance o di riassegnare proprietari.

4. **La colonna `Members` di `01-Get-M365AllGroupsReport.ps1` vale 0 anche quando la lettura è fallita.** Stesso meccanismo del punto 1: l'errore viene inghiottito e l'inventario presenta come certo un conteggio che è il risultato di un errore. Anche questo script interroga l'intero tenant con una chiamata per gruppo. Un gruppo che nell'inventario risulta a 0 membri va riletto singolarmente prima di qualsiasi decisione.

5. **`03-Get-M365UserMembershipReport.ps1` riporta solo le appartenenze dirette.** Usa `Get-MgUserMemberOf`, che non restituisce i gruppi raggiunti attraverso un gruppo annidato, mentre il suo help promette «tutti i gruppi». In un audit degli accessi il report sotto-riporta senza dirlo. Leggi il risultato come «gruppi di cui è membro diretto»; per la membership completa serve `Get-MgUserTransitiveMemberOf`.

6. **`10-Get-M365NestedDistributionGroups.ps1` salta in silenzio i sottoalberi dinamici.** Quando dentro una DL trova un gruppo di distribuzione dinamico lo tratta come una DL normale, ma il cmdlet che ne legge i membri non accetta un gruppo dinamico: l'errore viene inghiottito e quel ramo rende zero membri. L'«elenco piatto dei membri finali» perde quindi tutti i destinatari di quel sottoalbero, senza nessun avviso. Se le tue DL contengono DL dinamiche, risolvile a parte con `07-Get-M365DynamicDLMembers.ps1` e unisci i due CSV. La protezione anti-loop, invece, funziona: ogni radice parte con un elenco dei visitati nuovo.

## Dove finiscono i file

Tutti e dieci gli script esportano un CSV. Il nome predefinito è relativo e contiene solo la data, non l'ora: `.\M365-<report>-<data>.csv`.

- **Il file nasce dove si trova il prompt**, non dove sta lo script. Da una console aperta come amministratore è tipicamente `C:\Windows\System32`; se hai clonato il repository e lanci dalla cartella clonata, il CSV nasce dentro il clone. Il `.gitignore` della radice esclude `*.csv`, ma non fidarti: guarda `git status` prima di committare.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente senza chiedere niente**: nessuno script usa `-NoClobber`. Se devi conservare i report, passa un percorso e un nome tuoi con `-OutputCsv`.
- **Il contenuto è dato personale.** Nei CSV finiscono nome e cognome, UPN e indirizzo email di ogni utente e di ogni ospite esterno del tenant, la composizione completa delle liste di distribuzione e la dimensione delle caselle di gruppo. Scrivili fuori dal repository, in un percorso ad accesso limitato, e cancellali quando il report ha smesso di servire.

## Esempi

```powershell
# Inventario di tutti i gruppi del tenant
.\01-Get-M365AllGroupsReport.ps1

# Gruppi di un singolo utente, con il CSV fuori dalla cartella clonata
.\03-Get-M365UserMembershipReport.ps1 -UserPrincipalName mario.rossi@contoso.com -OutputCsv "$env:USERPROFILE\Documents\M365-UserMembership.csv"

# Liste di distribuzione che contengono quell'utente (tipico prima di un offboarding)
.\08-Get-M365UserDistributionGroups.ps1 -UserPrincipalName mario.rossi@contoso.com

# Espansione ricorsiva delle DL annidate
.\10-Get-M365NestedDistributionGroups.ps1
```

---

Gli stessi script si scaricano come ZIP da [synsphere.it/download/toolkit-powershell-gruppi-microsoft-365](https://synsphere.it/download/toolkit-powershell-gruppi-microsoft-365/). Se ti serve una mano a leggere un report o a impostare la governance di gruppi e liste di distribuzione, scrivici da [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
