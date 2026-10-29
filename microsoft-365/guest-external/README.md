# Ospiti e accesso esterno in Microsoft 365

Dieci script PowerShell per sapere chi, dall'esterno, ha accesso al tuo tenant, e per ripulire quello che non serve più.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Gli account guest si accumulano: un fornitore invitato per un progetto chiuso due anni fa, un invito mai accettato, un link "chiunque abbia il link" creato per comodità e mai revocato. Nessuno di questi compare in un elenco di utenti del tenant, e nessuno dà errore.

Questi script fotografano la collaborazione esterna di un tenant Microsoft 365 — chi sono gli ospiti, da quali domini vengono, a quali gruppi e team appartengono, che cosa hanno consultato, con quali impostazioni il tenant permette di invitarli — e consentono di rimuovere gli ospiti inattivi. Sono rivolti all'amministratore Microsoft 365 di una PMI, o al consulente che per lei conduce un audit di sicurezza, anche in chiave NIS2. Nove script su dieci sono in sola lettura e producono un CSV; solo il `06` modifica il tenant.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-M365GuestUsers.ps1` | Esporta tutti gli account con `userType = Guest`: nome, email, dominio di provenienza, azienda, data di creazione, stato dell'invito e se l'account è abilitato. È il punto di partenza di qualsiasi audit della collaborazione esterna. | Sola lettura |
| `02-Get-M365GuestGroupMemberships.ps1` | Per ogni ospite elenca i gruppi e i team di cui fa parte, con il conteggio: serve a capire a quali risorse un ospite ha effettivamente accesso. | Sola lettura |
| `03-Get-M365StaleGuestUsers.ps1` | Elenca gli ospiti il cui ultimo accesso è oltre la soglia `-InactiveDays`, o per cui non risulta alcun accesso. | Sola lettura |
| `04-Get-M365PendingGuestInvitations.ps1` | Elenca gli ospiti in stato `PendingAcceptance`: hanno ricevuto un invito e non l'hanno mai riscattato. | Sola lettura |
| `05-Get-M365GuestsByDomain.ps1` | Raggruppa gli ospiti per dominio di provenienza e conta quanti per ciascuno: con quali aziende collabori davvero e quali domini non sono più rilevanti. | Sola lettura |
| `06-Remove-M365StaleGuests.ps1` | Individua gli ospiti inattivi e, su richiesta, li disabilita (`-Action Disable`) o li elimina (`-Action Delete`). Il default `-Action Report` non tocca nulla. Supporta `-WhatIf`. | **SCRIVE** con `-Action Disable` o `-Action Delete` |
| `07-Get-M365ExternalSharingAudit.ps1` | Estrae dall'Unified Audit Log gli eventi di condivisione verso l'esterno (inviti di sharing, secure link): chi ha condiviso che cosa e con chi. | Sola lettura |
| `08-Get-M365ExternalFileAccessAudit.ps1` | Estrae dall'Unified Audit Log accessi e download di file compiuti da identità esterne (UPN che contiene `#EXT#`). | Sola lettura |
| `09-Get-M365AnonymousLinkAudit.ps1` | Estrae dall'Unified Audit Log creazione, modifica e uso dei link anonimi, quelli accessibili senza autenticazione. | Sola lettura |
| `10-Get-M365ExternalCollaborationSettings.ps1` | Legge l'authorization policy di Microsoft Entra: chi può invitare ospiti, quale ruolo di directory hanno gli ospiti, e alcuni permessi predefiniti degli utenti. | Sola lettura |

## Prima di eseguirli

**PowerShell.** PowerShell 5.1 oppure PowerShell 7. Nessuno script dichiara una versione minima con `#Requires -Version`.

