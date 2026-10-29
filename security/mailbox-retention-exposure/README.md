# Inventario della conservazione della posta in Microsoft 365

Per quanto tempo questo tenant conserva le email dei dipendenti, chi lo ha deciso e quali conservazioni non hanno una scadenza.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

È rivolto all'amministratore di sistema di una PMI, o al tecnico di un MSP, che deve rispondere a una domanda che il portale non mostra in un punto solo: per quanto tempo la posta dei dipendenti resta nel tenant, e in forza di quale decisione. Lo script raccoglie quattro insiemi di dati e li mette a confronto — i blocchi attivi sulle caselle con la loro durata, le caselle delle persone che hanno lasciato l'azienda, i criteri di conservazione di Microsoft Purview che coprono la posta, la conservazione dei registri di audit — e chiude con l'elenco delle voci da verificare.

Sul tenant non modifica niente: esegue solo cmdlet `Get-*`. Quello che produce è materiale per una decisione da prendere e da dichiarare, non una configurazione da applicare.

## Gli script

| File | Che cosa fa | Legge / Scrive |
|------|-------------|----------------|
| `get-mailbox-retention-exposure-synsphere.ps1` | Legge le caselle utente e condivise e costruisce quattro report. **A)** Litigation hold e blocchi in-place con la durata: segnala le durate `Unlimited` come ILLIMITATE, quelle oltre `-GiorniSoglia` (default 1095 giorni), i blocchi non comunicati all'utente — cioè con `RetentionComment` e `RetentionUrl` entrambi vuoti — e i retention hold attivi. **B)** Caselle inattive, con la data di rimozione e i giorni trascorsi: sono le caselle che sopravvivono alla revoca della licenza perché soggette a un blocco. **C)** Criteri di conservazione di Purview, con l'ambito sulla posta, la durata configurata e l'azione a scadenza. **D)** Audit log retention policy personalizzate e distribuzione di `AuditLogAgeLimit` per casella. Termina con un elenco numerato di voci da verificare, ricavato da quello che ha trovato. Con `-SoloRischi` restringe il dettaglio della sezione A alle sole voci segnalate; con `-SaltaConformita` salta Purview; con `-EsportaCsv` scrive i report su disco. | **Sola lettura** sul tenant: nessun cmdlet di scrittura verso Microsoft 365. Con `-EsportaCsv` crea la cartella indicata e vi scrive fino a quattro file CSV |

## Prima di eseguirlo

- **PowerShell 5.1 o 7+.** Lo script non dichiara `#Requires`: la versione minima è indicata solo in prosa nel blocco `.NOTES`, quindi su una versione più vecchia non si ferma con un messaggio chiaro.
- **Modulo `ExchangeOnlineManagement`**, l'unico richiesto. `Connect-IPPSSession`, che serve per le sezioni C e D, è nello stesso modulo. Installalo prima a mano:

  ```powershell
  Install-Module ExchangeOnlineManagement -Scope CurrentUser
  ```

  Lo script non installa nulla da sé: se il modulo manca, si interrompe e stampa esattamente questo comando.
- **Permessi di sola lettura.** Il minimo pratico, come dichiara il blocco `.NOTES`: per le sezioni A e B il ruolo Exchange **View-Only Recipients** (incluso in View-Only Organization Management); per le sezioni C e D la lettura dei criteri di conservazione e di audit in Microsoft Purview. Il ruolo **Global Reader** di Entra ID copre entrambe le connessioni. L'autenticazione è interattiva (`Connect-ExchangeOnline` e `Connect-IPPSSession`, si apre il browser) e funziona con MFA; nel codice non è memorizzata nessuna credenziale.
- **La lettura della sezione A non è protetta da un fallback.** Se i permessi non bastano per `Get-Mailbox`, lo script termina lì con un errore e non produce nessuna delle quattro sezioni. Le sezioni B, C e D invece hanno ciascuna il proprio `try/catch` e, se la lettura non riesce, vengono saltate con un avviso: vedi l'avvertenza 2.
- **Le audit log retention policy personalizzate della sezione D richiedono Microsoft Purview Audit (Premium).** Senza quel piano la lettura fallisce, lo script lo dichiara a schermo e prosegue. La distribuzione di `AuditLogAgeLimit` per casella viene invece calcolata sempre, perché si ricava dalle caselle già lette.

