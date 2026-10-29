# Defender & Security Posture Toolkit

Ten read-only reports that measure the security posture of a Microsoft 365 and Defender tenant and export it to CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

This collection is aimed at Microsoft 365 administrators and managed service providers who have to produce periodic, repeatable evidence about the security of a tenant: the monthly report to the customer, the material to attach to an audit, the snapshot of the state of the controls that a NIS2 risk analysis starts from. Each script queries Microsoft Graph on a different area — current Secure Score, its history and its improvement actions, Defender alerts and incidents, risky users and risk detections from Entra ID Protection, MFA and SSPR coverage per user, inventory of conditional access policies — prints a summary on screen and exports a CSV.

None of the ten scripts changes the tenant configuration: they are all `Get-*` calls plus the export, and every Graph scope they ask for is `.Read.All`. The risk, as the warnings section explains, is misreading the result — not damaging the environment.

The collection is a companion to [email-security](../email-security/): this one looks at posture (scores, alerts, identities, MFA, conditional access), not at mail flow or quarantine.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-SecureScoreCurrent.ps1` | The latest Microsoft Secure Score measurement: current score, maximum and percentage, with the date, the active users and the licensed ones. It is the single summary indicator of Microsoft 365 and Defender posture. | Read-only |
| `02-Get-SecureScoreTrend.ps1` | The last N daily Secure Score measurements (`-Days`, default 30) with score, maximum and percentage per date: it tells you whether posture is improving or getting worse. | Read-only |
| `03-Get-SecureScoreImprovementActions.ps1` | Cross-references the per-control scores of the latest Secure Score with the maximum of each control profile and computes the gap, that is the points still available. Sorted from the largest gap down: a concrete priority list. | Read-only |
| `04-Get-SecurityAlerts.ps1` | The alerts from the unified Microsoft 365 Defender API, by default only those not yet resolved (`-IncludeResolved` adds the resolved ones), with severity, status, title, category, originating product and date. See warning 1 about the ordering. | Read-only |
| `05-Get-SecurityIncidents.ps1` | The incidents, that is correlated groupings of alerts, by default only the unresolved ones (`-IncludeResolved`), with severity, status, classification, determination, assignee and date. It is the high-level monitoring view. | Read-only |
| `06-Get-RiskyUsers.ps1` | The users flagged with a risk level by Entra ID Protection (anomalous sign-ins, leaked credentials), by default only those not yet remediated (`-IncludeRemediated`), with risk level and risk state. | Read-only |
| `07-Get-RiskDetections.ps1` | The individual risk detections — impossible travel, anonymous IP, leaked credentials — with type, level, state, user, IP address and city/country. `-Top` caps how many events are retrieved, default 200. | Read-only |
| `08-Get-MfaRegistrationReport.ps1` | Uses the official authentication methods report to list, user by user, whether they are MFA- and SSPR-capable and registered, which methods they have registered and whether they are an administrator. `-OnlyGaps` keeps only the users who are not MFA-capable. | Read-only |
| `09-Get-ConditionalAccessPolicies.ps1` | Every conditional access policy with its state (enabled, report-only, disabled), the grant controls required, the operator and the creation and modification dates: it documents the rules that protect sign-ins. | Read-only |
| `10-Get-SecurityPostureSummary.ps1` | The single dashboard: Secure Score, open high and medium alerts, open incidents and MFA coverage brought together in one dated summary row, convenient to attach to a periodic report. See warnings 2 and 3. | Read-only |

## Before you run them

**PowerShell 5.1 or PowerShell 7.** That is the requirement that came with the collection; none of the ten scripts declares a minimum version with `#Requires -Version`, so on an older host there is nothing that will stop by itself.

**Microsoft Graph PowerShell SDK, and the `#Requires` lines are incomplete.** All ten declare only `Microsoft.Graph.Authentication` on their first line, which provides `Connect-MgGraph` and nothing else: the `Get-Mg*` cmdlets they go on to use live in other submodules. If you install only what the `#Requires` declares, the first `Get-Mg*` answers "term not recognized" halfway through the script, instead of the clean error `#Requires` would raise at startup. The short route is the meta-module:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

