# Microsoft Purview Compliance Toolkit

Dieci script PowerShell di sola lettura che separano la configurazione Purview presente nel portale da quella che sta effettivamente proteggendo qualcosa, e ne producono l'evidenza in CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Nel portale di Microsoft Purview una misura configurata e una misura che sta davvero proteggendo hanno lo stesso aspetto: una riga in un elenco. Questi script leggono la configurazione esistente e distinguono le due cose su quattro aree — conservazione, etichette di riservatezza, prevenzione della perdita dei dati, log di controllo unificato — esportando per ciascuna un CSV UTF-8.

Sono rivolti ad amministratori Microsoft 365 e a consulenti di PMI che devono consegnare a un auditor non l'elenco delle policy configurate, ma la misura di quali agiscono. Nessuno dei dieci aggiunge o modifica configurazione nel tenant.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-RetentionPolicyScope.ps1` | Policy di conservazione con le posizioni su cui sono davvero distribuite (Exchange, SharePoint, OneDrive, gruppi moderni, chat e canali di Teams) e lo stato di distribuzione. Usa sempre `-DistributionDetail`, senza il quale la documentazione Microsoft dichiara inaccurati lo stato e le proprietà `*Location`. | Sola lettura |
| `02-Get-RetentionLabelsAndRules.ps1` | Etichette di conservazione e regole collegate: per quanto tempo si conserva, da quale data decorre il conteggio, cosa succede alla fine del periodo, se l'etichetta è un record. | Sola lettura |
| `03-Get-SensitivityLabelsAndPolicies.ps1` | Etichette di riservatezza confrontate con le policy di pubblicazione: segnala quelle che esistono ma non sono incluse in nessuna policy, e quindi non arrivano a nessun utente. | Sola lettura |
| `04-Get-DlpPolicies.ps1` | Policy DLP con stato, modalità operativa e posizioni configurate. Non usa `-DistributionDetail`: per il DLP la documentazione Microsoft dichiara `DistributionResults` inaffidabile. | Sola lettura |
| `05-Get-DlpRulesDetail.ps1` | Per ogni regola DLP: tipi di informazione sensibile richiamati con conteggio e confidenza minimi, azioni configurate (blocco, notifica, override da parte dell'utente) e severità assegnata all'incidente. | Sola lettura |
| `06-Get-DlpPoliciesInTestMode.ps1` | Isola le policy DLP che non proteggono: quelle in modalità di test e quelle disabilitate, con i giorni trascorsi dall'ultima modifica. | Sola lettura |
| `07-Get-UnifiedAuditLogStatus.ps1` | Stato dell'inserimento nel log di controllo unificato, letto da Exchange Online; tenta anche le policy di conservazione del log e, se il cmdlet non è disponibile, lo dichiara invece di dedurne l'assenza. | Sola lettura |
| `08-Get-CustomSensitiveInfoTypes.ps1` | Tipi di informazione sensibile raggruppati per editore, con l'indicazione di quali sono richiamati da almeno una regola DLP. | Sola lettura |
| `09-Get-ComplianceSearchInventory.ps1` | Inventario delle ricerche di conformità (eDiscovery): stato, autore, data, perimetro interrogato e query. Non avvia, non modifica e non esporta alcuna ricerca. | Sola lettura |
| `10-Get-PurviewComplianceSummary.ps1` | Cruscotto delle quattro aree in una schermata. Ogni sezione è indipendente: se non è leggibile lo dichiara e le altre proseguono. Non apre connessioni da sé. | Sola lettura |

L'unica scrittura è il CSV su disco: nessuno script modifica la configurazione del tenant.

Se parti da zero: `10` per la fotografia d'insieme, poi `06` per vedere cosa è rimasto in simulazione, poi `07` (se il log di controllo non è attivo, quello viene prima di tutto il resto), poi `01` per l'ambito reale della conservazione e `03` con `08` per capire se il lavoro di classificazione è arrivato agli utenti.

## Prima di eseguirli

- **PowerShell 5.1 o PowerShell 7.** Nessuno script vincola la versione con `#Requires -Version`.
- **Modulo ExchangeOnlineManagement v3.2.0 o superiore**, che fornisce sia `Connect-IPPSSession` sia `Connect-ExchangeOnline`:

  ```powershell
  Install-Module ExchangeOnlineManagement -MinimumVersion 3.2.0
  ```

  Il `#Requires` in testa agli script controlla la presenza del modulo, non la versione: con un modulo più vecchio l'errore non arriva all'avvio ma al primo cmdlet mancante.
- **Due contesti di connessione, e non sono interscambiabili.**
  - `Connect-IPPSSession` (Security & Compliance) → `01`, `02`, `03`, `04`, `05`, `06`, `08`, `09`
  - `Connect-ExchangeOnline` → `07`
  - `10` legge da entrambi ma non apre connessioni: aprile tu prima di lanciarlo, altrimenti le sezioni non connesse risulteranno non disponibili.
- **Permessi.** Per le letture Purview è sufficiente un ruolo di sola lettura, tipicamente View-Only Configuration o View-Only Retention Management, oppure Global Reader. Per `07` e per la sezione Tracciabilità di `10` serve un ruolo che consenta `Get-AdminAuditLogConfig`, tipicamente View-Only Organization Configuration oppure Global Reader.
- **Licenza.** Le policy di conservazione del log di controllo che `07` tenta di leggere (`Get-UnifiedAuditLogRetentionPolicy`) richiedono il contesto compliance e una licenza Audit Premium.
- Nessuno scope Microsoft Graph e nessun ruolo Azure RBAC: il toolkit usa esclusivamente i cmdlet del modulo ExchangeOnlineManagement.

## ⚠️ Avvertenze

1. **Una proprietà non leggibile viene contata come "in produzione".** Nel cruscotto (`10`) e in `06` lo stato della policy è verificato in negativo (`-ne $false`): se il campo `Enabled` non è leggibile — permessi parziali, versione del modulo diversa — la policy finisce fra quelle che proteggono. `01` fa l'opposto (`-eq $true`) e la stessa policy non viene contata, quindi i due script possono dare numeri che non concordano. Per uno strumento di compliance è la direzione di errore pericolosa, perché dichiara protetto ciò che non è stato misurato. Leggi sempre le colonne grezze `Modalita` e `Abilitata` del CSV, non solo i conteggi a schermo: una cella vuota lì non è un "no".

2. **Il CSV di `09` contiene dati personali.** La colonna `Query` esporta in chiaro la query delle ricerche eDiscovery (`ContentMatchQuery`), che tipicamente contiene nomi e cognomi di persone fisiche e termini di indagine legale, in un file scritto nella directory corrente. È l'unico output del toolkit che può contenere dati personali. Dagli una directory dedicata con `-OutputCsv`, trattalo come documento riservato e cancellalo quando non serve più.

3. **Lo stato del log di controllo è falso se letto dal contesto sbagliato.** La proprietà `UnifiedAuditLogIngestionEnabled`, se letta in Security & Compliance PowerShell, non dà errore: restituisce sempre `False`, e la documentazione Microsoft lo dichiara. Per questo `07` si connette a Exchange Online. La sezione Tracciabilità di `10`, invece, legge la sessione che trova aperta: se hai connesso solo `Connect-IPPSSession`, il cruscotto riporta "log di controllo non attivo" su un tenant dove il log è regolarmente attivo. In caso di dubbio esegui `07` in una sessione nuova, con la sola connessione a Exchange Online.

4. **In `05` una `ModalitaPolicy` vuota non significa "in produzione".** Lo script collega ogni regola alla sua policy per nome; quando `ParentPolicyName` non è valorizzato al suo posto resta un GUID, il collegamento non trova nulla e la colonna resta vuota senza alcun errore. È esattamente la colonna per cui lo script esiste — dire se la regola vive in una policy in simulazione — e una cella vuota si legge come "nessun problema". Dove `ModalitaPolicy` è vuota, verifica quella policy con `04` o `06`.

5. **Una sezione o una colonna "non disponibile" non è uno zero.** Il cruscotto (`10`) degrada le quattro aree una per una: quando un'area non è leggibile scrive "non disponibile" nella colonna `Valore` e le altre proseguono. È il comportamento voluto, ma significa che un cruscotto che sembra pulito può essere un cruscotto che non ha misurato tre aree su quattro. Lo stesso vale per le policy di conservazione del log in `07` senza licenza Audit Premium. Prima di consegnare un CSV come evidenza, controlla che ogni area riporti un numero e non quella dicitura.

6. **Alla prima lettura gli script possono aprire una richiesta di accesso.** Ogni script tenta il suo primo cmdlet e, se fallisce, interpreta il fallimento come "non connesso" e chiama `Connect-IPPSSession` (o `Connect-ExchangeOnline`). Il `catch` non distingue la causa: anche permessi insufficienti, throttling o un errore di servizio fanno comparire un prompt di accesso che non ti aspettavi, dopo il quale l'errore vero riemerge mascherato da problema di connessione. Connettiti a mano prima di lanciarli, e se un prompt compare a sorpresa non dare per scontato che la causa sia la sessione.

## Dove finiscono i file

Ogni script esporta un CSV UTF-8 e il default di `-OutputCsv` è un percorso relativo nella forma `.\M365-<area>-<aaaammgg>.csv`. Due conseguenze da tenere presenti:

- **Il file nasce dove si trova il prompt**, non accanto allo script. Se hai clonato il repository e lanci da lì, il CSV finisce dentro il clone: non committarlo. Il `.gitignore` della radice lo esclude, ma non fidarti del filtro — guarda `git status` prima di un commit.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente senza chiedere.** Il nome di default contiene solo la data, non l'ora, e nessuna delle esportazioni usa `-NoClobber`, `-Append` o una conferma. In un contesto di audit significa perdere l'evidenza appena raccolta, compreso il CSV con i dati personali di `09`. Passa un `-OutputCsv` esplicito, con percorso assoluto, a ogni esecuzione.

Due dettagli su `07`: il secondo file con il dettaglio delle policy di conservazione del log è costruito dal nome del primo (`...-RetentionPolicies.csv`) e non è parametrizzabile a parte; e se passi un `-OutputCsv` che non termina in `.csv`, il file principale resta senza estensione.

Nomi di default, nell'ordine degli script: `M365-RetentionPolicyScope-<data>.csv`, `M365-RetentionLabels-<data>.csv`, `M365-SensitivityLabels-<data>.csv`, `M365-DlpPolicies-<data>.csv`, `M365-DlpRules-<data>.csv`, `M365-DlpTestMode-<data>.csv`, `M365-AuditLogStatus-<data>.csv` (più `M365-AuditLogStatus-<data>-RetentionPolicies.csv`), `M365-SensitiveInfoTypes-<data>.csv`, `M365-ComplianceSearches-<data>.csv`, `M365-PurviewSummary-<data>.csv`.

## Esempi

```powershell
# Conservazione, etichette e DLP: contesto Security & Compliance
Connect-IPPSSession
.\06-Get-DlpPoliciesInTestMode.ps1 -SoloProblemi
.\01-Get-RetentionPolicyScope.ps1
.\03-Get-SensitivityLabelsAndPolicies.ps1
.\08-Get-CustomSensitiveInfoTypes.ps1 -SoloNonMicrosoft

# Log di controllo unificato: va letto da Exchange Online
Connect-ExchangeOnline
.\07-Get-UnifiedAuditLogStatus.ps1

# Cruscotto: non apre connessioni, vanno aperte entrambe prima
Connect-IPPSSession
Connect-ExchangeOnline
.\10-Get-PurviewComplianceSummary.ps1

# Un file per esecuzione, in una directory dedicata e fuori dal clone
.\09-Get-ComplianceSearchInventory.ps1 -OutputCsv C:\Evidenze\eDiscovery-20261029.csv
```

## Altro

Lo stesso contenuto si scarica come ZIP dalla pagina [synsphere.it/download/toolkit-powershell-purview-compliance](https://synsphere.it/download/toolkit-powershell-purview-compliance/).

Se serve aiuto a portare la configurazione di Purview da "presente" ad "attiva", con le evidenze pronte per un audit: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