## ⚠️ Avvertenze

1. **La colonna «Durata» risponde solo per il litigation hold: una casella può essere conservata a tempo indeterminato senza comparire fra le ILLIMITATE.** La durata viene calcolata soltanto quando `LitigationHoldEnabled` è vero; in tutti gli altri casi resta `n/d`. I blocchi che arrivano da un criterio di Purview, da un caso eDiscovery o da un'etichetta di conservazione non vengono espansi: compaiono solo come numero nella colonna `AltriBlocchi` e come vero/falso in `EtichetteConserv`. Quindi la riga di riepilogo «Litigation hold ILLIMITATO: 0» non dimostra che nel tenant non ci sia conservazione senza termine, e una casella con `Durata = n/d` e `AltriBlocchi = 2` significa «due blocchi attivi di cui questo report non mostra la durata». Leggi quelle due colonne insieme alla sezione C, ed espandi a mano i blocchi in-place prima di dichiarare una durata. Allo stesso modo il contatore «Durata oltre soglia» dipende da `-GiorniSoglia`: con il default, uno zero vuol dire «niente oltre i tre anni», non «durate conformi». Abbassa la soglia al periodo che hai davvero dichiarato nell'informativa.

2. **Se la connessione a Security & Compliance non riesce, l'inventario esce a metà e sembra completo.** La connessione è in un `try/catch`: se fallisce, lo script stampa un avviso giallo «Security & Compliance non disponibile» e continua. La sezione C non viene stampata affatto, della D resta solo la distribuzione di `AuditLogAgeLimit`, e nell'esportazione i due CSV corrispondenti non vengono creati. Lo stesso accade, per scelta, con `-SaltaConformita`. La conseguenza è che un risultato senza criteri di conservazione non è un tenant senza criteri di conservazione: è una misura che non è stata fatta — e proprio quella che dice chi ha deciso la durata. Prima di leggere i numeri, verifica che sia comparsa la riga «Security & Compliance: connesso» e conta i file esportati.

3. **Il perimetro è più ristretto di «tutte le caselle del tenant».** La sezione A legge solo le caselle di tipo `UserMailbox` e `SharedMailbox`: le caselle di sala e di risorsa, le caselle di gruppo e gli altri tipi restano fuori, e gli archivi non vengono ispezionati a parte. Il numero «Caselle totali» è quindi il denominatore di quel filtro, non del tenant, e la stessa cosa vale per la distribuzione di `AuditLogAgeLimit` nella sezione D, che è calcolata sulle stesse caselle. Un «nessun blocco da segnalare» o una percentuale ricavata da quel totale si riferiscono a un sottoinsieme: dichiara il perimetro accanto al numero, e controlla separatamente le caselle che non rientrano.

4. **Lo script non dice su quale tenant sta lavorando, e riusa la sessione che trova aperta.** Prima di connettersi prova `Get-OrganizationConfig`: se risponde, stampa «sessione già attiva» e procede, senza indicare dominio o nome dell'organizzazione. Il nome dei CSV esportati contiene soltanto data e ora. Su una console usata per più clienti si finisce per inventariare il tenant della sessione che per caso era aperta, e i file prodotti non sono distinguibili a posteriori. Verifica la sessione prima di lanciare, ed esporta in una cartella che porti il nome del cliente:

```powershell
Get-ConnectionInformation | Format-List Organization, UserPrincipalName
```

