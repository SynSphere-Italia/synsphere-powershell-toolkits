# Defender & Security Posture Toolkit

Dieci report di sola lettura che misurano la postura di sicurezza di un tenant Microsoft 365 e Defender e la esportano in CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

La raccolta è rivolta ad amministratori Microsoft 365 e MSP che devono produrre evidenze periodiche e ripetibili sulla sicurezza di un tenant: il report mensile al cliente, il materiale da allegare a un audit, la fotografia dello stato dei controlli da cui parte l'analisi dei rischi richiesta dalla NIS2. Ogni script interroga Microsoft Graph su un'area diversa — Secure Score attuale, storico e azioni di miglioramento, avvisi e incidenti Defender, utenti a rischio e rilevamenti di Entra ID Protection, copertura MFA e SSPR per utente, inventario delle policy di accesso condizionale — stampa un riepilogo a video ed esporta un CSV.

Nessuno dei dieci script modifica la configurazione del tenant: sono tutti `Get-*` più l'esportazione del file, e tutti gli scope Graph che chiedono sono `.Read.All`. Il rischio, come spiega la sezione avvertenze, è di leggere male il risultato — non di guastare l'ambiente.

La raccolta è complementare a [email-security](../email-security/): qui si guarda la postura (punteggi, avvisi, identità, MFA, accesso condizionale), non il traffico di posta né la quarantena.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-SecureScoreCurrent.ps1` | L'ultimo rilevamento del Microsoft Secure Score: punteggio corrente, massimo e percentuale, con la data, gli utenti attivi e quelli licenziati. È l'indicatore sintetico della postura Microsoft 365 e Defender. | Sola lettura |
| `02-Get-SecureScoreTrend.ps1` | Gli ultimi N rilevamenti giornalieri del Secure Score (`-Days`, default 30) con punteggio, massimo e percentuale per data: serve a capire se la postura sta migliorando o peggiorando. | Sola lettura |
| `03-Get-SecureScoreImprovementActions.ps1` | Incrocia i punteggi per controllo dell'ultimo Secure Score con il massimo di ogni control profile e calcola il gap, cioè i punti ancora ottenibili. Ordina dal gap maggiore al minore: è la lista di priorità concreta. | Sola lettura |
| `04-Get-SecurityAlerts.ps1` | Gli avvisi dell'API unificata Microsoft 365 Defender, di default solo quelli non ancora risolti (`-IncludeResolved` include anche i risolti), con severità, stato, titolo, categoria, prodotto di origine e data. Vedi l'avvertenza 1 sull'ordinamento. | Sola lettura |
| `05-Get-SecurityIncidents.ps1` | Gli incidenti, cioè i raggruppamenti correlati di avvisi, di default solo quelli non risolti (`-IncludeResolved`), con severità, stato, classificazione, determinazione, assegnatario e data. È la vista di alto livello per il monitoraggio. | Sola lettura |
| `06-Get-RiskyUsers.ps1` | Gli utenti con un livello di rischio segnalato da Entra ID Protection (login anomali, credenziali trapelate), di default solo quelli non ancora bonificati (`-IncludeRemediated`), con livello e stato del rischio. | Sola lettura |
| `07-Get-RiskDetections.ps1` | I singoli rilevamenti di rischio — viaggio impossibile, IP anonimo, credenziali trapelate — con tipo, livello, stato, utente, indirizzo IP e città/paese. `-Top` limita il numero di eventi recuperati, default 200. | Sola lettura |
| `08-Get-MfaRegistrationReport.ps1` | Usa il report ufficiale dei metodi di autenticazione per elencare, utente per utente, se è capace e registrato per MFA e SSPR, quali metodi ha registrato e se è amministratore. `-OnlyGaps` lascia solo gli utenti non capaci di MFA. | Sola lettura |
| `09-Get-ConditionalAccessPolicies.ps1` | Ogni policy di accesso condizionale con stato (attiva, solo report, disattivata), controlli di concessione richiesti, operatore e date di creazione e modifica: documenta le regole che proteggono gli accessi. | Sola lettura |
| `10-Get-SecurityPostureSummary.ps1` | Il cruscotto unico: Secure Score, avvisi aperti high e medium, incidenti aperti e copertura MFA riuniti in una riga di sintesi datata, comoda da allegare a un report periodico. Vedi le avvertenze 2 e 3. | Sola lettura |

## Prima di eseguirli

**PowerShell 5.1 oppure PowerShell 7.** È l'indicazione che accompagnava la raccolta; nessuno dei dieci script dichiara una versione minima con `#Requires -Version`, quindi su un host più vecchio non c'è niente che si fermi da sé.

