# Governance dell'identità in Microsoft Entra ID

Dieci script di sola lettura che rispondono, CSV alla mano, a tre domande: chi ha i poteri di amministrazione, quali applicazioni hanno accesso al tenant, e dove la governance dell'identità ha dei buchi.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Gli script sono pensati per chi amministra un tenant Microsoft 365 / Entra ID di una PMI e per gli MSP che devono produrre evidenze periodiche di audit sull'identità per un audit interno o per gli obblighi di sicurezza a cui l'azienda è soggetta, senza acquistare uno strumento dedicato. Ognuno fotografa un pezzo della configurazione tramite il Microsoft Graph PowerShell SDK ed esporta un CSV datato; nessuno modifica il tenant.

Sono eseguibili singolarmente e in qualsiasi ordine: non c'è un ordine obbligato, lo `01` è solo il punto di partenza più comune.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-EntraPrivilegedRoleMembers.ps1` | Elenca ogni ruolo directory attivato nel tenant (Global Administrator e gli altri) con i suoi membri, siano utenti, gruppi o service principal. Mostra le assegnazioni attive e permanenti, non i ruoli eleggibili in PIM. | Sola lettura |
| `02-Get-EntraPimEligibleRoles.ps1` | Elenca le assegnazioni di ruolo eleggibili in Entra PIM: chi **può** attivare un ruolo privilegiato senza averlo in permanenza, con stato, tipo di assegnazione e finestra di validità. Completa lo `01`. | Sola lettura |
| `03-Get-EntraAppRegistrations.ps1` | Inventario delle app registration con appId, data di creazione, audience, dominio del publisher e numero di owner: serve a mappare le integrazioni e a trovare le app senza proprietario. | Sola lettura |
| `04-Get-EntraExpiringAppCredentials.ps1` | Segnala i client secret e i certificati delle app registration che scadono entro N giorni, inclusi quelli già scaduti (giorni negativi). Copre le app registration, non i service principal. | Sola lettura |
| `05-Get-EntraEnterpriseApps.ps1` | Inventario dei service principal (enterprise application) con tipo, stato di abilitazione, se richiedono l'assegnazione esplicita degli utenti e quante credenziali hanno fra segreti e certificati. | Sola lettura |
| `06-Get-EntraGuestAccounts.ps1` | Elenca gli account guest della collaborazione esterna B2B con email, data di creazione e ultimo accesso, per rivedere chi entra ancora dall'esterno e trovare i guest inattivi. | Sola lettura |
| `07-Get-EntraGroupsWithoutOwners.ps1` | Elenca i gruppi Microsoft 365 e di sicurezza che non hanno alcun owner assegnato, classificati per tipo. Esclude i gruppi sincronizzati da on-premises, i cui owner non si gestiscono in Entra. | Sola lettura |
| `08-Get-EntraGroupBasedLicensing.ps1` | Elenca i gruppi che assegnano licenze ai membri (group-based licensing) con i nomi degli SKU, risolti attraverso gli SKU sottoscritti dal tenant. | Sola lettura |
| `09-Get-EntraOAuth2PermissionGrants.ps1` | Elenca i consensi a permessi delegati: quale app ha ottenuto quali permessi su quale risorsa, e se il consenso vale per tutto il tenant o per un singolo utente. Nomi di app e risorse risolti. | Sola lettura |
| `10-Get-EntraIdentitySummary.ps1` | Cruscotto di sintesi: numero di Global Administrator, app registration, credenziali scadute o in scadenza a 30 giorni, service principal e guest. Stampa il riepilogo ed esporta una riga sola. | Sola lettura |

La terza colonna dice la stessa cosa dieci volte, e questo è il punto: nessuno dei dieci script modifica la configurazione del tenant, nessuno degli scope Graph che chiedono contiene `.ReadWrite`. L'unica cosa che viene scritta è il CSV sul disco locale.

## Prima di eseguirli

