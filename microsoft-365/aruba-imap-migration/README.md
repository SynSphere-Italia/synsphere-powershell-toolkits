# Migrazione IMAP da Aruba a Microsoft 365

Creare da riga di comando l'endpoint e il batch di migrazione IMAP che spostano la posta delle caselle Aruba su Exchange Online, partendo da un file CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

È rivolto all'amministratore di sistema di una PMI, o al tecnico di un MSP, che deve portare le caselle di un dominio ospitato su Aruba dentro un tenant Microsoft 365 senza ripetere a mano nel portale i passaggi della migrazione IMAP. Lo script esegue in sequenza le quattro operazioni che servono — verifica dei prerequisiti, connessione a Exchange Online, creazione (o riuso) dell'endpoint IMAP, creazione del batch dal CSV — e al termine stampa i comandi per seguire l'avanzamento, completare e rimuovere il batch.

Un limite da sapere prima di cominciare, perché decide come organizzare l'intervento: la migrazione IMAP sposta **solo la posta**, cioè cartelle e messaggi. Contatti, calendari, attività e regole restano dove sono e vanno gestiti a parte.

## Gli script

| File | Che cosa fa | Legge / Scrive |
|------|-------------|----------------|
| `migrazione-aruba-microsoft-365-synsphere.ps1` | Verifica che il modulo `ExchangeOnlineManagement` sia presente e che il CSV abbia le tre colonne richieste da Microsoft, si connette a Exchange Online con autenticazione moderna (riusa la sessione se è già aperta), crea l'endpoint di migrazione IMAP verso `imaps.aruba.it:993` in SSL — o riusa quello esistente se un endpoint con lo stesso nome c'è già — e crea il batch di migrazione passando il CSV a `New-MigrationBatch`. Con `-AutoStart` il batch parte subito; senza, nasce in stato `Stopped`. Alla fine stampa i comandi di monitoraggio e di chiusura del batch. Supporta `-WhatIf` e `-Confirm`. | **SCRIVE** — crea nel tenant un endpoint di migrazione e un batch; con `-AutoStart` avvia anche la copia della posta. Nessun file su disco |

## Prima di eseguirlo

- **PowerShell 5.1 o superiore.** La prima riga dichiara `#Requires -Version 5.1`, quindi su una versione inferiore lo script non parte.
- **Modulo `ExchangeOnlineManagement`**, l'unico richiesto. Installalo prima a mano:

  ```powershell
  Install-Module ExchangeOnlineManagement -Scope CurrentUser
  ```

  Lo script non installa nulla da sé: se il modulo manca si ferma e stampa esattamente questo comando.
- **Permessi: il ruolo Exchange Administrator (gruppo di ruolo `Organization Management`) è sufficiente.** Copre `New-MigrationEndpoint` e `New-MigrationBatch`, cioè tutto quello che lo script crea. Il blocco `.NOTES` dello script chiede «Exchange/Global»: Global Administrator non serve, vedi l'avvertenza 5. L'autenticazione è interattiva via `Connect-ExchangeOnline` (si apre il browser) e funziona con MFA; nel codice non è memorizzata nessuna credenziale.
- **Lato tenant, prima di lanciare**: le caselle di **destinazione** devono esistere e avere una licenza con Exchange Online assegnata, e il dominio personalizzato deve essere già aggiunto e verificato. Il batch non crea utenti.
- **Lato Aruba**: credenziali valide di tutte le caselle di origine, e l'host IMAP corretto. Il default `imaps.aruba.it` non vale per ogni configurazione: alcune usano host dedicati, da verificare nel pannello Aruba del dominio e da passare con `-ArubaImapServer`.

## ⚠️ Avvertenze

1. **Il file di lavoro di questa procedura è un elenco di password in chiaro.** Il CSV che Microsoft richiede per la migrazione IMAP ha intestazione `EmailAddress,UserName,Password`, e la terza colonna contiene la password della casella Aruba di origine: una riga per casella, in chiaro. Lo script non incorpora nessuna credenziale — legge il file che prepari tu e lo passa a `New-MigrationBatch` — ma per tutta la durata della migrazione quel file è sul tuo disco e vale, da solo, l'accesso a tutta la posta del dominio. Tienilo fuori dalla cartella del clone e su disco cifrato, e cancellalo a migrazione conclusa. Il `.gitignore` nella radice esclude `*.csv`, ma non fidarti: non copre un file rinominato con un'altra estensione, né un `git add -f`, né le copie che hai fatto altrove.

2. **Con `-AutoStart` parte tutto il CSV in una volta, senza limite e senza conferma per casella.** Con quello switch il batch viene creato già avviato: niente nel codice conta le righe del CSV o impone un tetto, quindi un file da 300 caselle parte intero. Il blocco `.NOTES` avverte del throttling IMAP di Aruba e raccomanda ondate da 20-50 caselle, ma è un consiglio nell'help, non un controllo nello script. La prima volta esegui **senza** `-AutoStart`: il batch nasce in stato `Stopped`, lo ispezioni con `Get-MigrationBatch` e lo avvii a mano con `Start-MigrationBatch` quando sei pronto. Dividi il CSV in ondate invece di affidarti a un file unico. La simulazione è affidabile: la creazione di endpoint e batch è dentro `ShouldProcess`, quindi `-WhatIf` non crea niente.

