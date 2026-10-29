# Microsoft 365 emergency: containment and evidence collection

Ten PowerShell scripts for the first hours of a compromised account: stop the access without destroying the evidence, and be able to go back.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

It is for the MSP technician, or the in-house IT of a small company, who has to contain a compromised account or a wire-transfer fraud on a Microsoft 365 / Entra ID tenant. In the first hours there are two opposite mistakes: acting and wiping the evidence, or collecting calmly and leaving the attacker inside.

The scripts cover the whole sequence: a go/no-go check of which evidence sources actually exist on that tenant, a reversible snapshot of account state, containment (disable plus session revocation), exports of sign-in logs, the Entra audit log, the unified audit log, message trace and mailbox rules and forwarding, a final HTML report, and the return to service.

Eight of the ten scripts are read-only. The two that write to the tenant, 03 and 04, simulate by default: without `-Esegui` they touch nothing.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Test-PrerequisitiEmergenza.ps1` | Go/no-go before containment: tells you whether Entra sign-in logs can be queried on this tenant, whether the unified audit log is recording, and whether the Exchange module is recent enough for `Get-MessageTraceV2`. Prints the real time window of each source. | Read-only |
| `02-Backup-StatoUtenti.ps1` | Snapshots the enabled state of every account before the block: this is what makes the block reversible. It also records which accounts are synchronised from Active Directory and who holds an admin role. | Read-only |
| `03-Invoke-BloccoEmergenza.ps1` | Containment: sets `AccountEnabled = false` and revokes active sessions. The revocation is the part that matters: without it, a refresh token already issued stays valid and the attacker keeps reading mail on an account the portal shows as blocked. Requires the snapshot from 02. | **WRITES** — simulates by default |
| `04-Restore-StatoUtenti.ps1` | Re-enables only the accounts that were enabled in the snapshot, so former employees and deliberately closed accounts stay closed. `-Utenti` limits the return to an explicit list. | **WRITES** — simulates by default |
| `05-Export-SignInLogs.ps1` | Exports Entra ID sign-ins and derives a second CSV of suspicious ones only: successful sign-ins with a risk outcome, legacy authentication protocols that bypass MFA, and unusual countries. | Read-only |
| `06-Export-AuditLogEntra.ps1` | Exports the Entra audit log and isolates seven families of events used to build persistence: authentication methods added, application consents and service principals, credentials added to an application, admin roles assigned, users created, domains added, conditional access policies changed. | Read-only |
| `07-Export-UnifiedAuditLog.ps1` | Exports the unified audit log (Exchange, SharePoint, Entra, Teams) with the correct paging: `-SessionCommand ReturnLargeSet` and the same `-SessionId` until zero records come back. Without that paging the search returns 100 records and no error. | Read-only |
| `08-Export-MessageTrace.ps1` | Exports mail in transit with `Get-MessageTraceV2`, splitting the window itself into the 10-day blocks the cmdlet imposes; a block that hits the 5,000-result ceiling is redone day by day. | Read-only |
| `09-Export-RegolePostaEInoltri.ps1` | Inventories mailbox-level forwarding and inbox rules: the persistence that stays active after the block and after the password reset. Sorted by severity, from the mailbox forward the user cannot see in Outlook down to suspicious rule names. | Read-only |
| `10-New-ReportIncidente.ps1` | Builds a single HTML report from the CSVs collected. Where a source is missing it writes that it is missing, not zero. It does not query the tenant: it can run on another machine, after the incident. | Read-only (no tenant connection) |

## Before you run them

- **PowerShell 5.1 or PowerShell 7.** No script enforces it with `#Requires -Version`: on an older version the failure arrives mid-run, not at startup.
- **Microsoft Graph** (scripts 01-06): `Install-Module Microsoft.Graph -Scope CurrentUser`
- **Exchange Online** (scripts 07, 08, 09): `Install-Module ExchangeOnlineManagement -Scope CurrentUser` — **version 3.7.0 or later is required**, because `Get-MessageTraceV2` does not exist before it and `Get-MessageTrace`, the historical cmdlet, is deprecated. Check with `Get-Module -ListAvailable ExchangeOnlineManagement`, update with `Update-Module ExchangeOnlineManagement`.
- Script 10 needs no modules and no tenant connection: it only reads the CSVs already collected.

Read-only roles (scripts 01, 02, 05, 06, 07, 08, 09): **Global Reader** for the Microsoft Graph side; **Security Reader** or **Reports Reader** for sign-in logs and the Entra audit log; **View-Only Organization Management** for the Exchange side; **View-Only Audit Logs** for the unified audit log.

Write roles (scripts 03 and 04): **User Administrator** or **Global Administrator**.

