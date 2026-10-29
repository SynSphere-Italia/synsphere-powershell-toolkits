# Contribuire

Questi script nascono dal lavoro quotidiano di SynSphere Italia sui tenant dei
nostri clienti. Li pubblichiamo perché ci sembra più utile che tenerli in un
cassetto — e perché un errore trovato da qualcun altro è un errore in meno.

## Che cosa ci è utile davvero

In ordine di valore:

1. **"Questo script non fa quello che dice."** È la segnalazione più preziosa.
   Indica lo script, cosa ti aspettavi e cosa è successo. Se puoi, allega
   l'output (rimuovendo i dati del tuo tenant).
2. **"Questo script chiede più permessi del necessario."** Ogni script dichiara
   i propri scope Graph o ruoli Azure nell'header. Se basta `.Read.All` dove noi
   chiediamo `.ReadWrite.All`, vogliamo saperlo.
3. **"Questo non funziona più."** Le API Microsoft cambiano: cmdlet deprecati,
   proprietà rinominate, moduli sostituiti. Una segnalazione di questo tipo ci
   risparmia di scoprirlo da un cliente.
4. **Uno script nuovo.** Benvenuto, se rispetta le convenzioni qui sotto.

## Convenzioni

Sono poche e tutte verificabili dalla pipeline di analisi:

- **Comment-based help obbligatorio**: `.SYNOPSIS`, `.DESCRIPTION`, almeno un
  `.EXAMPLE`, e in `.NOTES` i permessi richiesti.
- **`[CmdletBinding()]` e parametri tipizzati.** Niente valori cablati dove
  serve un parametro: percorsi di output, soglie, nomi di dominio.
- **Chi scrive, dichiara di scrivere.** Uno script che modifica qualcosa usa un
  verbo che non è `Get-` e supporta `-WhatIf` tramite
  `[CmdletBinding(SupportsShouldProcess)]`. Questa non è una preferenza di
  stile: è la differenza fra una prova e un danno.
- **Nessun segreto, mai.** Né password, né token, né tenant ID reali, né nomi di
  clienti. L'autenticazione passa dai cmdlet `Connect-*`. La pipeline fa fallire
  il build se trova un segreto letterale.
- **UTF-8 e CRLF**, come dice `.editorconfig`. I messaggi a schermo sono in
  italiano e contengono accenti: una codifica sbagliata li rende illeggibili.
- **Gestione degli errori leggibile.** `$ErrorActionPreference = 'Stop'` e, dove
  un fallimento è prevedibile (permessi mancanti, oggetto inesistente), un
  `try/catch` che spiega all'utente che cosa fare — non uno stack trace.

Prima di aprire una pull request:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path .\percorso\al\tuo-script.ps1 -Severity Error,Warning
```

## Che cosa non accettiamo

- Script che inviano dati a un endpoint di terze parti.
- Script che richiedono di incollare una password o un token nel codice.
- Dipendenze da moduli non pubblicati sulla PowerShell Gallery.
- Contributi che aggiungono il nome di un cliente, nostro o vostro.

## Aspettative, dette chiaramente

Manteniamo questi script perché li usiamo. Rispondiamo alle issue, ma **non**
garantiamo tempi di risposta su richieste di funzionalità, e può capitare che
un contributo valido resti in attesa. Se ti serve qualcosa con una scadenza,
[scrivici](https://synsphere.it/contattaci): è un altro tipo di conversazione.

---

# Contributing (English)

These scripts come out of SynSphere Italia's daily work on customer tenants. We
publish them because that seems more useful than keeping them in a drawer — and
because a bug someone else finds is one bug fewer.

## What actually helps

1. **"This script doesn't do what it says."** The most valuable report. Name the
   script, what you expected, what happened. Attach output with your tenant's
   data removed.
2. **"This script asks for more permissions than it needs."** Each script
   declares its Graph scopes or Azure roles in its header. If `.Read.All` is
   enough where we ask for `.ReadWrite.All`, tell us.
3. **"This no longer works."** Microsoft APIs change. Hearing it from you beats
   hearing it from a customer.
4. **A new script**, if it follows the conventions below.

## Conventions

All of them are checked by the analysis pipeline:

- **Comment-based help is mandatory**: `.SYNOPSIS`, `.DESCRIPTION`, at least one
  `.EXAMPLE`, and the required permissions in `.NOTES`.
- **`[CmdletBinding()]` and typed parameters.** No hard-coded values where a
  parameter belongs.
- **If it writes, it says so.** A script that changes anything uses a verb other
  than `Get-` and supports `-WhatIf` via
  `[CmdletBinding(SupportsShouldProcess)]`. This is not a style preference: it
  is the difference between a rehearsal and damage.
- **No secrets, ever.** No passwords, tokens, real tenant IDs or customer names.
  Authentication goes through the `Connect-*` cmdlets. CI fails the build on a
  literal secret.
- **UTF-8 and CRLF**, as `.editorconfig` says. On-screen messages are in Italian
  and contain accented characters; the wrong encoding makes them unreadable.
- **Readable error handling.** `$ErrorActionPreference = 'Stop'`, and a
  `try/catch` that tells the user what to do wherever failure is foreseeable —
  not a stack trace.

## What we don't accept

Scripts that send data to third-party endpoints; scripts that require pasting a
password or token into the code; dependencies on modules not published on the
PowerShell Gallery; contributions that add a customer's name.

## Expectations, stated plainly

We maintain these scripts because we use them. We answer issues, but we do **not**
promise response times on feature requests, and a valid contribution may sit for
a while. If you need something by a deadline,
[get in touch](https://synsphere.it/contattaci) — that's a different conversation.