3. **Se un endpoint con lo stesso nome esiste, viene riusato senza verificare dove punta.** Lo script cerca l'endpoint per nome (default `Endpoint-Aruba-IMAP`) e, se lo trova, stampa «Endpoint IMAP già esistente: lo riuso» senza confrontare server, porta e tipo di sicurezza con i valori che hai passato. Su un tenant dove quell'endpoint è rimasto da una migrazione precedente, `-ArubaImapServer` e `-ArubaImapPort` non hanno alcun effetto e il batch va a interrogare il vecchio server: l'esecuzione riesce e niente te lo dice. Controlla prima dove punta, oppure passa un `-EndpointName` diverso per ogni migrazione:

```powershell
Get-MigrationEndpoint -Identity 'Endpoint-Aruba-IMAP' | Format-List Identity,RemoteServer,Port,Security
```

4. **Un batch «Completed» non significa che la casella è migrata.** La migrazione IMAP copia cartelle e messaggi e nient'altro: contatti, calendari, attività e regole non sono inclusi, come dichiara l'help dello script. Se leggi lo stato del batch come «migrazione finita» e sposti il record MX, gli utenti si ritrovano la posta e non l'agenda. Pianifica a parte quella parte dell'intervento (esportazione `.pst` da Outlook e importazione, oppure ricreazione lato client) e trattala come un passaggio del cutover, non come una rifinitura.

5. **L'help chiede un ruolo più alto di quello che serve.** Il blocco `.NOTES` prescrive «Account amministratore Exchange/Global con MFA». Per i due cmdlet che lo script usa davvero basta Exchange Administrator: il Global Administrator non è necessario, e seguire l'help alla lettera significa eseguire con il ruolo più privilegiato del tenant un'operazione che non lo richiede. Usa Exchange Administrator e, dove è disponibile PIM, attivalo solo per la durata dell'intervento.

## Dove finiscono i file

**Questo script non esporta niente**: nessun CSV, nessun log, nessun report. Tutto quello che produce lo stampa a schermo, quindi il contenuto della console è l'unico verbale dell'intervento — se ti serve, aprilo con `Start-Transcript` prima di lanciare (il `.gitignore` della radice esclude `transcript*.txt`).

L'unico file in gioco è il CSV **in ingresso**, e su quello vale l'avvertenza 1: nasce dove lo metti tu, contiene password in chiaro e non va committato.

Quello che lo script lascia dietro di sé sta nel tenant, non sul disco, e va chiuso a mano:

- **L'endpoint di migrazione resta** dopo la migrazione, ed è proprio il motivo per cui le esecuzioni successive lo riusano (avvertenza 3).
- **I batch si accumulano.** Il nome predefinito contiene data **e ora** (`Migrazione-Aruba-<aaaammgg-hhmm>`), quindi due esecuzioni lo stesso giorno non si sovrascrivono: creano due batch distinti, entrambi nel tenant. Si chiudono con `Complete-MigrationBatch` e poi `Remove-MigrationBatch`, i comandi che lo script stesso stampa alla fine.
- **Con `-NotificationEmails` il report di fine migrazione viene recapitato da Microsoft** agli indirizzi che indichi: è posta che esce dal tuo controllo e contiene l'esito per casella, quindi scegli indirizzi interni.

## Esempi

```powershell
# Simulazione: verifica prerequisiti e parametri, non crea nulla
.\migrazione-aruba-microsoft-365-synsphere.ps1 -CsvPath .\caselle-aruba.csv `
    -TargetDeliveryDomain "contoso.mail.onmicrosoft.com" -WhatIf

# Prima volta: crea il batch e NON lo avvia (nasce in stato Stopped)
.\migrazione-aruba-microsoft-365-synsphere.ps1 -CsvPath .\caselle-aruba.csv `
    -TargetDeliveryDomain "contoso.mail.onmicrosoft.com" -NotificationEmails "it@contoso.it"

# Crea e avvia subito il batch: leggi prima l'avvertenza 2
.\migrazione-aruba-microsoft-365-synsphere.ps1 `
    -CsvPath .\caselle-aruba.csv `
    -TargetDeliveryDomain "contoso.mail.onmicrosoft.com" `
    -NotificationEmails "it@contoso.it" `
    -AutoStart

# Host IMAP dedicato e nome di endpoint distinto per questa migrazione
.\migrazione-aruba-microsoft-365-synsphere.ps1 -CsvPath .\ondata-1.csv `
    -TargetDeliveryDomain "contoso.mail.onmicrosoft.com" `
    -ArubaImapServer "imaps.dominio-cliente.it" -EndpointName "Endpoint-Aruba-contoso"

# Avvio manuale e monitoraggio (comandi stampati dallo script)
Start-MigrationBatch -Identity 'Migrazione-Aruba-20261029-0930'
Get-MigrationBatch   -Identity 'Migrazione-Aruba-20261029-0930' | Format-List Status,*Count*
```

## Altro

Lo stesso contenuto si scarica come ZIP da [synsphere.it/download/script-powershell-migrazione-aruba-microsoft-365](https://synsphere.it/download/script-powershell-migrazione-aruba-microsoft-365/). Se serve aiuto: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
