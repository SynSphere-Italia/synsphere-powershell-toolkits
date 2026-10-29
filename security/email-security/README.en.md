# Microsoft 365 Email Auditing and Security Toolkit

Ten read-only PowerShell reports that pull the mail audit data out of Exchange Online — traffic per address, filter verdicts, deletions, delegated sends, non-owner access, rules, connectors, quarantine — one CSV each.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

This is for anyone who has to assess the mail of a Microsoft 365 tenant, document an incident or answer an internal dispute: IT administrators and MSPs working on their own tenants or on other people's. It writes down what the portal only shows one screen at a time: how much traffic each address carries, what the anti-spam and anti-phishing filter stopped, who deleted which emails, who sent on whose behalf, who opened somebody else's mailbox, which transport rules and which connectors are in place.

None of the ten scripts changes the tenant: there is not a single write cmdlet in the collection, and the only thing written is the CSV on the local disk. Authentication is interactive through `Connect-ExchangeOnline`: the browser opens, MFA works, no password is stored in the scripts, and each script inherits the permissions of the account that runs it.

Script 07 goes first and does not stand on its own: it tells you whether mailbox auditing is on, that is, whether audits 03-06 have anything to read (warning 2).

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-M365MailTrafficReport.ps1` | Messages sent and received by each address over the requested window, aggregated from the message trace. `Get-MessageTrace` only covers the last 10 days: longer windows need the portal's historical report or `Get-MessageTraceV2`. | Read-only |
| `02-Get-M365MailFlowStatusReport.ps1` | Message counts by type (GoodMail, Spam, Malware, Phish, EdgeBlockSpam) and by direction. An unusual rise in outbound spam or malware is the classic sign of a compromised account. | Read-only |
| `03-Get-M365EmailDeletionAudit.ps1` | Deletion operations from the Unified Audit Log (SoftDelete, HardDelete, MoveToDeletedItems): who deleted what and when, with the subject of the affected items. For disputes and suspected deliberate deletion. | Read-only |
| `04-Get-M365SendAsAudit.ps1` | SendAs operations: who sent on whose behalf, with the date and subject of the message. For checking how Send As delegations are being used, legitimately or not. | Read-only |
| `05-Get-M365SharedMailboxSendingAudit.ps1` | Sends from shared mailboxes (SendAs and SendOnBehalf) with the real person behind `info@` or `sales@`. It filters the audit events against the tenant's list of shared mailboxes. | Read-only |
| `06-Get-M365NonOwnerMailboxAccess.ps1` | Mailbox access events (MailItemsAccessed) where the logon type is not Owner and the user is not the mailbox owner: who opened whose mailbox, as Admin or as Delegate. | Read-only |
| `07-Get-M365MailboxAuditConfig.ps1` | Every mailbox with its auditing state and `AuditLogAgeLimit`, sorted to surface the ones where auditing is disabled. This is the prerequisite check for scripts 03-06. | Read-only |
| `08-Get-M365TransportRulesReport.ps1` | The tenant's transport rules with state, priority, mode (Enforce/Audit) and description, for reviewing hidden redirects and BCCs and filter bypasses. | Read-only |
| `09-Get-M365MailConnectorsReport.ps1` | Inbound and outbound connectors with state, type, domains and smart hosts. An unrecognised outbound connector is a known Business Email Compromise technique. | Read-only |
| `10-Get-M365QuarantineReport.ps1` | Quarantined messages with sender, recipients, type (Spam, Phish, Malware, HighConfPhish, Bulk), subject and release state. It is the only script that pages through its results with a `-Page` loop. | Read-only |

## Before you run them

- **PowerShell**: Windows PowerShell 5.1 or PowerShell 7. None of the ten scripts declares `#Requires -Version`, so that minimum is not enforced by the code.
- **Module** (the only one, declared with `#Requires -Modules` in all ten scripts):

  ```powershell
  Install-Module ExchangeOnlineManagement -Scope CurrentUser
  ```

  Nothing else is needed: no references to Microsoft Graph, to `Az` or to MSOnline/AzureAD, no app registration, no certificate, no application permission.

- **Permissions**: read-only Exchange Online roles, and they differ from script to script. A Global Administrator is not required and should not be used: none of these ten scripts needs write privileges. The minimum role, script by script:

| Script | Minimum role |
| --- | --- |
| 01, 07 | View-Only Recipients |
| 02 | Reporting / Security Reader |
| 03, 04, 06 | View-Only Audit Logs |
| 05 | View-Only Audit Logs **and** View-Only Recipients (warning 4) |
| 08, 09 | View-Only Configuration |
| 10 | Security Reader with quarantine access |

**One prerequisite that is not a permission**: mailbox auditing has to be on, otherwise scripts 03-06 have nothing to read. Check it with script 07 before anything else.

## ⚠️ Warnings

