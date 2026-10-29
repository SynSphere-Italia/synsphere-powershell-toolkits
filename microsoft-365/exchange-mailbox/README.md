# Toolkit Exchange Online e caselle Microsoft 365

Dieci report PowerShell di sola lettura che fotografano deleghe, inoltri, dimensioni, hold, risposte automatiche e permessi dei calendari di un tenant Exchange Online, uno per CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Serve a chi deve fare un audit di sicurezza o di capacità su un tenant Exchange Online senza toccarne la configurazione: amministratori IT interni e MSP che gestiscono tenant di terzi. Risponde alle domande che dal portale si leggono una casella per volta: chi ha accesso alle caselle di chi, dove c'è un inoltro automatico attivo, quali caselle sono sotto hold, quanto sono grandi, chi legge i calendari.

Nessuno dei dieci script scrive sul tenant. L'autenticazione è interattiva: si apre il browser, l'MFA funziona, nessuna password sta negli script e ogni script eredita i permessi dell'account che lo lancia.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-M365MailboxPermissionReport.ps1` | Deleghe su tutte le caselle: Full Access, Send As, Send on Behalf. Una riga per coppia casella/delegato, esclusi i permessi di sistema ed ereditati. | Sola lettura |
| `02-Get-M365SharedMailboxPermissionReport.ps1` | Le stesse deleghe, limitate alle sole caselle condivise: chi ha accesso a `info@`, `amministrazione@`, `vendite@`. | Sola lettura |
| `03-Get-M365MailboxesUserHasAccessTo.ps1` | Lookup inverso: dato un utente, su quali caselle altrui ha Full Access o Send As. Utile prima di un offboarding. | Sola lettura |
| `04-Get-M365MailboxSizeReport.ps1` | Dimensione totale, numero di elementi e quota di ogni casella, per capacity planning e per individuare le caselle vicine al limite. | Sola lettura |
| `05-Get-M365ArchiveMailboxSizeReport.ps1` | Caselle con archivio online attivo e dimensione dell'archivio. | Sola lettura |
| `06-Get-M365EmailForwardingReport.ps1` | Caselle con inoltro configurato a livello di casella (destinatario interno o indirizzo SMTP) e se viene mantenuta una copia nella casella. | Sola lettura |
| `07-Get-M365InboxRulesExternalForwarding.ps1` | Regole della posta in arrivo che inoltrano o redirigono verso domini non accettati dal tenant: segnale tipico di casella compromessa. | Sola lettura |
| `08-Get-M365MailboxHoldReport.ps1` | Caselle soggette a un qualsiasi hold: litigation, in-place, retention, compliance tag, delay hold. Da guardare prima di eliminare una casella. | Sola lettura |
| `09-Get-M365AutoReplyReport.ps1` | Caselle con risposta automatica attiva o pianificata, con data di inizio e fine. Individua gli OOF dimenticati e le caselle di ex dipendenti. | Sola lettura |
| `10-Get-M365CalendarPermissionReport.ps1` | Permessi sulla cartella Calendario, inclusi i livelli `Default` e `Anonymous`. Trova la cartella per tipo, quindi funziona anche sui tenant in italiano. | Sola lettura |

## Prima di eseguirli