Graph scopes requested by the code: `AuditLog.Read.All`, `Directory.Read.All`, `User.Read.All` in 01; `User.Read.All`, `Directory.Read.All`, `RoleManagement.Read.Directory` in 02; `AuditLog.Read.All`, `Directory.Read.All` in 05 and 06; `User.ReadWrite.All`, `Directory.ReadWrite.All` in 03 (see warning 6); `User.ReadWrite.All` in 04. Scripts 07, 08 and 09 do not use Graph: they authenticate with `Connect-ExchangeOnline`.

**Order in an emergency:** `01 → 02 → 03 → 05 → 06 → 09 → 07 → 08 → 10 → 04`. Script 02 always comes before 03: without that snapshot the block is not reversible, because afterwards there is no way left to know which accounts were already disabled before the incident, and re-enabling them all would put former employees and deliberately closed accounts back in service. Script 04 comes last.

Before you run 03:

- 02 has been run and its CSV is stored outside the tenant;
- there is at least one working, uncompromised break-glass account to pass in `-Escludi`;
- 03 has been run first in simulation, without `-Esegui`, and the list has been read in full.

How far back you can look, because it is the constraint that decides the whole collection:

- **Entra ID sign-in logs**: 30 days with P1 or P2, 7 days with Entra ID Free. They require P1 or P2: on Business Basic and Standard they do not exist through the API, and the call fails with an error that looks like a permission problem. Business Premium includes P1.
- **Entra audit log**: 30 days with P1 or P2.
- **Unified audit log**: 180 days with Audit Standard (the default since 17 October 2023), one year only with Audit Premium or E5, and only if logging was already on when the events happened: turning it on now does not recover the past. If script 07 reports that it hit the 50,000-record session ceiling, that is not "all the events": re-run it over narrower windows.
- **Message trace**: 90 days, at most 10 days per query.

## ⚠️ Warnings

1. **The automatic Global Administrator exclusion may protect nobody, and it fails without an error.** Script 03 skips Global Administrators by reading the `RuoliAdmin` column of the snapshot, and that column falls silent in three ways: if reading the roles fails in 02, the script only emits a warning and carries on, so `RuoliAdmin` stays empty for everyone, and 03 validates the `AccountEnabled` column only, so it accepts that snapshot; the comparison is a substring match on the role display name (`Global Administrator` or `Amministratore globale`), while the directory APIs also return that role as `Company Administrator`, and in a tenant in another language under a third name again; and only active assignments are read, so Global Administrators who are eligible through PIM — the configuration Microsoft recommends — do not appear in the snapshot at all. In each of the three cases, with `-Esegui` the Global Administrators are disabled, break-glass included if it is not listed in `-Escludi`, and the summary prints "Accounts excluded: 0", indistinguishable from "there were no administrators". Always pass the break-glass accounts in `-Escludi` by hand, and before `-Esegui` open the snapshot and check that the `RuoliAdmin` column is actually populated: do not rely on the automatic exclusion.

2. **Script 09 can conclude "no external forwarding found" on a compromised tenant.** Every mailbox it fails to read, because of Exchange Online throttling, missing permissions or an inaccessible mailbox, is discarded without leaving a trace, and the summary does not say how many mailboxes were skipped. If none of the mailboxes actually read has a forward, the script prints in green that it found none: a scan throttled at 90% therefore produces a reassuring result. This is the most dangerous false negative in the toolkit. Compare the number of mailboxes examined with the real number of mailboxes in the tenant, start from `-Utenti` on the suspect mailboxes, and re-run the full scan: a number without its denominator proves no absence.

3. **`-Esegui -Confirm:$false` on 03 removes the last safety net.** After `-Esegui` the only gate left is the per-account confirmation prompt; `-Confirm:$false` removes it, and the script disables and revokes the sessions of every account that was enabled in the snapshot without asking a single question. There is no aggregate confirmation: the summary prints the number of accounts in scope but does not ask you to confirm it. Do not pass `-Confirm:$false`, and read the simulation list before executing.

4. **The scope of 03 includes service accounts, and on a hybrid tenant it stops synchronisation.** The scope is "every account that was enabled in the snapshot", minus the operator, minus Global Administrators, minus `-Escludi`: that includes the Entra Connect synchronisation account (`Sync_*@*.onmicrosoft.com`), which holds the Directory Synchronization Accounts role and therefore does not match the exclusion filter. Disabling it breaks directory synchronisation and password hash sync exactly while you are containing the incident, and restoring that account is not covered by these scripts. Always pass the synchronisation account and the other service accounts (Directory Synchronization Accounts, Partner Tier1 and Tier2 Support) in `-Escludi` together with the break-glass accounts. The mirror image of the same problem: on accounts synchronised from Active Directory the cloud-side block is overwritten at the next synchronisation cycle, and they must be disabled in AD; 02 and 03 count them and flag them separately.