1. **Five of the ten reports stop at 5000 rows and do not say so.** Audits 03, 04, 05 and 06 call `Search-UnifiedAuditLog` with `-ResultSize 5000` and without `-SessionCommand ReturnLargeSet`: 5000 is the ceiling of a single call, and the truncation is silent. The worst case is 06, because `MailItemsAccessed` is the highest-volume operation in the Unified Audit Log and on a real tenant seven days routinely go past 5000 events — and that is precisely the script you reach for when looking for unauthorised access. In 05 the cut is doubly deceptive: the 5000 raw events are *then* filtered down to shared mailboxes only, so the final report can hold three rows and look exhaustive while the starting sample was already clipped. Script 01 gets to the same place by another route: `Get-MessageTrace -PageSize 5000` with no `-Page` loop reads the first page only, so its `Sent` and `Received` figures are a sample, not the volumes for the period. **Do not conclude "no unusual access" or "no suspicious deletion" from these outputs.** If the count printed at the end is exactly 5000, the data is truncated: narrow the window with `-Days` and repeat over shorter intervals. Script 10 pages correctly and does not have this limit.

2. **If mailbox auditing is off, scripts 03-06 return zero rows and no error.** The run completes normally, the CSV is written, and the number printed is zero: indistinguishable from "nothing happened". Auditing has been on by default at organisation level since 2019, but it can have been disabled on individual mailboxes. Run 07 first: if it finds mailboxes with auditing disabled, the zeros from the audits do not apply to those mailboxes, and that belongs in the report you hand over. A zero without its denominator is not a result.

3. **The CSVs you produce are personal data, and in four cases they hold email content, not just metadata.** Script 06 writes in clear who opened whose mailbox (the `Accessor` and `Mailbox` columns); scripts 03, 04, 05 and 10 export message subjects (`Items`, `Subject`), which are the content of the communication. Where the people involved are employees in Italy, a file like this falls under the GDPR and under article 4 of the Workers' Statute on remote monitoring: the purpose has to be stated up front, the people concerned have to be informed beforehand, and depending on the case a union agreement or an application to the labour inspectorate is required. Check you have that basis before running 03-06, then keep the CSVs no longer than you need them.

4. **Script 05 needs a role its own help does not declare, and it dies before writing anything.** Its `.NOTES` mention only *View-Only Audit Logs*, but the script also calls `Get-EXOMailbox -RecipientTypeDetails SharedMailbox`, which requires *View-Only Recipients*. With `$ErrorActionPreference = 'Stop'` and no `try/catch`, anyone who granted exactly the documented permissions watches the run die on that line: no CSV, no partial output. Grant both roles.

5. **No script closes its session, so running them all in sequence makes the last ones fail.** `Connect-ExchangeOnline` appears in ten scripts out of ten, `Disconnect-ExchangeOnline` in none. Ten runs in the same console open ten Exchange Online sessions and go past the per-user limit on concurrent PowerShell sessions; the resulting error talks about quota and reads very easily as a permissions problem, which sends the diagnosis the wrong way. Close the session yourself with `Disconnect-ExchangeOnline -Confirm:$false` between scripts, or at least when you are done: retrying without closing it does not help. The same applies when a script stops halfway, because without `try/finally` the session is left open anyway.

6. **`-Days` is validated in one script out of seven.** The help in 02, 03, 04, 05, 06 and 10 states a maximum — 90 days for the audits, around 30 for quarantine because of its retention — but the parameter carries no validation attribute: `-Days 365` is not rejected, it goes through to the API and produces either an obscure error or a silently shortened window. Only 01 really validates (`[ValidateRange(1, 10)]`, the `Get-MessageTrace` limit). Stay within the maxima the help states: a window that is accepted is not a window that is covered.

## Where the output goes

- The CSV is written in the **current** directory, not next to the script: the default is a relative path such as `.\M365-NonOwnerAccess-<yyyymmdd>.csv`, so the file is created wherever the prompt is. If you cloned the repository and run from there, the CSV lands **inside the clone**: the `.gitignore` in the root excludes `*.csv`, but do not rely on it — check `git status` before you commit. And if the console was opened as administrator, the current directory is often `C:\Windows\System32`.
- The default file name contains **only the date**, and `Export-Csv` is called without `-NoClobber` in all ten scripts: a second run on the same day overwrites the previous report without asking. If you need the history, or you are re-running an extraction to compare it with the first one, pass `-OutputCsv` with a different name.
- **The content is sensitive**, and some of it is the content of communications: who opened whose mailbox (06), the subjects of deleted emails (03), of delegated sends (04), of sends from shared mailboxes (05) and of quarantined messages (10), senders and recipients of blocked mail (10), traffic volumes address by address (01), the tenant's transport rules and connectors (08, 09), the full mailbox list (07). All ten scripts accept `-OutputCsv`: use it to write into a dedicated folder with restricted ACLs, where you keep the customer's confidential documents, not in your working folder. See also warning 3.

## Examples

```powershell
# first things first: is auditing on? (warning 2)
.\07-Get-M365MailboxAuditConfig.ps1

.\02-Get-M365MailFlowStatusReport.ps1 -Days 30
.\03-Get-M365EmailDeletionAudit.ps1 -Days 30
.\06-Get-M365NonOwnerMailboxAccess.ps1 -Days 14
.\09-Get-M365MailConnectorsReport.ps1

# every script accepts -OutputCsv: use it to write outside the clone (warnings 3 and 6)
.\06-Get-M365NonOwnerMailboxAccess.ps1 -Days 14 -OutputCsv C:\Audit\Customer\non-owner-access.csv
```

## Download and support

The same content is available as a ZIP archive from [synsphere.it/download/toolkit-powershell-email-security-microsoft-365](https://synsphere.it/download/toolkit-powershell-email-security-microsoft-365/).

If you need help reading the reports, or fixing what they show: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