- **PowerShell**: Windows PowerShell 5.1 o PowerShell 7. Nessuno script dichiara `#Requires -Version`, quindi il minimo non è imposto dal codice: su 5.1 vale l'avvertenza 2.
- **Modulo** (l'unico, dichiarato con `#Requires -Modules` in tutti e dieci gli script):

  ```powershell
  Install-Module ExchangeOnlineManagement -Scope CurrentUser
  ```

- **Permessi**: un account Exchange Online con ruolo *View-Only Recipients* o superiore. Non serve nessuna app registration, nessun permesso Microsoft Graph, nessun permesso Azure: gli script si collegano in modo delegato con `Connect-ExchangeOnline` ed ereditano l'RBAC dell'operatore. Per gli script 07 e 09 quel ruolo potrebbe non bastare: vedi l'avvertenza 4.

## ⚠️ Avvertenze

1. **Uno zero dello script 07 non prova che non ci sia inoltro esterno.** Il controllo riconosce solo i destinatari scritti in forma `SMTP:`. Una regola che punta a un destinatario di directory (reso come `EX:/o=...`) - per esempio un contatto di posta o un mail user il cui recapito è fuori dal tenant - non viene segnalata, e lo script chiude comunque in verde con «Nessuna inbox rule con inoltro esterno trovata». Leggi quel verde come «nessun riscontro fra le regole con destinatario SMTP», non come assenza di inoltro: completa con lo script 06 (inoltro a livello di casella) e con una verifica delle regole create dal client e dei consensi OAuth, che questo script non vede.
2. **Su Windows PowerShell 5.1, con un solo risultato, il conteggio finale si stampa vuoto.** Tutti e dieci gli script chiudono stampando `$report.Count`: su 5.1 un singolo oggetto non espone `.Count` (su PowerShell 7 sì), quindi al posto del numero compare uno spazio. Il caso peggiore è proprio il 07, dove il ritrovamento più probabile è uno solo: il messaggio diventa «ATTENZIONE:  regole inbox con inoltro ESTERNO». Un conteggio vuoto non vuol dire zero: conta le righe del CSV.
3. **Un errore su una singola casella interrompe tutto e il CSV non viene scritto.** Gli script impostano `$ErrorActionPreference = 'Stop'` e non usano `try/catch`: il report si accumula in memoria e viene esportato solo all'ultima riga. Una casella inattiva o soft-deleted, un permesso negato o un throttling fanno perdere tutto il lavoro già raccolto, senza lasciare nemmeno un file parziale. Su tenant grandi conviene procedere a lotti (gli script 03 e 10 accettano `-UserPrincipalName`) e non considerare fatto il report finché il CSV non esiste.
4. **Il ruolo dichiarato non copre con certezza 07 e 09, e dove i permessi mancano il 07 tace.** Il prerequisito unico *View-Only Recipients* arriva dalla documentazione precedente della raccolta; 07 usa `Get-InboxRule` e 09 usa `Get-MailboxAutoReplyConfiguration`, che non sono cmdlet EXO REST come i `Get-EXO*` e plausibilmente richiedono un ruolo più ampio - non è stato verificato sulla documentazione Microsoft. In più, nel 07 la lettura delle regole è chiamata con `-ErrorAction SilentlyContinue`: le caselle su cui l'account non ha i diritti vengono saltate in silenzio. Un report vuoto può quindi significare «non ho potuto leggere», non «non c'è niente». Prima di fidarti di un esito negativo, prova `Get-InboxRule` su una casella di cui conosci le regole.
5. **I CSV prodotti sono la mappa degli accessi del tenant.** Contengono deleghe Full Access e Send As (01, 02, 03), permessi dei calendari (10), indirizzi di inoltro interni ed esterni (06, 07), dimensioni e hold delle caselle (04, 05, 08), periodi di assenza del personale (09). Il percorso di default è relativo, quindi il file nasce nella directory corrente qualunque essa sia: con una console aperta come amministratore finisce in `C:\Windows\System32`. Passa sempre `-OutputCsv` indicando una directory controllata e tratta i file come riservati.
6. **La scansione è per casella anche in script presentati come rapidi.** Oltre a 01, 03, 07 e 10, fanno una chiamata per ogni casella anche 04 e 05 (`Get-EXOMailboxStatistics`) e 09 (`Get-MailboxAutoReplyConfiguration`), che nella documentazione precedente non erano indicati come lenti e non riportano l'avviso nel proprio help. Su un tenant con molte caselle incontrano gli stessi tempi e lo stesso throttling, e per l'avvertenza 3 un errore di throttling fa perdere l'intera esecuzione. Considera lenti 01, 03, 04, 05, 07, 09 e 10.

## Dove finiscono i file

- Il CSV viene scritto nella directory **corrente**, non accanto allo script: il default è un percorso relativo del tipo `.\M365-MailboxPermissions-<aaaammgg>.csv`, quindi il file nasce dove si trova il prompt. Se hai clonato il repository e lanci da lì, il CSV finisce **dentro il clone**: il `.gitignore` nella radice esclude `*.csv`, ma non fidarti e controlla `git status` prima di committare.
- Il nome contiene **solo la data**: una seconda esecuzione nello stesso giorno sovrascrive il file precedente senza chiedere conferma. Se ti serve lo storico, passa `-OutputCsv` con un nome diverso.
- Gli script 06 e 07 scrivono il CSV **solo se trovano qualcosa**: l'assenza del file significa nessun riscontro (con i limiti dell'avvertenza 1), non un'esecuzione fallita.
- Il contenuto è sensibile: deleghe e permessi di cassetta, permessi dei calendari, indirizzi verso cui la posta viene inoltrata, hold di compliance, date di assenza. Conservalo dove conservi i documenti riservati del cliente, non nella cartella di lavoro.

## Esempi

```powershell
.\01-Get-M365MailboxPermissionReport.ps1
.\03-Get-M365MailboxesUserHasAccessTo.ps1 -UserPrincipalName mario.rossi@azienda.it
.\07-Get-M365InboxRulesExternalForwarding.ps1
.\10-Get-M365CalendarPermissionReport.ps1 -UserPrincipalName mario.rossi@azienda.it

# ogni script accetta -OutputCsv: usalo per scrivere fuori dal clone (avvertenza 5)
.\01-Get-M365MailboxPermissionReport.ps1 -OutputCsv C:\Audit\Cliente\deleghe.csv
```

## Download e supporto

Lo stesso contenuto si scarica come archivio ZIP da [synsphere.it/download/toolkit-powershell-exchange-mailbox-microsoft-365](https://synsphere.it/download/toolkit-powershell-exchange-mailbox-microsoft-365/).

Se serve aiuto per leggere i report o per rimediare a quello che mostrano: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
