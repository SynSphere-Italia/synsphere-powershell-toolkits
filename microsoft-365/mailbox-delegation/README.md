# Delega di una cassetta Microsoft 365

Assegnare o revocare da riga di comando, in modo ripetibile e con un log, le quattro deleghe di una cassetta Exchange Online.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

È rivolto all'amministratore di sistema di una PMI o al tecnico di un MSP che deve configurare, o smontare in fase di offboarding, la delega di una casella su un tenant Microsoft 365 senza passare dal portale. Lo scenario di partenza è l'assistente (o la segreteria) che gestisce la posta di un responsabile: lo script lo copre con due preset, e per i casi diversi espone i quattro permessi uno per uno.

I quattro permessi, come li descrive lo script:

- **FullAccess** — il delegato apre, legge e gestisce la casella. Da solo **non** consente di inviare.
- **SendAs** — il delegato invia *come* il responsabile: il destinatario vede solo il responsabile.
- **SendOnBehalf** — il delegato invia *per conto* del responsabile: resta tracciabile chi ha scritto.
- **InboxEditor** — permesso di sola cartella (per esempio la Posta in arrivo), senza accesso al resto della casella.

I due preset: `-Preset Assistente` = FullAccess + SendOnBehalf; `-Preset AssistenteComeMe` = FullAccess + SendAs. Per leggere **e** inviare serve FullAccess insieme a SendAs oppure a SendOnBehalf: l'accesso completo da solo non basta per inviare.

## Gli script

| File | Che cosa fa | Legge / Scrive |
|------|-------------|----------------|
| `Set-MailboxDelegation.ps1` | Assegna o revoca i quattro permessi di delega su una cassetta. Si connette a Exchange Online, verifica che casella e delegato esistano, applica solo quello che manca e al termine ristampa lo stato dei tre permessi principali. Con `-Remove` revoca invece di assegnare (offboarding). Supporta `-WhatIf` e `-Confirm` e scrive un log con timestamp. | **SCRIVE** — permessi della cassetta e un file di log |
| `Esempi.ps1` | Sette invocazioni pronte da adattare: preset assistente, invio trasparente, permessi su misura, sola cartella, simulazione, offboarding, delega in massa da CSV. Tutte le righe sono commentate, quindi eseguire il file così com'è non fa nulla. | Sola lettura come distribuito; le righe che si decommentano **SCRIVONO**, perché richiamano lo script principale |

## Prima di eseguirli

- **PowerShell 5.1 oppure 7.** È quanto dichiara il blocco `.NOTES`; negli script non c'è nessuna direttiva `#Requires`, quindi nulla blocca l'esecuzione su una versione diversa.
- **Modulo ExchangeOnlineManagement**, l'unico richiesto. Installalo prima a mano, per il motivo spiegato nell'avvertenza 6:

  ```powershell
  Install-Module ExchangeOnlineManagement -Scope CurrentUser
  ```

- **Permessi: il gruppo di ruolo Exchange RBAC `Recipient Management` è sufficiente.** Copre tutti i cmdlet effettivamente usati: `Add-MailboxPermission` / `Remove-MailboxPermission`, `Add-RecipientPermission` / `Remove-RecipientPermission`, `Set-Mailbox -GrantSendOnBehalfTo`, `Add-MailboxFolderPermission` / `Set-MailboxFolderPermission` / `Remove-MailboxFolderPermission` e i `Get-*` della verifica finale. Il ruolo Exchange Administrator funziona ma è più ampio del necessario; dove è disponibile PIM, attiva il ruolo solo per la durata dell'intervento.
- **Nient'altro serve**: nessuno scope Microsoft Graph, nessun ruolo Entra ID, nessuna app registration, nessun certificato. L'autenticazione è interattiva via `Connect-ExchangeOnline`; con `-AdminUpn` indichi quale account usare. Nel codice non è memorizzata nessuna credenziale.

## ⚠️ Avvertenze

1. **`SendOnBehalf` può essere saltato in silenzio, nei due versi.** Il controllo che evita di riapplicare una delega già presente confronta solo la parte locale dell'indirizzo, come sottostringa, contro le voci di `GrantSendOnBehalfTo` (che Exchange restituisce come nome canonico basato sul nome visualizzato, non come indirizzo SMTP). In assegnazione: con `-Delegate anna@contoso.it` e una voce esistente `Gianna Verdi`, «anna» è sottostringa di «Gianna», lo script scrive «SendOnBehalf: già presente, salto» e **non concede** la delega richiesta. In revoca, cioè in offboarding: con `-Delegate s.rossi@contoso.it` e la voce `Stefano Rossi`, «s.rossi» non aggancia, lo script scrive «SendOnBehalf: non presente, niente da rimuovere» e **non revoca** un permesso che esiste, quindi l'assistente uscente continua a inviare per conto. In nessuno dei due casi compare un errore, e la verifica finale non ti salva: stampa `GrantSendOnBehalfTo`, che risulta popolato perché contiene gli *altri* delegati. Controlla a mano, cercando la riga del tuo delegato:

```powershell
Get-Mailbox -Identity direttore@contoso.it | Select-Object -ExpandProperty GrantSendOnBehalfTo
```

2. **L'esempio etichettato «solo lettura» concede l'accesso completo.** In `Esempi.ps1` l'esempio 3 si intitola «Permessi su misura (solo lettura, niente invio)» ma passa `-Permission FullAccess`. FullAccess non è sola lettura: consente di aprire, leggere, cancellare, spostare e creare elementi nella casella, e quello che resta escluso è solo l'invio. Chi copia quella riga per uno stagista gli consegna il controllo della casella. Per una delega di sola consultazione servirebbe un permesso di cartella con diritto Reviewer, che il kit non espone: `-Permission InboxEditor` concede **Editor**, non Reviewer.