Alternatively, only the submodules actually used:

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Security, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Reports -Scope CurrentUser
```

Which script uses what: `Microsoft.Graph.Authentication` all ten; `Microsoft.Graph.Security` 01, 02, 03, 04, 05 and 10; `Microsoft.Graph.Identity.SignIns` 06, 07 and 09; `Microsoft.Graph.Reports` 08 and 10.

**Authentication and consent.** Each script calls `Connect-MgGraph` with only the scopes it needs. They are all delegated and all read-only, but they require administrator consent: on the first run the consent screen appears for that script's scopes.

| Script | Graph scopes requested |
| --- | --- |
| 01, 02, 03 | `SecurityEvents.Read.All` |
| 04 | `SecurityAlert.Read.All` |
| 05 | `SecurityIncident.Read.All` |
| 06 | `IdentityRiskyUser.Read.All` |
| 07 | `IdentityRiskEvent.Read.All` |
| 08 | `AuditLog.Read.All` |
| 09 | `Policy.Read.All` |
| 10 | `SecurityEvents.Read.All`, `SecurityAlert.Read.All`, `SecurityIncident.Read.All`, `AuditLog.Read.All` |

**Entra role: Security Reader.** For Secure Score (01, 02, 03), for conditional access policies (09) and for the MFA registration report (08, 10), Security Reader is exactly the minimum role documented by Microsoft: nothing more is needed. For the Identity Protection endpoints (06, 07) we did not verify the role separately, so if either of them answers with an access denied, that is where to look first. One caveat that concerns 09: with Security Reader, conditional access policies are readable only in their "standard properties", so the inventory may contain fewer fields than the portal shows — with no error, and with nothing in the CSV to flag it.

**Licensing.** The complete Identity Protection data (06, 07) requires Microsoft Entra ID P2. Secure Score and Identity Protection both depend on the licences active in the tenant: if a value comes out empty, the plan is the first thing to check — and see warning 3, because that case does not always present itself as an error.

**They stop at the first error.** All ten set `$ErrorActionPreference = 'Stop'` and none has a `try/catch`, while `Export-Csv` is among their last statements. If a Graph call fails — a missing permission, throttling — the run ends before the write and not even a partial file is left. Run them one at a time, and re-run the one that stopped once you have fixed the cause.

## ⚠️ Warnings

1. **`04` sorts the alerts the opposite way from what it promises: the twenty on screen are the LEAST severe.** The sort is `Sort-Object @{ E = { $sevOrder[[string]$_.Severita] } }, Creato -Descending`, and in PowerShell `-Descending` applies to **all** of `Sort-Object`'s keys, not just the last one. Since the severity map is `@{ high = 0; medium = 1; low = 2; informational = 3 }`, descending order puts `informational` first and `high` last: the `Select-Object -First 20` therefore shows the twenty least severe alerts, and the CSV is exported in the same inverted order, while the `.DESCRIPTION` claims it "sorts by severity for triage". The script does the opposite, both on screen and in the file. Do not use 04's on-screen table to decide where to start: re-sort the CSV on the `Severita` column (high, medium, low, informational) and check that the first rows are the `high` ones before attaching it to a report.

2. **The "MFA coverage" in `10` and the user total in `08` count only ENABLED accounts.** Both start from `Get-MgReportAuthenticationMethodUserRegistrationDetail`, and the Microsoft Graph documentation for the `/reports/authenticationMethods/userRegistrationDetails` endpoint states that the method does not return disabled users: disabled accounts are simply absent from the collection. So `UtentiTotali` in 10's CSV is not "the tenant's users" but "the enabled users", and `MfaCoperturaPct` is a share of enabled accounts only; the same applies to the "Utenti nel report" count printed by 08. The error runs in the flattering direction — coverage looks higher than it is — and neither the script nor the output says so. When you use these numbers as evidence, write the denominator and its source next to them ("out of N enabled users, Graph authentication methods report"), or cross-reference `Get-MgUser` to count the disabled accounts separately. A number without its denominator misleads.

3. **When Secure Score is unavailable, `10` prints `0/0` and writes a CSV indistinguishable from a real measurement of zero.** 01 and 03 have the guard `if (-not $s) { Write-Host 'Nessun Secure Score disponibile.'; return }`; 10 and 02 use the same cmdlet but do not. In 10, with `$score` null, `[math]::Round($null.CurrentScore, 1)` raises no exception at all: it returns `0`. The summary therefore prints `Secure Score        : % (0/0)` and exports a row with `SecureScorePct` empty and `SecureScore`/`SecureScoreMax` null — and in an audit document a zero reads as a measurement, not as a missing one. 02, which also lacks the guard, runs to the end announcing "Esportati 0 rilevamenti" and writes a file with no rows. The case is expected, not theoretical: Secure Score depends on the active licences. Before using 10's summary, run 01, which states the case in words; and if the field is empty, write it as "not available" in the document you hand over, not as a zero.

4. **The output contains personal data, and the CSV from `08 -OnlyGaps` is a list of targets.** There is no personal data in the collection's own files, but there is in the files the scripts produce: 07 exports UserPrincipalName, IP address, city and country for every detection; 06 exports UPN and display name; 08 exports UPN, display name, MFA state and the administrator flag. In particular, 08 run with `-OnlyGaps` produces a plain-text list of the accounts **without MFA, administrators included**: a ready-made target list, written in the clear in the working directory. This is personal data in scope for GDPR articles 5 and 32. Treat that CSV as confidential material: keep it out of shared folders and off email, delete it once the gap is closed, and never commit it (see the next section).

5. **`AuditLog.Read.All` (08, 10) grants the ability to read the tenant's entire audit log and all of its sign-in logs, not just the MFA report.** For this endpoint it is the least-privileged permission documented by Microsoft and no narrower alternative exists: the script is not asking for more than it needs. The point is that the scope is broad in its **effects**, because the underlying Entra permissions are `microsoft.directory/auditLogs/allProperties/read` and `microsoft.directory/signInReports/allProperties/read` — reading every audit and sign-in log in the tenant, far beyond "the MFA report". The scope name on the `Connect-MgGraph` screen does not convey this. Know it before you consent, and tell the customer on whose tenant you are consenting.

6. **`SecurityEvents.Read.All` (01, 02, 03, 10) reads every security alert, not only the scores.** It is the documented minimum privilege for `GET /security/secureScores`, and Microsoft's own Secure Score page flags it as an unavoidable over-grant: the scope gives access to all security alerts and nothing narrower exists. This is a property of the API, not a choice of the toolkit, but the consent you grant is wider than "read the score". If that is unacceptable for a customer, the only routes are to isolate the Secure Score calls in a separate app registration, or to give up scripts 01, 02 and 03.

## Where the output goes

All ten export a CSV through `-OutputCsv`, whose default value is a path **relative** to the current directory and contains only the date: `.\SecureScore-Current-20261029.csv`, `.\Defender-Alerts-20261029.csv`, `.\MFA-Registration-20261029.csv` and so on. Two consequences to keep in mind every time:

- **The file lands where the prompt is, not where the script is.** If you have cloned this repository and run from there, the CSV ends up inside the clone. The `.gitignore` in the root excludes `*.csv`, but do not rely on it: check with `git status` before committing. And in folders synced to OneDrive, SharePoint or Dropbox no `.gitignore` protects you at all.
- **A second run on the same day overwrites the first one, without asking.** The name carries the date but not the time, and `Export-Csv` is called without `-NoClobber`: the evidence taken this morning is replaced by this evening's. If you need to compare a before and an after, or to keep evidence you have already produced, pass `-OutputCsv` with different names.

The content deserves to be protected like a confidential document, because taken together it tells an attacker which accounts to aim at and which controls they will have to get around: user names in the clear (06, 07, 08), IP addresses with the city and country of risky sign-ins (07), MFA state and administrator flag for every user (08, 10), and the inventory of the conditional access rules that protect the tenant (09).

## Examples

```powershell
# Current Secure Score, and the actions with the largest score gap
.\01-Get-SecureScoreCurrent.ps1
.\03-Get-SecureScoreImprovementActions.ps1

# Wider windows: 90 trend measurements, 500 risk detections
.\02-Get-SecureScoreTrend.ps1 -Days 90
.\07-Get-RiskDetections.ps1 -Top 500

# Only the users without MFA: treat the output as confidential (warning 4)
.\08-Get-MfaRegistrationReport.ps1 -OnlyGaps

# Summary dashboard, written outside the cloned repository
.\10-Get-SecurityPostureSummary.ps1 -OutputCsv 'C:\Audit\posture-20261029.csv'
```

## More

The same content is available as a ZIP from [synsphere.it/download/toolkit-powershell-defender-sicurezza/](https://synsphere.it/download/toolkit-powershell-defender-sicurezza/).

If you need help reading the reports, or closing the gaps they found: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