**Moduli.** La via più semplice è installare il meta-modulo Graph, che contiene tutti i sottomoduli necessari:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser          # script 01-06 e 10
Install-Module ExchangeOnlineManagement -Scope CurrentUser  # script 07-09
```

Se preferisci installare i singoli sottomoduli invece del meta-modulo, servono tutti e tre questi, perché le direttive `#Requires` degli script sono incomplete: sei script su dieci superano il controllo e poi si fermano con "termine non riconosciuto" (`01`, `02`, `03`, `04` e `05` usano `Get-MgUser`/`Get-MgUserMemberOf`, che stanno in `Microsoft.Graph.Users`; `10` usa `Get-MgPolicyAuthorizationPolicy`, che sta in `Microsoft.Graph.Identity.SignIns`). Lo `06` dichiara correttamente `Microsoft.Graph.Users` ed e l'unico che non si rompe.

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Identity.SignIns -Scope CurrentUser
```

**Permessi e ruoli.** Gli scope Graph sono delegati e richiedono il consenso dell'amministratore al primo accesso.

| Script | Scope Graph o ruolo |
| --- | --- |
| `01`, `04`, `05` | `User.Read.All` |
| `02` | `User.Read.All`, `GroupMember.Read.All` |
| `03` | `User.Read.All`, `AuditLog.Read.All` |
| `06` | `User.ReadWrite.All`, `AuditLog.Read.All` (vedi avvertenza 6) |
| `07`, `08`, `09` | Exchange Online, ruolo **View-Only Audit Logs** o **Audit Logs** |
| `10` | `Policy.Read.All` |

- Ruolo di directory: **Global Reader** è sufficiente per `01`-`05` e `10`. Il `06` con `-Action Disable` o `-Action Delete` richiede **User Administrator** o superiore.
- Gli script `07`-`09` richiedono che l'audit unificato (Purview) sia **attivo** sul tenant.
- La proprietà `signInActivity`, su cui si basano `03` e `06`, richiede una licenza **Microsoft Entra ID P1 o P2**.

## ⚠️ Avvertenze

1. **`06 -Action Delete` non chiede conferma: elimina e basta.** Lo script dichiara `SupportsShouldProcess` ma senza `ConfirmImpact = 'High'`, e con le preferenze predefinite di PowerShell questo significa che il prompt non compare mai. Conseguenza: `.\06-Remove-M365StaleGuests.ps1 -Action Delete` cancella in blocco tutti gli ospiti sopra soglia senza un solo "sei sicuro?". Esegui **sempre** prima con `-WhatIf`, e ricorda che il default `-Action Report` non modifica nulla. Un account Entra eliminato resta ripristinabile dal cestino della directory per circa 30 giorni; oltre, non più.

2. **Chi finisce nell'insieme può essere molto più di quello che credi.** Due cause distinte, entrambe su `03` e `06`. La prima: i due script considerano stantio anche l'ospite per cui l'ultimo accesso non risulta (nel CSV compare come `Mai`), ma `signInActivity` richiede la licenza Entra ID P1/P2 e lo scope `AuditLog.Read.All` — senza di essi il dato può non arrivare affatto e ospiti perfettamente attivi appaiono come mai entrati. La seconda: `-InactiveDays` non ha un controllo di intervallo, quindi un valore negativo come `-InactiveDays -30` sposta la soglia nel futuro e allarga il perimetro invece di stringerlo. Con `-Action Delete`, quell'insieme è l'elenco di chi viene cancellato. Verifica la licenza, passa solo valori positivi, esegui prima `03` in sola lettura e leggi il CSV riga per riga: se vedi `Mai` su quasi tutti gli ospiti, il dato non c'è, non è una fotografia del tenant.

3. **Un'esecuzione di `06` interrotta a metà non lascia traccia di quello che ha già fatto.** Gli script non hanno gestione degli errori e `$ErrorActionPreference` è impostato su `Stop`: il primo fallimento (permessi insufficienti su un ospite, throttling di Graph) interrompe l'intero ciclo *prima* dell'`Export-Csv` finale. Conseguenza: le disabilitazioni o le cancellazioni già riuscite non vengono scritte in alcun file e non sai su quali ospiti hai agito. Lavora per lotti piccoli, alzando la soglia in modo che il set sia breve, e avvia `Start-Transcript` prima di una esecuzione con `-Action Delete`.

4. **Uno zero di `08` o di `09` non è la prova che non sia accaduto nulla.** I tre script di audit chiedono al server un massimo di 5000 eventi. `08` applica quel tetto a *tutti* gli accessi a file del tenant e solo dopo, in locale, tiene i soli attori esterni: in un tenant attivo i 5000 eventi più recenti possono essere tutti interni, e lo script stampa "0 accessi a file da utenti esterni" mentre accessi esterni ci sono stati. `09`, su qualunque risultato vuoto, stampa "Nessun link anonimo nel periodo: buona postura di condivisione" — anche quando il vuoto dipende dall'audit unificato non attivo, dal ruolo di audit mancante, da una finestra `-Days` oltre la retention del tuo piano o da un `-Days` pari a zero o negativo, che non essendo validato produce una data di inizio nel futuro e un risultato sempre vuoto. Prima di leggere il risultato accertati che l'audit sia attivo e di avere il ruolo; poi restringi `-Days` e ripeti su finestre brevi, così da non sbattere nel tetto. Un numero senza il suo denominatore non è una misura.

5. **`02` sotto-conta in silenzio: `GroupCount = 0` può voler dire "lettura non riuscita".** La lettura delle membership di ciascun ospite sopprime gli errori (`-ErrorAction SilentlyContinue`): se per un ospite fallisce, quell'ospite compare nel report con zero gruppi, indistinguibile da un ospite che davvero non appartiene a nulla. Il report presenta come completo un elenco che può aver perso degli accessi. Riverifica a mano, con `02` su quel singolo ospite o dal portale, gli ospiti che risultano senza gruppi.

6. **`06` chiede la scrittura su tutti gli utenti del tenant anche quando non scrive niente.** Lo script si connette sempre con `User.ReadWrite.All`, anche con `-Action Report`, cioè nel caso in cui non modifica nulla: per ottenere un semplice elenco concedi — o fai concedere all'amministratore — un consenso di scrittura su tutto il tenant. Se ti serve solo l'elenco degli ospiti inattivi, usa `03`, che chiede `User.Read.All`.

## Dove finiscono i file

Ogni script esporta un CSV e il percorso predefinito è **relativo alla directory corrente**, con un nome che contiene solo la data (per esempio `.\M365-GuestUsers-20261029.csv`). Due conseguenze:

- Il file nasce dove si trova il prompt. Se hai clonato il repository e lanci gli script da dentro il clone, il CSV nasce **dentro il clone**: il `.gitignore` della radice esclude i `*.csv`, ma non fidarti di quella rete e controlla `git status` prima di un commit.
- Una seconda esecuzione nello stesso giorno **sovrascrive** l'export precedente senza chiedere: il nome dipende solo dalla data e `Export-Csv` non usa `-NoClobber`.

Il contenuto è materiale personale di soggetti terzi: nome e indirizzo email degli ospiti esterni, con dominio di provenienza e azienda (`01`-`06`); UPN degli utenti esterni, nomi dei file consultati e URL dei siti (`07`-`09`). Sono export rilevanti ai fini del GDPR: passa sempre `-OutputCsv` verso una cartella controllata, e cancellali a analisi conclusa. Lo script `10` stampa inoltre a schermo le impostazioni del tenant.

## Esempi

```powershell
# Censimento di partenza: tutti gli ospiti del tenant
.\01-Get-M365GuestUsers.ps1

# Ospiti che non accedono da più di sei mesi (sola lettura)
.\03-Get-M365StaleGuestUsers.ps1 -InactiveDays 180

# Condivisioni verso l'esterno dell'ultimo mese
.\07-Get-M365ExternalSharingAudit.ps1 -Days 30

# Pulizia: prima in prova, senza toccare niente
.\06-Remove-M365StaleGuests.ps1 -InactiveDays 180 -Action Disable -WhatIf
```

## Altro

Lo stesso contenuto è scaricabile come archivio ZIP dalla pagina [synsphere.it/download/toolkit-powershell-guest-esterni-microsoft-365](https://synsphere.it/download/toolkit-powershell-guest-esterni-microsoft-365/).

Se serve aiuto a interpretare i risultati o a mettere in sicurezza la collaborazione esterna: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