3. **`-Remove` revoca subito, non chiede conferma.** `-WhatIf` e `-Confirm` sono supportati davvero, ma `ConfirmImpact` è impostato a `Medium` mentre il `$ConfirmPreference` predefinito di PowerShell è `High`: nessun prompt compare, a meno che tu non passi esplicitamente `-Confirm`. `-Permission FullAccess,SendAs,SendOnBehalf -Remove` toglie le tre deleghe in un colpo senza chiedere niente. Esegui prima la stessa riga con `-WhatIf`: la simulazione è affidabile, tutte le chiamate che scrivono sono dentro `ShouldProcess`.

4. **Sul permesso di cartella il log dichiara «OK» anche quando non ha rimosso nulla.** Nel ramo `-Remove` di `InboxEditor` l'errore di `Remove-MailboxFolderPermission` è soppresso con `-ErrorAction SilentlyContinue`, e la riga di log «Permesso cartella rimosso» viene scritta in ogni caso: se il permesso non c'era, se la cartella non esiste o se il nome è sbagliato, leggi comunque un successo. Il caso più frequente è proprio il nome: il default è `Posta in arrivo`, che su un tenant in inglese non esiste, quindi su un tenant EN il permesso di cartella non viene né assegnato né revocato e nessun errore te lo dice. Passa `-Folder` nella lingua del tenant (`-Folder 'Inbox'`) e verifica l'esito con `Get-MailboxFolderPermission -Identity 'direttore@contoso.it:\Inbox'`.

5. **L'esempio di delega in massa da CSV gira senza simulazione e senza rete di sicurezza.** L'esempio 7 di `Esempi.ps1` cicla un `Import-Csv .\deleghe.csv` e per ogni riga applica il preset `Assistente`, cioè FullAccess + SendOnBehalf: nessun `-WhatIf`, nessun `try/catch`, nessun controllo delle colonne, nessun riepilogo finale. Un CSV con una colonna sbagliata, una riga di troppo o un indirizzo errato concede accesso completo a caselle non previste, e il ciclo va avanti senza fermarsi. Eseguilo due volte: la prima aggiungendo `-WhatIf` alla chiamata interna e leggendo tutte le coppie che verrebbero toccate, poi quella reale.

6. **Se il modulo manca, lo script lo installa da PowerShell Gallery senza chiedertelo.** Alla prima connessione esegue `Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber`: `-Force` sopprime il prompt di repository non attendibile (PSGallery è Untrusted per impostazione predefinita) e `-AllowClobber` autorizza a sovrascrivere nomi di comando già esposti da altri moduli presenti sulla tua workstation. Installa il modulo prima, a mano, con il comando della sezione precedente: così lo script non installa niente.

## Dove finiscono i file

Questo kit non esporta CSV. L'unico file che scrive è un log di testo, e su quello valgono quattro avvertenze.

- **Nasce dove si trova il prompt, non accanto allo script.** Il percorso predefinito è la directory corrente più `Set-MailboxDelegation.log`. `Esempi.ps1` consiglia di aprire PowerShell come amministratore, e una console elevata parte da `C:\Windows\System32`: il log finisce là dentro. Se hai clonato il repository e lanci dalla cartella del clone, il log nasce **dentro il clone**: il `.gitignore` della radice esclude `*.log`, ma controlla prima di committare invece di fidarti. Passando `-LogPath` con un percorso esplicito il dubbio non c'è.
- **Il nome è fisso e non contiene la data**: le esecuzioni successive **aggiungono in coda** allo stesso file invece di sovrascriverlo. Il log cresce e mescola interventi diversi su caselle diverse; se vuoi un file per intervento devi passare `-LogPath`.
- **«Log salvato in: …» viene stampato comunque.** La scrittura usa `-ErrorAction SilentlyContinue`: se il percorso non è scrivibile l'errore non si vede, e a fine esecuzione leggi una conferma di salvataggio per un file che non esiste. Verifica che il file ci sia davvero.
- **Il log contiene dati personali.** Vi finiscono l'indirizzo della casella, l'indirizzo del delegato e, nello stato finale, l'elenco completo di `GrantSendOnBehalfTo`: quindi anche gli altri utenti che hanno la delega su quella casella. Trattalo come un documento del tenant, non come uno scarto.

## Esempi

```powershell
# Scenario assistente classico: accesso completo + invia per conto
.\Set-MailboxDelegation.ps1 -Mailbox direttore@contoso.it -Delegate segreteria@contoso.it -Preset Assistente

# Accesso completo + invia come, senza automapping
.\Set-MailboxDelegation.ps1 -Mailbox ceo@contoso.it -Delegate ufficio@contoso.it -Preset AssistenteComeMe -AutoMapping $false

# Simula l'assegnazione del solo permesso sulla Posta in arrivo
.\Set-MailboxDelegation.ps1 -Mailbox direttore@contoso.it -Delegate stage@contoso.it -Permission InboxEditor -WhatIf

# Offboarding: revoca i permessi. Provalo prima con -WhatIf, vedi l'avvertenza 3
.\Set-MailboxDelegation.ps1 -Mailbox direttore@contoso.it -Delegate segreteria@contoso.it -Permission SendAs,FullAccess -Remove
```

## Altro

Lo stesso contenuto si scarica come ZIP da [synsphere.it/download/script-powershell-delega-cassetta-microsoft-365](https://synsphere.it/download/script-powershell-delega-cassetta-microsoft-365/); la guida passo passo allo scenario è [qui](https://synsphere.it/notizie/delegare-cassetta-mail-microsoft-365-assistente-pmi). Se serve aiuto: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
