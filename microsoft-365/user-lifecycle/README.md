# Microsoft 365 — Gestione utenti e ciclo di vita

Dieci script PowerShell per sapere chi accede davvero al tenant, chi non ha l'MFA, chi è amministratore e chi non si collega più — e per chiudere un account quando una persona esce.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Raccolta per amministratori IT interni e per MSP che gestiscono tenant Microsoft 365 di piccole e medie imprese. Otto script producono in CSV l'inventario di ciò che la console mostra una schermata alla volta: ultimo accesso, stato MFA, età delle password, ruoli amministrativi, manager, storico degli accessi. Due script scrivono sul tenant: la bonifica degli account inattivi e l'offboarding di una persona che lascia l'azienda.

Tutti passano da Microsoft Graph. Ogni script è autonomo — nessun file condiviso, nessuna dipendenza fra uno script e l'altro — è parametrico e porta in testa i permessi Graph che richiede.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-M365LastLogonReport.ps1` | Per ogni utente la data dell'ultimo accesso **interattivo** e i giorni di inattività, in CSV ordinato dall'account più fermo. Serve a individuare gli account dormienti. | Sola lettura |
| `02-Get-M365MfaStatusReport.ps1` | Stato MFA preso dal report ufficiale di Entra «authentication method registration details»: registrato, capace, metodi configurati. `-OnlyWithoutMfa` esporta solo chi non è registrato. Sostituisce il vecchio approccio MSOnline, deprecato. | Sola lettura |
| `03-Get-M365RealLastLogonReport.ps1` | Ultimo accesso «reale»: la data più recente fra interattivo e non interattivo. Evita di classificare come fermi gli account di servizio o condivisi, che hanno solo accessi non interattivi. | Sola lettura |
| `04-Get-M365PasswordReport.ps1` | Data dell'ultima modifica password, età in giorni e password impostate per non scadere mai (`DisablePasswordExpiration`). | Sola lettura |
| `05-Get-M365AdminReport.ps1` | Tutte le assegnazioni di ruolo di directory, con il tipo di membro (utente, gruppo, service principal) e il conteggio dei Global Administrator. | Sola lettura |
| `06-Get-M365ManagerReport.ps1` | Il responsabile diretto di ciascun utente, con reparto e mansione; marca `NESSUN MANAGER` chi non ne ha. | Sola lettura |
| `07-Get-M365SignInHistory.ps1` | Gli eventi di accesso degli ultimi N giorni (default 7): utente, data, applicazione, indirizzo IP, città, paese, client ed esito con codice di errore. `-UserPrincipalName` restringe a una sola persona. | Sola lettura |
| `08-Get-M365UserActivitySummary.ps1` | Gli stessi log aggregati per utente (default 30 giorni): accessi totali, accessi falliti, applicazioni distinte, IP distinti, ultimo accesso. Ordinato per accessi falliti. | Sola lettura |
| `09-Remove-M365InactiveUsers.ps1` | Seleziona gli account senza accessi da oltre N giorni (default 90) e, su richiesta, li **disabilita** o li **elimina**. | **SCRIVE** con `-Action Disable` o `-Action Delete`; il default `-Action Report` non modifica nulla, ma chiede comunque uno scope di scrittura |
| `10-Invoke-M365UserOffboarding.ps1` | Offboarding di un singolo UPN in otto passi: blocco accesso, revoca sessioni, reset password a valore casuale, rimozione da tutti i gruppi, rimozione licenze, conversione della casella in Shared, esclusione dalla rubrica (GAL), risposta automatica. | **SCRIVE** (Graph + Exchange Online) |

## Prima di eseguirli

**PowerShell.** Il pacchetto è pensato per PowerShell 5.1 e PowerShell 7, ma nessuno dei dieci script dichiara una versione minima (`#Requires -Version`): se la tua versione è troppo vecchia non ricevi un errore in partenza, lo script si avvia e si rompe più avanti.

