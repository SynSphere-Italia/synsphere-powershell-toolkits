# ACN Cyber Taxonomy

One script that downloads the ACN Cyber Taxonomy from its official source and tells you the exact tag to write, instead of inventing a code.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

The Cyber Taxonomy of ACN, Italy's National Cybersecurity Agency, is the shared vocabulary for describing cyber events and threats: every characteristic of an event becomes a tag in the form `acn:predicate="value"`. Besides the document, ACN publishes it as JSON in the form of a MISP taxonomy, and this script reads it from there on every run instead of carrying a copy that goes stale.

It is meant for whoever, in a small business or at an MSP, has to classify an incident with that vocabulary — typically for a notification or for internal reporting — and wants to check a tag before writing it down. The script filters by predicate, searches a word across values, labels and descriptions, validates a single tag and suggests similar values when the one you passed does not exist, exports the taxonomy to CSV, and generates an empty classification sheet to fill in.

On the machine it is read-only: it does not touch tenants, users, policies or settings, it needs no administrative permissions, and it installs nothing. The only write is the CSV — and where that file lands matters, see the last two sections.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `Get-AcnCyberTaxonomy.ps1` | Downloads the ACN Cyber Taxonomy from its MISP publication and makes it usable from the command line: filter by predicate, free-text search across values, labels and descriptions, validation of an `acn:predicate="value"` tag with suggestions for similar values, CSV export, and generation of a classification sheet to fill in, with the predicates grouped into four families. | Read-only on the machine and on the tenant; **WRITES** a CSV in the current directory |

There are five modes, all on the same file:

- no parameters — exports the whole taxonomy to CSV and prints the per-family summary;
- `-Predicato <name>` — only the values of one predicate (for example `impact`, `malicious-code`, `involved-asset`, `vector`);
- `-Cerca <text>` — searches the text across values, labels and descriptions, to find out what something is called in the ACN vocabulary;
- `-ValidaTag '<tag>'` — checks that the tag exists in the taxonomy and, if it does not, suggests similar values. It is the only mode that writes no file;
- `-SchedaEvento` — generates an empty classification sheet, one predicate per row, with the columns `ValoreScelto`, `TagRisultante` and `Note` to fill in.

Two parameters apply to every mode: `-File` reads a local copy of the JSON instead of downloading it, `-OutputCsv` decides where the CSV goes.

## Before you run it

**PowerShell 5.1 or later.** The script declares `#Requires -Version 5.1` — the only dependency declared in the code — and runs on PowerShell 7 as well.

**No module to install.** It uses built-in cmdlets only: `Invoke-WebRequest`, `ConvertFrom-Json`, `Get-Content`, `Export-Csv`, `Get-Date`, `Test-Path`. There is no `Import-Module` and no `#Requires -Modules` in the file, so no `Install-Module` is needed: it runs on a freshly installed workstation.

**No administrative permission and no sign-in.** There is no `#Requires -RunAsAdministrator`, and no `Connect-MgGraph`, `Connect-AzAccount` or `Connect-ExchangeOnline`: the script asks for no delegated or application permission, on any tenant, and there is no role to assign.

The two real requirements are different ones:

- **outbound HTTPS connectivity** to `raw.githubusercontent.com`, with a 60-second timeout on the download. You can avoid it entirely with `-File`, by passing a local copy of the JSON;
- **write permission in the directory you run the command from**, because that is where the CSV is created.

## ⚠️ Warnings

1. **The classification sheet is built from a list of predicates written inside the script, not from the one just downloaded.** The four families — Baseline Characterization, Threat Type, Threat Actor, Additional Context — and the predicates that make them up are our own grouping, hard-coded to make the output readable: they are not part of the ACN JSON. The `-SchedaEvento` branch iterates that internal list and not the downloaded data, and any predicate it does not find there is skipped without a word. The consequence is that a predicate added upstream would never show up in the sheet, and a renamed or removed one would disappear silently: the sheet can look complete without being complete, and it is exactly the artefact you fill in and pass around. Compare the number of rows in the sheet with the line the script prints on every run (`Tassonomia 'acn' — N predicati, N valori`), and run the command once with no parameters: the full export groups by family and shows a `(non classificato)` group holding the predicates the internal list does not know about.

2. **A second run on the same day overwrites the previous CSV, without asking.** The default name contains the date only (`.\ACN-SchedaEvento-20261029.csv`, `.\ACN-Tassonomia-20261029.csv`), `Export-Csv` is called without `-NoClobber`, and the script supports neither `-WhatIf` nor `-Confirm`. The scenario that costs most is the ordinary one: you generate the sheet, fill in `ValoreScelto` in Excel, then run `-SchedaEvento` again the same day for a second event, and the filled-in sheet is gone without a question. Whenever the sheet is going to be used for something, pass `-OutputCsv` with a name that identifies the event.