5. **Con `-EsportaCsv` finiscono su disco in chiaro dati nominativi di dipendenti ed ex dipendenti.** I quattro CSV contengono indirizzo e nome visualizzato di ogni casella letta, chi ha attivato il litigation hold e in che data, se l'utente è stato informato, le impostazioni di audit casella per casella; e il file delle caselle inattive è, per definizione, l'elenco con nome e indirizzo delle persone che hanno lasciato l'azienda, con la data. `-SoloRischi` non riduce l'esportazione: filtra la tabella a schermo, mentre nel CSV finiscono comunque tutte le caselle lette. Esporta in un percorso controllato fuori dal clone, trattalo come il resto della documentazione del personale e cancellalo quando il controllo è chiuso. Il `.gitignore` della radice esclude `*.csv`, ma non copre un file rinominato con un'altra estensione, né un `git add -f`, né le copie fatte altrove.

6. **Con `-EsportaCsv` lo script crea senza chiedere l'intero albero di cartelle indicato, e due esecuzioni nello stesso minuto si sovrascrivono.** Il percorso viene creato con `New-Item -Force`: un errore di battitura non produce un messaggio, produce una cartella. I nomi dei file contengono data **e ora al minuto**, quindi due esecuzioni nello stesso giorno non si sovrascrivono — due nello stesso minuto sì, senza conferma. L'help dello script dichiara in maiuscolo «QUESTO SCRIPT NON MODIFICA NULLA»: è vero per il tenant, dove esegue solo cmdlet `Get-*`, non per il filesystem locale. Passa un percorso che esiste già e controllalo prima.

## Dove finiscono i file

**Senza `-EsportaCsv` non viene scritto niente**: tutto resta a schermo, e il contenuto della console è l'unico verbale del controllo. Se ti serve conservarlo, aprilo con `Start-Transcript` prima di lanciare — il `.gitignore` della radice esclude `transcript*.txt`.

Con `-EsportaCsv <cartella>` nascono fino a quattro file, in UTF-8 e senza l'intestazione di tipo:

```
blocchi-caselle-<aaaammgg-hhmm>.csv
caselle-inattive-<aaaammgg-hhmm>.csv
criteri-conservazione-<aaaammgg-hhmm>.csv
policy-audit-<aaaammgg-hhmm>.csv
```

Due cose da sapere su quella cartella. La prima: **se il percorso è relativo, i file nascono dove si trova il prompt**, quindi lanciando lo script dal clone del repository il CSV finisce dentro il clone; non committarlo (il `.gitignore` lo esclude, ma controlla prima di un `git add`). La seconda: **un file mancante non è un errore**. Ogni report viene scritto solo se ha almeno una riga, e gli altri sono elencati come «Saltato (nessun dato)» — ma l'assenza di `criteri-conservazione` e `policy-audit` può voler dire anche che le sezioni C e D non sono state eseguite, ed è l'avvertenza 2.

Il contenuto di questi file è sensibile per il motivo detto nell'avvertenza 5: sono dati personali di lavoratori identificati, compresi quelli di chi non è più in azienda.

## Esempi

```powershell
# Inventario completo di tutte le sezioni
.\get-mailbox-retention-exposure-synsphere.ps1

# Solo le voci da verificare: è la modalità per il controllo periodico
.\get-mailbox-retention-exposure-synsphere.ps1 -SoloRischi

# Inventario completo con esportazione dei quattro CSV
.\get-mailbox-retention-exposure-synsphere.ps1 -EsportaCsv "C:\Report"

# Solo sezioni A e B, senza connessione a Purview, soglia abbassata a due anni
.\get-mailbox-retention-exposure-synsphere.ps1 -SaltaConformita -GiorniSoglia 730
```

## Altro

I criteri di lettura dei risultati e i riferimenti normativi stanno nell'articolo che lo script stesso richiama: [Conservazione delle email dei dipendenti, i limiti di Microsoft 365 nelle PMI](https://synsphere.it/notizie/conservazione-email-dipendenti-limiti-microsoft-365-pmi).

Lo stesso contenuto si scarica come ZIP da [synsphere.it/download/script-powershell-conservazione-email-microsoft-365](https://synsphere.it/download/script-powershell-conservazione-email-microsoft-365/). Se serve aiuto: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