**PowerShell.** Nessuno dei dieci script dichiara una versione minima nel codice. Sono scritti per PowerShell 5.1 o PowerShell 7.

**Moduli.** Installa il modulo Graph completo:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

Attenzione a non fermarti a meno di così: ogni script dichiara `#Requires -Modules Microsoft.Graph.Authentication`, che copre solo `Connect-MgGraph`. I cmdlet `Get-Mg*` che fanno il lavoro stanno in altri sottomoduli, quindi chi installa soltanto `Microsoft.Graph.Authentication` passa il controllo dei requisiti e poi vede lo script fallire al primo comando con «termine non riconosciuto». Se preferisci il set minimo invece del meta-modulo, servono questi sei:

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Identity.Governance, Microsoft.Graph.Applications, Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Identity.SignIns -Scope CurrentUser
```

**Ruolo.** Global Reader è sufficiente per tutto tranne i dati PIM, che richiedono anche la licenza Entra ID P2.

**Permessi Graph delegati, per script.** Tutti di sola lettura:

| Script | Scope richiesti al `Connect-MgGraph` |
| --- | --- |
| 01 | `RoleManagement.Read.Directory` |
| 02 | `RoleEligibilitySchedule.Read.Directory` (dati PIM: serve Entra ID P2) |
| 03, 04, 05 | `Application.Read.All` |
| 06 | `User.Read.All`, `AuditLog.Read.All` (l'ultimo accesso dei guest richiede Entra ID P1 o P2) |
| 07 | `Group.Read.All` |
| 08 | `Group.Read.All`, `Organization.Read.All` |
| 09 | `Directory.Read.All` |
| 10 | `Directory.Read.All`, `Application.Read.All` |

**Consenso.** Il consenso agli scope viene chiesto al primo `Connect-MgGraph`. In un tenant dove il consenso utente è disabilitato serve un amministratore che approvi, altrimenti lo script non parte.

**Durata.** Lo `03` e lo `07` chiedono gli owner uno per uno, una chiamata a Graph per ogni app e per ogni gruppo: su un tenant con molti oggetti metti in conto un'esecuzione lunga.

## ⚠️ Avvertenze

1. **I CSV contengono dati personali e nascono nella cartella da cui lanci lo script.** Il `06` esporta gli indirizzi email dei guest, cioè di persone fisiche esterne all'azienda; `01` e `02` esportano gli UPN di chi ha i ruoli privilegiati; `07` e `09` esportano object ID e, per i consensi per-utente, il principal ID dell'utente. Il percorso di default è relativo, quindi se hai clonato il repository e lanci gli script da dentro il clone i file finiscono nella working tree, dove un `git add .` distratto li pubblica. Il `.gitignore` nella radice esclude `*.csv`, ma non fidarti del `.gitignore`: guarda `git status` prima di committare, e tratta questi file come tratti gli altri dati personali del tenant (non allegarli a un ticket, non mandarli per email).

2. **Il cruscotto `10` può stampare uno zero che non è uno zero.** La lettura del ruolo Global Administrator usa `-ErrorAction SilentlyContinue` e, se non restituisce nulla, il conteggio vale `0`: un errore o un permesso mancante diventano quindi la riga «Global Administrator: 0», che a schermo sembra un dato. Uno zero su quella riga non è un tenant pulito, è un dato da verificare: incrocialo con lo `01`, che sullo stesso dato fallisce in modo visibile.

3. **Senza le licenze giuste due script non dicono quello che sembrano dire.** Il `02` senza Entra ID P2 stampa un avviso e termina **senza scrivere nessun CSV**: chi lancia la raccolta in sequenza e poi guarda solo i file trova un buco e non un errore. Il `06` senza Entra ID P1 o P2 riempie la colonna dell'ultimo accesso con `n/d (Entra ID P1)` per ogni riga: una revisione dei guest inattivi fatta su quella colonna non sta decidendo su niente. Controlla che il file esista e che la colonna sia popolata prima di usarli come evidenza.

4. **Nessuno dei tre elenchi «chi ha accesso» è completo da solo.** Lo `01` mostra le assegnazioni attive e permanenti: se nel tenant si usa PIM, un elenco di amministratori basato solo sullo `01` **omette chi può attivare un ruolo quando vuole** — serve anche lo `02`. Il `04` copre le credenziali delle app registration, non quelle dei service principal: per quelle serve il `05`. Il `07`, al contrario, è più largo di quanto sembra: esclude i gruppi sincronizzati da on-premises, e le liste di distribuzione create in Exchange compaiono come «senza owner» perché l'owner è gestito in Exchange — vanno verificate lì prima di contarle come un gap.

5. **Due esecuzioni nello stesso giorno: la seconda sovrascrive la prima, senza chiedere.** Il nome di default ha granularità giornaliera (`yyyyMMdd`) e l'export non usa `-NoClobber` né chiede conferma. Se filtri un risultato a mano e rilanci lo script per confronto, il CSV di prima non c'è più. Per conservarli entrambi passa un `-OutputCsv` esplicito.

6. **Il `09` e il `10` chiedono `Directory.Read.All`, uno scope più ampio degli altri otto script.** È lettura dell'intera directory del tenant, e il consenso che concedi al primo `Connect-MgGraph` resta valido per quell'applicazione. Nel caso del `09` è deliberato: per elencare i consensi OAuth2 delegati l'unico scope che Microsoft documenta come meno privilegiato è `DelegatedPermissionGrant.ReadWrite.All`, che è un permesso di **scrittura**, quindi `Directory.Read.All` è la scelta più restrittiva compatibile con un toolkit di sola lettura. Nel caso del `10` basterebbe la somma degli scope specifici (`RoleManagement.Read.Directory`, `User.Read.All`, `Application.Read.All`): se vuoi il minimo indispensabile, modifica quella riga. In entrambi i casi eseguire come Global Reader non concede nulla in scrittura.

## Dove finiscono i file

Tutti e dieci gli script esportano un CSV nella **directory corrente**, con un nome del tipo `Entra-<nome>-<yyyyMMdd>.csv`. Due conseguenze da tenere a mente:

- Il file nasce dove si trova il prompt, non accanto allo script. Se hai clonato il repository e lanci da lì, il CSV finisce dentro il clone: il `.gitignore` della radice esclude `*.csv`, ma controlla comunque `git status` prima di committare.
- Una seconda esecuzione nello stesso giorno sovrascrive la precedente senza chiedere. Usa `-OutputCsv` se devi conservare più fotografie dello stesso giorno.

Il contenuto è sensibile: email di persone esterne all'azienda (`06`), UPN degli amministratori e dei principal eleggibili in PIM (`01`, `02`), object ID dei gruppi (`07`), principal ID degli utenti che hanno dato un consenso (`09`). Sono dati personali, vanno conservati e cancellati come gli altri dati del tenant.

Attenzione infine alla differenza fra schermo e file: il `04` stampa a video soltanto le prime venti righe, mentre il CSV contiene tutto; il `10` stampa il riepilogo leggibile ed esporta una sola riga di sintesi.

## Esempi

```powershell
.\01-Get-EntraPrivilegedRoleMembers.ps1
.\04-Get-EntraExpiringAppCredentials.ps1 -Days 60
.\07-Get-EntraGroupsWithoutOwners.ps1
.\10-Get-EntraIdentitySummary.ps1

# Con percorso di output esplicito, per non sovrascrivere la raccolta precedente
.\01-Get-EntraPrivilegedRoleMembers.ps1 -OutputCsv C:\Audit\admin-2026-10-29-1430.csv
```

## Download e supporto

Lo stesso contenuto si scarica come archivio ZIP dalla pagina [synsphere.it/download/toolkit-powershell-entra-identity-governance](https://synsphere.it/download/toolkit-powershell-entra-identity-governance/). Se ti serve aiuto a leggere i risultati o a mettere a posto quello che emerge: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