**Microsoft Graph PowerShell SDK, e i `#Requires` sono incompleti.** Tutti e dieci dichiarano alla prima riga soltanto `Microsoft.Graph.Authentication`, che fornisce `Connect-MgGraph` e nient'altro: i cmdlet `Get-Mg*` che poi usano vivono in altri sottomoduli. Se installi solo ciò che il `#Requires` dichiara, il primo `Get-Mg*` risponde «termine non riconosciuto» a metà script, invece dell'errore pulito che `#Requires` darebbe all'avvio. La via breve è il meta-modulo:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

In alternativa, soltanto i sottomoduli effettivamente usati:

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Security, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Reports -Scope CurrentUser
```

Quale script usa cosa: `Microsoft.Graph.Authentication` tutti e dieci; `Microsoft.Graph.Security` 01, 02, 03, 04, 05 e 10; `Microsoft.Graph.Identity.SignIns` 06, 07 e 09; `Microsoft.Graph.Reports` 08 e 10.

**Autenticazione e consenso.** Ogni script chiama `Connect-MgGraph` con i soli scope che gli servono. Sono tutti delegati e tutti in sola lettura, ma richiedono il consenso di un amministratore: al primo lancio compare la schermata di consenso per gli scope di quello script.

| Script | Scope Graph richiesti |
| --- | --- |
| 01, 02, 03 | `SecurityEvents.Read.All` |
| 04 | `SecurityAlert.Read.All` |
| 05 | `SecurityIncident.Read.All` |
| 06 | `IdentityRiskyUser.Read.All` |
| 07 | `IdentityRiskEvent.Read.All` |
| 08 | `AuditLog.Read.All` |
| 09 | `Policy.Read.All` |
| 10 | `SecurityEvents.Read.All`, `SecurityAlert.Read.All`, `SecurityIncident.Read.All`, `AuditLog.Read.All` |

**Ruolo Entra: Security Reader.** Per il Secure Score (01, 02, 03), per le policy di accesso condizionale (09) e per il report di registrazione MFA (08, 10) Security Reader è esattamente il ruolo minimo documentato da Microsoft: non serve nulla di più. Per gli endpoint di Identity Protection (06, 07) non abbiamo verificato il ruolo separatamente, quindi se uno dei due risponde con un accesso negato è lì che va cercata la causa. Un caveat che riguarda 09: con Security Reader le policy di accesso condizionale si leggono solo nelle «standard properties», quindi l'inventario può contenere meno campi di quanti ne mostri il portale, senza alcun errore e senza che il CSV lo segnali.

**Licenze.** I dati completi di Identity Protection (06, 07) richiedono Microsoft Entra ID P2. Secure Score e Identity Protection dipendono dalle licenze attive nel tenant: se un valore risulta vuoto, il piano è la prima cosa da verificare — e vedi l'avvertenza 3, perché quel caso non si presenta sempre come un errore.

**Si fermano al primo errore.** Tutti e dieci impostano `$ErrorActionPreference = 'Stop'` e nessuno ha un `try/catch`, mentre `Export-Csv` è fra le ultime istruzioni. Se una chiamata Graph fallisce — un permesso mancante, un throttling — l'esecuzione si interrompe prima della scrittura e non resta nemmeno un file parziale. Lanciali uno alla volta e rilancia quello che si è fermato dopo aver sistemato la causa.

## ⚠️ Avvertenze

1. **`04` ordina gli avvisi al contrario di quello che promette: a video compaiono i venti MENO gravi.** L'ordinamento è `Sort-Object @{ E = { $sevOrder[[string]$_.Severita] } }, Creato -Descending`, e in PowerShell `-Descending` si applica a **tutte** le chiavi di `Sort-Object`, non solo all'ultima. Poiché la mappa delle severità è `@{ high = 0; medium = 1; low = 2; informational = 3 }`, l'ordine decrescente mette `informational` per primo e `high` per ultimo: il `Select-Object -First 20` mostra quindi i venti avvisi meno gravi, e il CSV viene esportato nello stesso ordine invertito, mentre la `.DESCRIPTION` dichiara «ordina per severità per la triage». Lo script fa l'opposto, sullo schermo e nel file. Non usare la tabella a video di 04 per decidere da dove cominciare: riordina il CSV per la colonna `Severita` (high, medium, low, informational) e controlla che le prime righe siano `high` prima di allegarlo a un report.

2. **La «copertura MFA» di `10` e il totale utenti di `08` contano solo gli account ABILITATI.** Entrambi partono da `Get-MgReportAuthenticationMethodUserRegistrationDetail`, e la documentazione Microsoft Graph dell'endpoint `/reports/authenticationMethods/userRegistrationDetails` dichiara che il metodo non restituisce gli utenti disabilitati: gli account disabilitati sono semplicemente assenti dalla collezione. Quindi `UtentiTotali` nel CSV di 10 non sono «gli utenti del tenant» ma «gli utenti abilitati», e `MfaCoperturaPct` è una quota sui soli account abilitati; lo stesso vale per il conteggio «Utenti nel report» stampato da 08. L'errore è nella direzione lusinghiera — la copertura appare più alta del reale — e né lo script né l'output lo dichiarano. Quando usi questi numeri come evidenza, scrivi accanto il denominatore e la sua fonte («su N utenti abilitati, report Graph dei metodi di autenticazione»), oppure incrocia con `Get-MgUser` per contare a parte gli account disabilitati. Un numero senza il suo denominatore inganna.

3. **Se il Secure Score non è disponibile, `10` stampa `0/0` e scrive un CSV indistinguibile da una misura reale pari a zero.** 01 e 03 hanno la guardia `if (-not $s) { Write-Host 'Nessun Secure Score disponibile.'; return }`; 10 e 02 usano lo stesso cmdlet ma non l'hanno. In 10, con `$score` nullo, `[math]::Round($null.CurrentScore, 1)` non solleva alcuna eccezione: restituisce `0`. Il riepilogo stampa quindi `Secure Score        : % (0/0)` ed esporta una riga con `SecureScorePct` vuoto e `SecureScore`/`SecureScoreMax` nulli — in un documento di audit uno zero si legge come una misura, non come un dato mancante. 02, anch'esso senza guardia, arriva in fondo dichiarando «Esportati 0 rilevamenti» e scrive un file senza righe. E il caso è atteso, non teorico: il Secure Score dipende dalle licenze attive. Prima di usare la sintesi di 10, lancia 01, che il caso lo dice a parole; e se il campo è vuoto, nel documento che consegni scrivilo come «non disponibile», non come zero.

4. **Gli output contengono dati personali, e il CSV di `08 -OnlyGaps` è un elenco di bersagli.** Nei file della raccolta non c'è alcun dato personale, ma quelli che gli script producono sì: 07 esporta UserPrincipalName, indirizzo IP, città e paese di ogni rilevamento; 06 esporta UPN e nome visualizzato; 08 esporta UPN, nome visualizzato, lo stato MFA e il flag di amministratore. In particolare 08 lanciato con `-OnlyGaps` produce un elenco in chiaro degli account **senza MFA, amministratori inclusi**: una lista di bersagli pronta all'uso, scritta in chiaro nella directory di lavoro. Sono dati personali rilevanti per gli artt. 5 e 32 del GDPR. Tratta quel CSV come materiale riservato: tienilo fuori dalle cartelle condivise e dagli allegati di posta, cancellalo quando la lacuna è chiusa, e non committarlo mai (vedi la sezione seguente).

5. **`AuditLog.Read.All` (08, 10) abilita la lettura di tutto l'audit log e di tutti i sign-in log del tenant, non del solo report MFA.** Per questo endpoint è il permesso con privilegio minimo documentato da Microsoft e non esiste un'alternativa più stretta: lo script non chiede più del necessario. Il punto è che lo scope è ampio nei suoi **effetti**, perché i ruoli Entra sottostanti sono `microsoft.directory/auditLogs/allProperties/read` e `microsoft.directory/signInReports/allProperties/read`, cioè la lettura di tutti i log di audit e di accesso del tenant — molto oltre «il report MFA». Dal nome dello scope, nella schermata di `Connect-MgGraph`, questo non si capisce. Sappilo prima di acconsentire, e dillo al cliente sul cui tenant stai acconsentendo.

6. **`SecurityEvents.Read.All` (01, 02, 03, 10) legge tutti gli avvisi di sicurezza, non solo i punteggi.** È il privilegio minimo documentato per `GET /security/secureScores`, e la pagina Microsoft dedicata al Secure Score segnala essa stessa che si tratta di un over-grant inevitabile: lo scope dà accesso a tutti gli avvisi di sicurezza e non esiste niente di più stretto. È una proprietà dell'API, non una scelta del toolkit, ma il consenso che concedi è più largo di «leggi il punteggio». Se per un cliente è inaccettabile, le uniche vie sono isolare le chiamate Secure Score in una app registration separata o rinunciare agli script 01, 02 e 03.

## Dove finiscono i file

Tutti e dieci esportano un CSV tramite `-OutputCsv`, il cui valore predefinito è un percorso **relativo** alla directory corrente e contiene solo la data: `.\SecureScore-Current-20261029.csv`, `.\Defender-Alerts-20261029.csv`, `.\MFA-Registration-20261029.csv` e così via. Due conseguenze da tenere a mente ogni volta:

- **Il file nasce dove si trova il prompt, non dove si trova lo script.** Se hai clonato questo repository e lanci da lì, il CSV finisce dentro il clone. Il `.gitignore` nella radice esclude `*.csv`, ma non fidarti: controlla con `git status` prima di committare. E nelle cartelle sincronizzate su OneDrive, SharePoint o Dropbox nessun `.gitignore` ti protegge.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente, senza chiedere.** Il nome contiene la data ma non l'ora, e `Export-Csv` è chiamato senza `-NoClobber`: l'evidenza presa stamattina viene sostituita da quella di stasera. Se devi confrontare un prima e un dopo, o conservare l'evidenza già prodotta, passa `-OutputCsv` con nomi diversi.

Il contenuto va protetto come un documento riservato, perché messo insieme dice a un attaccante quali account prendere di mira e quali controlli dovrà aggirare: nomi utente in chiaro (06, 07, 08), indirizzi IP con città e paese degli accessi a rischio (07), stato MFA e flag di amministratore di ogni utente (08, 10), inventario delle regole di accesso condizionale che proteggono il tenant (09).

## Esempi

```powershell
# Secure Score attuale, e le azioni con il gap di punteggio piu alto
.\01-Get-SecureScoreCurrent.ps1
.\03-Get-SecureScoreImprovementActions.ps1

# Finestre piu larghe: 90 rilevamenti di trend, 500 rilevamenti di rischio
.\02-Get-SecureScoreTrend.ps1 -Days 90
.\07-Get-RiskDetections.ps1 -Top 500

# Solo gli utenti senza MFA: output da trattare come riservato (avvertenza 4)
.\08-Get-MfaRegistrationReport.ps1 -OnlyGaps

# Cruscotto di sintesi, scritto fuori dal repository clonato
.\10-Get-SecurityPostureSummary.ps1 -OutputCsv 'C:\Audit\postura-20261029.csv'
```

## Altro

Lo stesso contenuto si scarica come ZIP dalla pagina [synsphere.it/download/toolkit-powershell-defender-sicurezza/](https://synsphere.it/download/toolkit-powershell-defender-sicurezza/).

Se serve aiuto a interpretare i report, o a chiudere le lacune che hanno trovato: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