**Moduli.** Installa il meta-modulo Graph, non i singoli sottomoduli:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser   # serve solo allo script 10
```

Il `#Requires` in testa agli script non elenca tutti i moduli che usano davvero: `Microsoft.Graph.Reports` (02, 07, 08), `Microsoft.Graph.Identity.DirectoryManagement` (05), `Microsoft.Graph.Groups` (10), `Microsoft.Graph.Users` (01, 03, 04, 06) e `Microsoft.Graph.Users.Actions` (10, per `Set-MgUserLicense` e `Revoke-MgUserSignInSession`) non sono dichiarati. Chi installa solo i sottomoduli dichiarati supera il controllo `#Requires` e poi vede lo script fermarsi a metà con `CommandNotFoundException` — nel caso dello script 10, a offboarding già iniziato.

**Permessi Graph.** Li chiede lo script stesso al primo `Connect-MgGraph`; se il tenant richiede il consenso amministrativo, vanno approvati prima.

| Script | Scope richiesti dal codice |
| --- | --- |
| 01, 03 | `User.Read.All`, `AuditLog.Read.All` |
| 02 | `AuditLog.Read.All`, `UserAuthenticationMethod.Read.All` |
| 04 | `User.Read.All` |
| 05 | `RoleManagement.Read.Directory`, `Directory.Read.All` |
| 06 | `User.Read.All`, `Directory.Read.All` |
| 07, 08 | `AuditLog.Read.All` |
| 09 | `User.ReadWrite.All`, `AuditLog.Read.All` |
| 10 | `User.ReadWrite.All`, `Group.ReadWrite.All`, `Directory.ReadWrite.All`, `Organization.Read.All`, più `Connect-ExchangeOnline` |

**Ruoli.** Per 01-08 basta un ruolo di sola lettura (Global Reader o Security Reader). Lo script 09 richiede User Administrator. Lo script 10 richiede User Administrator e, per i passi 6-8, un ruolo Exchange che permetta `Set-Mailbox` e `Set-MailboxAutoReplyConfiguration` (Exchange Administrator).

**Licenza Entra ID.** `signInActivity` (01, 03, 09) e i sign-in logs (07, 08) richiedono Microsoft Entra ID P1 o P2: nel piano Free non esistono. Vedi la prima e la quinta avvertenza.

## ⚠️ Avvertenze

1. **Lo script 09 tratta «dato assente» come «account inattivo»: con `-Action Delete` può selezionare tutti gli utenti del tenant.** Il filtro è `($null -eq $real) -or ($real -lt $cutoff)`, e `$real` è `$null` non solo quando l'utente non ha mai acceduto, ma ogni volta che `signInActivity` non è disponibile: tenant senza Entra ID P1/P2, amministratore senza `AuditLog.Read.All`, account appena creati, account di servizio o di risorsa. In quei casi ogni utente risulta inattivo e `Remove-MgUser` li elimina uno dopo l'altro. Esegui sempre prima `-Action Report` e controlla la colonna `RealLastSignIn`: se vale `Mai` per tutti, il dato non c'è e la selezione non significa niente.

2. **Senza `-WhatIf` gli script 09 e 10 non chiedono nessuna conferma.** Dichiarano `SupportsShouldProcess` ma non `ConfirmImpact`: il valore predefinito resta sotto la soglia di conferma di PowerShell, quindi `ShouldProcess` passa senza mostrare alcun prompt. `.\09-Remove-M365InactiveUsers.ps1 -Action Delete` elimina in silenzio ogni account selezionato. `-WhatIf` esiste e funziona, ma è opt-in: usalo sempre alla prima esecuzione e aggiungi `-Confirm` quando agisci davvero.

3. **Lo script 09 non esclude gli amministratori né gli account break-glass.** Il ciclo scorre tutti gli utenti senza filtrare ruoli, gruppi o UPN da preservare. Gli account di emergenza non vengono usati per progetto: risultano quindi i primi «inattivi» e i primi a essere disabilitati o eliminati, cioè proprio gli account che servono a rientrare nel tenant quando qualcosa va storto. Leggi il CSV di report riga per riga prima di agire e tieni sotto mano l'elenco dei break-glass.