5. **An `-OutputCsv` value that does not end in `.csv` destroys the main export.** Scripts 05, 06 and 09 write a second, filtered CSV (`-SOSPETTI`, `-PERSISTENZA`, `-INOLTRI-CASSETTA`) whose path is derived from `-OutputCsv` by replacing the trailing `.csv`. If the value passed does not end in `.csv` the replacement matches nothing and the two paths coincide: the complete export, just written, is overwritten by the filtered subset alone, with no error. `.\IR-05` and `.\export.csv.bak` collide; `.\IR-05.csv` and `D:\caso\export.CSV` are fine. In a forensic context that means keeping the filter and losing the primary evidence. Leave the default, or pass a path that ends in `.csv`.

6. **Script 03 asks for a broader Graph consent than it uses.** It requests `User.ReadWrite.All` and `Directory.ReadWrite.All`, but performs only two writes: disabling the account and revoking the sessions. `Directory.ReadWrite.All` is one of the broadest scopes in Graph, with write access to groups, applications, service principals, devices and directory settings, and neither write needs it: the proof is in this same toolkit, since 04 performs the same `Update-MgUser` with `User.ReadWrite.All` alone. That consent is put in front of an administrator under pressure, during an incident — the worst possible moment to approve a scope that is not needed: if the consent dialog appears, grant `User.ReadWrite.All` (tighter still: `User.EnableDisableAccount.All` and `User.RevokeSessions.All`). The same holds in miniature on the read-only side: 05 and 06 ask for `Directory.Read.All` but only call the log cmdlets.

## Where the output goes

The scripts export to the **current directory**, with a file name containing the date and the time to the minute (`IR-02-StatoUtenti-20260828-1030.csv` and similar); 10 produces an `IR-Report-<date-time>.html`. Every path is parameterised. Two consequences to keep in mind:

- **The file is created wherever the prompt is.** If you cloned the repository and run the scripts from inside the clone, the CSVs land in the clone: do not commit them. The `.gitignore` in the root excludes `*.csv`, `*.json` and `*.html`, but do not trust the filter: check `git status` before adding anything.
- **Two runs in the same minute overwrite each other without asking**, because no `Export-Csv` uses `-NoClobber`. If you re-run an export right after the previous one, pass a different `-OutputCsv` — one ending in `.csv` (see warning 5).

These files contain customer data: the tenant ID, every UPN and display name, the list of external guest accounts, the IP addresses the sign-ins came from, the subjects and MessageIds of mail items, and the inbox rules with their forwarding destinations. Treat them as incident material: outside the repository, outside the compromised tenant, on controlled storage.

One note on the report: 10 looks for the CSVs by name (`IR-05-SignIn-*-SOSPETTI.csv` and similar) in the folder you point it at. If you changed the names with `-OutputCsv`, the report declares that source **missing** even though you collected it. In the report "missing" does not mean "empty", and that is deliberate: "no suspicious sign-ins" when the sign-in logs were never downloaded would be the most dangerous conclusion a tool like this could produce.

## Examples

```powershell
# The state snapshot, mandatory before any block
.\02-Backup-StatoUtenti.ps1

# Containment in simulation: shows who would be blocked, touches nothing
.\03-Invoke-BloccoEmergenza.ps1 -SnapshotCsv .\IR-02-StatoUtenti-20260828-1030.csv

# List read, now it runs for real, with the break-glass account excluded
.\03-Invoke-BloccoEmergenza.ps1 -SnapshotCsv .\IR-02-StatoUtenti-20260828-1030.csv -Escludi 'breakglass@contoso.com' -Esegui

# Return to service in waves, one group of users at a time
.\04-Restore-StatoUtenti.ps1 -SnapshotCsv .\IR-02-StatoUtenti-20260828-1030.csv -Utenti 'mario.rossi@contoso.com','anna.bianchi@contoso.com' -Esegui
```

## Closing

The same content is available as a ZIP archive from the download page, [Toolkit PowerShell: emergenza compromissione Microsoft 365](https://synsphere.it/download/toolkit-powershell-emergenza-compromissione-microsoft-365/). If you need support during an incident in progress: [synsphere.it/contattaci](https://synsphere.it/contattaci).

What these scripts do not do: they do not remove malicious rules or application consents, they find them and list them, because removal has to be decided case by case; they do not force a password reset, which depends on the return-to-service plan; and they do not replace incident response carried out by people. The report gathers indicators, it does not establish whether a compromise occurred: that remains a human judgement. Provided "as is", without warranty: try it in a test environment before you actually need it.

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
