# Sicurezza / Security

## Perché questo file conta qui più che altrove

Gli script di questo repository si eseguono con credenziali amministrative su
tenant Microsoft 365 e sottoscrizioni Azure **di produzione**. Un difetto in uno
script di sola lettura è un fastidio; un difetto in uno script che rimuove
licenze, disabilita utenti o modifica una policy può fermare un'azienda.

Per questo trattiamo le segnalazioni di sicurezza in modo diverso dalle altre.

## Come segnalare un problema

**Non aprire una issue pubblica** se pensi che il problema possa essere usato per
fare danno. Scrivi a **info@synsphere.com** con oggetto `SECURITY: synsphere-powershell-toolkits`.

Nella segnalazione indica:

- quale script e quale riga;
- che cosa succede di sbagliato, e in quali condizioni;
- l'impatto: che cosa può rompersi in un tenant reale;
- se l'hai riprodotto, come.

Rispondiamo entro **5 giorni lavorativi**. Se il problema è confermato e grave,
pubblichiamo la correzione e, nelle note di rilascio, diciamo che cosa era
sbagliato — senza nominare chi l'ha segnalato, a meno che non lo chieda.

Per tutto il resto — un parametro che non funziona, un messaggio sbagliato, una
proposta — una issue pubblica va benissimo.

## Che cosa questi script NON fanno

Per togliere ambiguità a chi li legge prima di eseguirli:

- **non contengono credenziali.** Nessuna password, nessun token, nessun client
  secret. L'autenticazione passa da `Connect-MgGraph`, `Connect-ExchangeOnline`
  o `Connect-AzAccount`, che aprono il browser e usano la tua identità e la tua
  MFA. Una pipeline di analisi su ogni push verifica che nessun segreto in
  chiaro entri nel repository.
- **non inviano dati a nessuno.** Nessuno script contatta synsphere.it, né invia
  dati del tuo tenant a noi o a terzi. Gli output restano sul tuo disco.
- **un solo script su 247 fa una chiamata di rete**, e la dichiara nel proprio
  help: `security/acn-cyber-taxonomy/Get-AcnCyberTaxonomy.ps1` scarica in sola
  lettura (GET) la Tassonomia Cyber dell'ACN da
  `raw.githubusercontent.com/MISP/misp-taxonomies`, la fonte in cui l'ACN la
  pubblica. È una scelta esplicita: non ridistribuiamo il lavoro dell'ACN e non
  teniamo una copia che invecchia. Non invia niente. Tutti gli altri 246 script
  parlano solo con gli endpoint Microsoft a cui ti sei connesso.
- **non chiedono più permessi del necessario.** Ogni script dichiara nel proprio
  header gli scope Graph o i ruoli Azure che richiede. Se trovi uno scope più
  ampio del necessario, è un difetto: segnalalo.

## Prima di eseguirli

1. **Leggi l'header.** Ogni script dichiara cosa fa, cosa richiede e se scrive.
2. **Gli script che scrivono sono riconoscibili**: il verbo nel nome non è `Get-`.
   Quelli che supportano `-WhatIf` vanno eseguiti **prima** con `-WhatIf`.
3. **Prova su un tenant non critico** o su un sottoinsieme ristretto.
4. Gli script sono forniti **"as is"**: la responsabilità dell'esecuzione in un
   ambiente di produzione resta di chi li esegue.

---

# Security (English)

## Why this file matters more here

The scripts in this repository run with administrative credentials against
**production** Microsoft 365 tenants and Azure subscriptions. A bug in a
read-only script is an annoyance; a bug in one that removes licences, disables
users or changes a policy can stop a company from working.

## Reporting a vulnerability

**Do not open a public issue** if you believe the problem could be used to cause
harm. Email **info@synsphere.com** with the subject
`SECURITY: synsphere-powershell-toolkits`, and include: the script and line, what
goes wrong and under which conditions, the impact on a real tenant, and repro
steps if you have them.

We reply within **5 working days**. Confirmed, serious issues get a fix and a
release note describing what was wrong. We do not name the reporter unless asked.

Anything else — a broken parameter, a wrong message, a suggestion — is welcome as
a public issue.

## What these scripts do not do

- **No embedded credentials.** Authentication goes through `Connect-MgGraph`,
  `Connect-ExchangeOnline` or `Connect-AzAccount`, using your identity and MFA.
  A CI check on every push fails the build if a literal secret appears.
- **No telemetry.** No script contacts synsphere.it, and none sends your tenant's
  data to us or to anyone else. Output stays on your disk.
- **Exactly one script out of 247 makes a network call**, and declares it in its
  own help: `security/acn-cyber-taxonomy/Get-AcnCyberTaxonomy.ps1` performs a
  read-only GET to fetch the Italian cybersecurity agency's Cyber Taxonomy from
  `raw.githubusercontent.com/MISP/misp-taxonomies`, where ACN publishes it. That
  is deliberate: we do not redistribute ACN's work, and we do not keep a copy
  that goes stale. It sends nothing. The other 246 scripts talk only to the
  Microsoft endpoints you connected to.
- **No excessive permissions.** Each script declares the Graph scopes or Azure
  roles it needs in its header. A scope wider than necessary is a bug — report it.

## Before you run them

Read the header; run `-WhatIf` first on any script whose verb is not `Get-`; test
on a non-critical tenant. The scripts are provided **"as is"** — running them in
production is your responsibility.
