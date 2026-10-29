# Toolkit audit e sicurezza della posta Microsoft 365

Dieci report PowerShell di sola lettura che estraggono da Exchange Online i dati di audit della posta — volumi per indirizzo, esiti del filtro, eliminazioni, invii con delega, accessi non autorizzati, regole, connettori, quarantena — uno per CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Serve a chi deve fare un assessment della posta su un tenant Microsoft 365, documentare un incidente o rispondere a una contestazione interna: amministratori IT e MSP che lavorano su tenant propri o di terzi. Mette per iscritto quello che dal portale si guarda una schermata per volta: quanto traffico passa da ciascun indirizzo, che cosa ha fermato il filtro anti-spam e anti-phishing, chi ha cancellato quali email, chi ha inviato a nome di chi, chi è entrato nella casella di qualcun altro, quali regole di trasporto e quali connettori sono configurati.

Nessuno dei dieci script modifica il tenant: non c'è un solo cmdlet con verbo di scrittura, l'unica scrittura è il CSV sul disco locale. L'autenticazione è interattiva con `Connect-ExchangeOnline`: si apre il browser, l'MFA funziona, nessuna password sta negli script e ogni script eredita i permessi dell'account che lo lancia.

Lo script 07 si esegue per primo e non dà solo: dice se il mailbox auditing è attivo, cioè se gli audit 03-06 hanno qualcosa da leggere (avvertenza 2).

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-M365MailTrafficReport.ps1` | Messaggi inviati e ricevuti da ciascun indirizzo nella finestra richiesta, aggregando il message trace. `Get-MessageTrace` copre al massimo gli ultimi 10 giorni: per finestre più lunghe servono il report storico del portale o `Get-MessageTraceV2`. | Sola lettura |
| `02-Get-M365MailFlowStatusReport.ps1` | Riepilogo dei messaggi per tipo (GoodMail, Spam, Malware, Phish, EdgeBlockSpam) e per direzione. Una crescita anomala dell'Outbound Spam/Malware è il segnale tipico di un account compromesso. | Sola lettura |
| `03-Get-M365EmailDeletionAudit.ps1` | Operazioni di eliminazione dall'Unified Audit Log (SoftDelete, HardDelete, MoveToDeletedItems): chi ha cancellato cosa e quando, con l'oggetto degli elementi colpiti. Per contestazioni e sospetta cancellazione dolosa. | Sola lettura |
| `04-Get-M365SendAsAudit.ps1` | Operazioni SendAs: chi ha inviato a nome di chi, con data e oggetto del messaggio. Per verificare l'uso, lecito o meno, delle deleghe di invio. | Sola lettura |
| `05-Get-M365SharedMailboxSendingAudit.ps1` | Invii dalle caselle condivise (SendAs e SendOnBehalf) con il mittente reale dietro `info@` o `vendite@`. Filtra gli eventi di audit sull'elenco delle shared mailbox del tenant. | Sola lettura |
| `06-Get-M365NonOwnerMailboxAccess.ps1` | Accessi alle caselle (MailItemsAccessed) con LogonType diverso da Owner e utente diverso dal proprietario: chi ha aperto la casella di chi, come Admin o come Delegate. | Sola lettura |
| `07-Get-M365MailboxAuditConfig.ps1` | Elenco delle caselle con stato dell'auditing e `AuditLogAgeLimit`, ordinato per evidenziare quelle con auditing disabilitato. È la verifica di prerequisito degli script 03-06. | Sola lettura |
| `08-Get-M365TransportRulesReport.ps1` | Regole di trasporto del tenant con stato, priorità, modalita' (Enforce/Audit) e descrizione, per rivedere redirect e BCC nascosti e i bypass del filtro. | Sola lettura |
| `09-Get-M365MailConnectorsReport.ps1` | Connettori inbound e outbound con stato, tipo, domini e smart host. Un connettore in uscita non riconosciuto è una tecnica nota di Business Email Compromise. | Sola lettura |
| `10-Get-M365QuarantineReport.ps1` | Messaggi in quarantena con mittente, destinatari, tipo (Spam, Phish, Malware, HighConfPhish, Bulk), oggetto e stato di rilascio. È l'unico script che pagina i risultati con un ciclo su `-Page`. | Sola lettura |

## Prima di eseguirli

- **PowerShell**: Windows PowerShell 5.1 o PowerShell 7. Nessuno dei dieci script dichiara `#Requires -Version`, quindi il minimo non è imposto dal codice.
- **Modulo** (l'unico, dichiarato con `#Requires -Modules` in tutti e dieci gli script):

  ```powershell
  Install-Module ExchangeOnlineManagement -Scope CurrentUser
  ```

  Non serve nient'altro: zero riferimenti a Microsoft Graph, ad `Az` o a MSOnline/AzureAD, nessuna app registration, nessun certificato, nessun permesso applicativo.

- **Permessi**: ruoli di sola lettura di Exchange Online, diversi da script a script. Non serve un amministratore globale e non va usato: nessuno di questi dieci script ha bisogno di privilegi di scrittura. Il ruolo minimo, script per script:

| Script | Ruolo minimo |
| --- | --- |
| 01, 07 | View-Only Recipients |
| 02 | Reporting / Security Reader |
| 03, 04, 06 | View-Only Audit Logs |
| 05 | View-Only Audit Logs **e** View-Only Recipients (avvertenza 4) |
| 08, 09 | View-Only Configuration |
| 10 | Security Reader con accesso alla quarantena |

**Un prerequisito che non è un permesso**: il mailbox auditing deve essere attivo sulle caselle, altrimenti gli script 03-06 non hanno nulla da leggere. Verificalo con il 07 prima di tutto il resto.

## ⚠️ Avvertenze

1. **Cinque report su dieci si fermano a 5000 righe e non lo dicono.** Gli audit 03, 04, 05 e 06 chiamano `Search-UnifiedAuditLog` con `-ResultSize 5000` e senza `-SessionCommand ReturnLargeSet`: 5000 è il tetto di una singola chiamata e il troncamento è silenzioso. Il caso peggiore è il 06, perché `MailItemsAccessed` è l'operazione più voluminosa dell'Unified Audit Log e su un tenant reale sette giorni superano regolarmente i 5000 eventi — ed è proprio lo script che si usa per cercare accessi non autorizzati. Nel 05 il taglio è doppiamente insidioso: i 5000 eventi grezzi vengono *poi* filtrati sulle sole caselle condivise, quindi il report finale può avere tre righe e sembrare esaustivo mentre il campione di partenza era già tagliato. Lo script 01 arriva allo stesso effetto per un'altra via: `Get-MessageTrace -PageSize 5000` senza ciclo su `-Page` legge solo la prima pagina, quindi i suoi `Sent` e `Received` sono un campione, non i volumi del periodo. **Non dedurre «nessun accesso anomalo» o «nessuna cancellazione sospetta» da questi output.** Se il conteggio stampato a fine esecuzione è esattamente 5000, il dato è troncato: restringi la finestra con `-Days` e ripeti su intervalli più corti. Lo script 10 pagina correttamente e non ha questo limite.

2. **Se il mailbox auditing è spento, gli script 03-06 restituiscono zero righe senza errore.** L'esecuzione finisce regolarmente, il CSV viene scritto e il numero stampato è zero: indistinguibile da «non è successo niente». Dal 2019 l'auditing è attivo per impostazione predefinita a livello di organizzazione, ma può essere stato disabilitato sulle singole caselle. Esegui prima il 07: se trova caselle con auditing disabilitato, gli zeri degli audit non valgono per quelle caselle, e va detto nel report che consegni. Uno zero senza il suo denominatore non è un risultato.

3. **I CSV che produci sono dati personali, e in quattro casi contengono contenuto delle email, non metadati.** Lo script 06 scrive in chiaro chi ha aperto la casella di chi (colonne `Accessor` e `Mailbox`); gli script 03, 04, 05 e 10 esportano l'oggetto dei messaggi (`Items`, `Subject`), che è contenuto della comunicazione. Su dipendenti italiani un file così ricade nel GDPR e nell'art. 4 dello Statuto dei Lavoratori sul controllo a distanza: la finalita' va dichiarata prima, serve l'informativa preventiva agli interessati e, secondo il caso, l'accordo sindacale o l'istanza all'Ispettorato del lavoro. Prima di eseguire 03-06 verifica di avere la base per farlo, poi limita la conservazione dei CSV al tempo necessario.

4. **Lo script 05 chiede un ruolo che il suo help non dichiara, e si interrompe prima di scrivere qualsiasi cosa.** Le `.NOTES` nominano solo *View-Only Audit Logs*, ma lo script chiama anche `Get-EXOMailbox -RecipientTypeDetails SharedMailbox`, che richiede *View-Only Recipients*. Con `$ErrorActionPreference = 'Stop'` e senza `try/catch`, chi ha assegnato esattamente i permessi documentati vede l'esecuzione morire su quella riga: nessun CSV, nessun output parziale. Assegna entrambi i ruoli.

5. **Nessuno dei dieci script chiude la sessione: lanciandoli tutti di seguito, gli ultimi falliscono.** `Connect-ExchangeOnline` è presente in dieci script su dieci, `Disconnect-ExchangeOnline` in nessuno. Dieci esecuzioni nella stessa console aprono dieci sessioni di Exchange Online e superano il limite di sessioni PowerShell concorrenti per utente; l'errore che ne risulta parla di quota e si legge facilmente come un problema di permessi, mandando la diagnosi fuori strada. Chiudi la sessione a mano con `Disconnect-ExchangeOnline -Confirm:$false` fra uno script e l'altro, o almeno quando hai finito: riprovare senza chiuderla non risolve. Vale anche quando uno script si interrompe a metà, perché senza `try/finally` la sessione resta comunque aperta.

6. **`-Days` è validato in un solo script su sette.** Gli help di 02, 03, 04, 05, 06 e 10 dichiarano un massimo — 90 giorni per gli audit, circa 30 per la quarantena per via della retention — ma il parametro non ha nessun attributo di validazione: un `-Days 365` non viene respinto, passa all'API e produce o un errore oscuro o una finestra silenziosamente ridotta. Solo il 01 valida davvero (`[ValidateRange(1, 10)]`, il limite di `Get-MessageTrace`). Resta nei massimi dichiarati negli help: una finestra accettata non è una finestra coperta.

## Dove finiscono i file

- Il CSV viene scritto nella directory **corrente**, non accanto allo script: il default è un percorso relativo del tipo `.\M365-NonOwnerAccess-<aaaammgg>.csv`, quindi il file nasce dove si trova il prompt. Se hai clonato il repository e lanci da lì, il CSV finisce **dentro il clone**: il `.gitignore` nella radice esclude `*.csv`, ma non fidarti e controlla `git status` prima di committare. E se la console è stata aperta come amministratore, la directory corrente è spesso `C:\Windows\System32`.
- Il nome di default contiene **solo la data** e `Export-Csv` è chiamato senza `-NoClobber` in tutti e dieci gli script: una seconda esecuzione nello stesso giorno sovrascrive il report precedente senza chiedere niente. Se ti serve lo storico, o se stai rifacendo un'estrazione per confrontarla con la prima, passa `-OutputCsv` con un nome diverso.
- **Il contenuto è sensibile**, e in parte è contenuto delle comunicazioni: chi ha aperto la casella di chi (06), gli oggetti delle email cancellate (03), inviate con delega (04), inviate dalle caselle condivise (05) e messe in quarantena (10), mittenti e destinatari della posta bloccata (10), i volumi di traffico indirizzo per indirizzo (01), le regole di trasporto e i connettori del tenant (08, 09), l'elenco completo delle caselle (07). Tutti e dieci gli script accettano `-OutputCsv`: usalo per scrivere in una cartella dedicata con ACL ristrette, dove conservi i documenti riservati del cliente, non nella cartella di lavoro. Vedi anche l'avvertenza 3.

## Esempi

```powershell
# prima di tutto: l'auditing e' attivo? (avvertenza 2)
.\07-Get-M365MailboxAuditConfig.ps1

.\02-Get-M365MailFlowStatusReport.ps1 -Days 30
.\03-Get-M365EmailDeletionAudit.ps1 -Days 30
.\06-Get-M365NonOwnerMailboxAccess.ps1 -Days 14
.\09-Get-M365MailConnectorsReport.ps1

# ogni script accetta -OutputCsv: usalo per scrivere fuori dal clone (avvertenze 3 e 6)
.\06-Get-M365NonOwnerMailboxAccess.ps1 -Days 14 -OutputCsv C:\Audit\Cliente\accessi-non-owner.csv
```

## Download e supporto

Lo stesso contenuto si scarica come archivio ZIP da [synsphere.it/download/toolkit-powershell-email-security-microsoft-365](https://synsphere.it/download/toolkit-powershell-email-security-microsoft-365/).

Se serve aiuto per leggere i report, o per rimediare a quello che mostrano: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