4. **Il passo 4 dello script 10 rimuove l'utente da ogni gruppo, compresi quelli che assegnano licenze o danno accesso alle risorse**, e il passo 5 rimuove subito dopo tutte le licenze residue. Nessuno dei due si annulla con un comando: le appartenenze vanno ricostruite a mano. Lo script agisce su un solo UPN per esecuzione (il parametro è obbligatorio), quindi non è un'operazione di massa, ma è irreversibile. Attenzione anche al perimetro degli switch: la descrizione parla di switch `-Skip*` al plurale, ma l'unico definito è `-SkipMailbox`, che salta i passi 6-8 su Exchange Online. `-SkipPassword`, `-SkipGroups` e `-SkipLicenses` non esistono: i passi da 1 a 5 non sono saltabili.

5. **Un report può tornare vuoto, o tutto-negativo, per mancanza di licenza o di permessi — e sembrare un buon risultato.** Senza Entra ID P1/P2, o senza `AuditLog.Read.All`, 01 e 03 scrivono `Mai` e `N/D` per tutti e 07 e 08 non restituiscono nessun evento. Una colonna vuota su tutta la popolazione non vuol dire «nessun accesso recente», vuol dire «nessun dato». Prima di concludere qualcosa, confronta il numero di righe esportate con il numero di utenti del tenant: un numeratore senza il suo denominatore inganna.

6. **Lo script 09 chiede uno scope di scrittura anche quando lavora in sola lettura, lo script 10 ne chiede uno più ampio del necessario.** `Connect-MgGraph -Scopes 'User.ReadWrite.All', …` viene eseguito sempre, anche con il default `-Action Report`: per ottenere un semplice elenco devi concedere la scrittura su tutta la directory utenti. Lo script 10 chiede `Directory.ReadWrite.All`, uno degli scope di scrittura più ampi di Graph, che nessuno dei suoi otto passi usa (basterebbero `User.ReadWrite.All`, `GroupMember.ReadWrite.All` e `Organization.Read.All`). Se il consenso lo deve approvare un amministratore, valuta di restringere gli scope nel codice prima di chiederlo.

## Dove finiscono i file

I nove script di report esportano un CSV nella **directory corrente** (il `10`, che esegue l'offboarding, non scrive nessun file: stampa a schermo i passi eseguiti), con un nome che contiene solo la data: `M365-LastLogon-20261029.csv`, `M365-MfaStatus-20261029.csv` e così via. Due conseguenze da tenere a mente:

- **Il file nasce dove si trova il prompt, non dove sta lo script.** Se hai clonato il repository e lanci da dentro il clone, il CSV finisce nel clone. Non committarlo: il `.gitignore` della radice esclude `*.csv`, ma non fidarti del filtro — guarda `git status` prima di aggiungere.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente, senza chiedere.** Il nome contiene la data e non l'ora, e `Export-Csv` scrive senza `-NoClobber`. Se ti serve lo storico, passa `-OutputCsv` con un nome tuo.

Il contenuto non è un semplice elenco di nomi: 07 esporta indirizzo IP, città e paese di ogni accesso e 08 conta gli IP distinti per utente; 02 dice per nome e cognome chi non ha l'MFA; 05 elenca gli amministratori con i loro ruoli; 04 dice quali password non scadono mai. Sono dati personali e, letti insieme, la mappa di che cosa attaccare in quel tenant: tienili fuori dal repository e dalle cartelle condivise, e cancellali quando l'analisi è chiusa.

## Esempi

```powershell
# Chi non ha l'MFA registrato
.\02-Get-M365MfaStatusReport.ps1 -OnlyWithoutMfa

# Accessi di una singola persona negli ultimi 30 giorni
.\07-Get-M365SignInHistory.ps1 -UserPrincipalName mario.rossi@azienda.it -Days 30

# Account fermi da oltre 120 giorni: solo report, nessuna modifica
.\09-Remove-M365InactiveUsers.ps1 -InactiveDays 120

# La stessa selezione in simulazione, prima di disabilitarla davvero
.\09-Remove-M365InactiveUsers.ps1 -InactiveDays 120 -Action Disable -WhatIf

# Offboarding in simulazione: stampa gli otto passi senza eseguirli
.\10-Invoke-M365UserOffboarding.ps1 -UserPrincipalName mario.rossi@azienda.it -WhatIf
```

## Download e supporto

Lo stesso contenuto si scarica come archivio ZIP da [synsphere.it/download/toolkit-powershell-utenti-microsoft-365](https://synsphere.it/download/toolkit-powershell-utenti-microsoft-365/). Se ti serve aiuto: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