3. **The data comes from the MISP repository, branch `main`, with no integrity check.** On every run the script downloads `raw.githubusercontent.com/MISP/misp-taxonomies/main/acn/machinetag.json`: that is not an ACN endpoint, it is the taxonomy as published in the MISP project repository, and there is no checksum and no pinning to a commit. The content you classify an event with is therefore worth exactly what that branch is worth at the moment you read it. There is no code-execution risk — the content only goes through `ConvertFrom-Json`, and there is no `Invoke-Expression` anywhere in the file — the risk is availability and content: behind a corporate proxy the download fails and the script stops with a message pointing to `-File`. For a classification you need to be able to defend, check the tag against the ACN document; to work offline or from a frozen copy, download the JSON once and use `-File`.

4. **The numbers written in the script's own help do not update; the count on screen does.** The help at the top of the file quotes a fixed number of values and predicates, typed by hand: if ACN and MISP update the JSON, that number becomes false and nothing flags it — precisely because the taxonomy is not embedded. The real count is the one the script prints on every run, in the line `Tassonomia 'acn' — N predicati, N valori`. That is the only one to quote in a document: not the number in the help, not a number in this README.

5. **Even a plain search writes a CSV.** In the lookup branch the export happens before anything is printed: `-Predicato` and `-Cerca` show you the table of tags, but they have already written `.\ACN-Tassonomia-<date>.csv`. Two consequences: a quick lookup leaves a file in whatever folder you are standing in, and it overwrites the full export made the same day. If you are only looking up a word, run the command from a working folder, or pass `-OutputCsv` pointing at a temporary path. The only mode that writes nothing is `-ValidaTag`.

6. **`-ValidaTag` validates the predicate and the value, not the namespace.** If the namespace you pass differs from the taxonomy's own, the script flags it in yellow but carries on: `TAG VALIDO` can appear right underneath, and it refers to the predicate/value pair, not to the tag as you typed it. The accepted format is deliberately permissive — `acn:impact="..."`, `impact="..."`, `impact:...` — so the tag you typed and the tag the script validated may not be the same string. Always copy the canonical form from the `Tag` field in the output: that one is built from the taxonomy's real namespace.

## Where the output goes

Both CSVs have a default name that is **relative** to the current directory, and that name contains the date only:

- `.\ACN-Tassonomia-<yyyymmdd>.csv` — the taxonomy export, including when it is filtered by predicate or by search;
- `.\ACN-SchedaEvento-<yyyymmdd>.csv` — the classification sheet to fill in.

Two consequences to keep in mind every time:

- **The file is created where the prompt is, not where the script is.** If you cloned this repository and run from there, the CSV lands inside the clone. The `.gitignore` in the root excludes `*.csv`, but do not rely on it: check with `git status` before committing. And in a folder synced to OneDrive or SharePoint no `.gitignore` protects you.
- **A second run on the same day overwrites the previous one, without asking.** The name contains the date but not the time: to keep two results from the same day you need two different `-OutputCsv` values.

As for the content, unlike almost every other toolkit in this collection: the taxonomy export **contains no tenant data**. It is predicates, values, labels, descriptions and tags from a public vocabulary — no users, no addresses, no permissions, no credentials. The sheet, however, changes nature as soon as you fill it in: `ValoreScelto`, `TagRisultante` and `Note` describe a real incident, and from that moment it is an internal document to be treated as such, outside the repository and outside any folder you share by accident.

## Examples

```powershell
# What "ransomware" is called in the ACN vocabulary
.\Get-AcnCyberTaxonomy.ps1 -Cerca ransomware

# All the values of one predicate
.\Get-AcnCyberTaxonomy.ps1 -Predicato malicious-code

# Check a tag before writing it down: writes no file
.\Get-AcnCyberTaxonomy.ps1 -ValidaTag 'acn:impact="account-compromise"'

# Classification sheet for one event, with a name that will not be overwritten
.\Get-AcnCyberTaxonomy.ps1 -SchedaEvento -OutputCsv 'C:\Incidents\2026-014-classification.csv'
```

## More

The same content is available as a ZIP from [synsphere.it/download/script-powershell-tassonomia-cyber-acn/](https://synsphere.it/download/script-powershell-tassonomia-cyber-acn/).

If you need help classifying an event or setting up internal reporting: [synsphere.it/contattaci](https://synsphere.it/contattaci).

Data source: the ACN Cyber Taxonomy, published as a MISP taxonomy ([github.com/MISP/misp-taxonomies/tree/main/acn](https://github.com/MISP/misp-taxonomies/tree/main/acn)). Reference document: Agenzia per la Cybersicurezza Nazionale ([acn.gov.it](https://www.acn.gov.it/)). The script reads the official source: it does not replace the ACN document and is not an authoritative interpretation of it.

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
