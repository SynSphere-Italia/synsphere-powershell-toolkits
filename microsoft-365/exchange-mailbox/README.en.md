# Exchange Online and Microsoft 365 Mailbox Toolkit

Ten read-only PowerShell reports that capture the delegations, forwarding, sizes, holds, auto-replies and calendar permissions of an Exchange Online tenant, one CSV each.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

This is for anyone who has to audit the security or the capacity of an Exchange Online tenant without changing its configuration: in-house IT administrators and MSPs running other people's tenants. It answers the questions the portal only answers one mailbox at a time: who has access to whose mailbox, where automatic forwarding is switched on, which mailboxes are under hold, how big they are, who can read the calendars.

None of the ten scripts writes to the tenant. Authentication is interactive: the browser opens, MFA works, no password is stored in the scripts, and each script inherits the permissions of the account that runs it.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-M365MailboxPermissionReport.ps1` | Delegations on every mailbox: Full Access, Send As, Send on Behalf. One row per mailbox/delegate pair, system and inherited permissions excluded. | Read-only |
| `02-Get-M365SharedMailboxPermissionReport.ps1` | The same delegations, restricted to shared mailboxes: who can get into `info@`, `accounts@`, `sales@`. | Read-only |
| `03-Get-M365MailboxesUserHasAccessTo.ps1` | Reverse lookup: given one user, which other people's mailboxes they hold Full Access or Send As on. Useful before an offboarding. | Read-only |
| `04-Get-M365MailboxSizeReport.ps1` | Total size, item count and quota of every mailbox, for capacity planning and for spotting the mailboxes close to the limit. | Read-only |
| `05-Get-M365ArchiveMailboxSizeReport.ps1` | Mailboxes with an active online archive, and the size of that archive. | Read-only |
| `06-Get-M365EmailForwardingReport.ps1` | Mailboxes with mailbox-level forwarding configured (internal recipient or SMTP address) and whether a copy is kept in the mailbox. | Read-only |
| `07-Get-M365InboxRulesExternalForwarding.ps1` | Inbox rules that forward or redirect to domains the tenant does not accept: a typical sign of a compromised mailbox. | Read-only |
| `08-Get-M365MailboxHoldReport.ps1` | Mailboxes under any kind of hold: litigation, in-place, retention, compliance tag, delay hold. Worth checking before deleting a mailbox. | Read-only |
| `09-Get-M365AutoReplyReport.ps1` | Mailboxes with an auto-reply enabled or scheduled, with start and end dates. Finds forgotten out-of-office messages and former employees' mailboxes. | Read-only |
| `10-Get-M365CalendarPermissionReport.ps1` | Permissions on the Calendar folder, including the `Default` and `Anonymous` levels. It finds the folder by type, so it also works on non-English tenants. | Read-only |

## Before you run them

- **PowerShell**: Windows PowerShell 5.1 or PowerShell 7. No script declares `#Requires -Version`, so that minimum is not enforced by the code: on 5.1, warning 2 applies.
- **Module** (the only one, declared with `#Requires -Modules` in all ten scripts):

  ```powershell
  Install-Module ExchangeOnlineManagement -Scope CurrentUser
  ```

- **Permissions**: an Exchange Online account with the *View-Only Recipients* role or higher. No app registration, no Microsoft Graph permission and no Azure permission is needed: the scripts connect in delegated mode with `Connect-ExchangeOnline` and inherit the operator's RBAC. For scripts 07 and 09 that role may not be enough: see warning 4.

## ⚠️ Warnings

1. **A zero from script 07 is not proof that no external forwarding exists.** The check only matches recipients written in `SMTP:` form. A rule pointing at a directory recipient (rendered as `EX:/o=...`) - a mail contact or a mail user whose actual address is outside the tenant, for instance - is not flagged, and the script still finishes in green with "No inbox rule with external forwarding found". Read that green as "no match among the rules with an SMTP recipient", not as the absence of forwarding: complete the picture with script 06 (mailbox-level forwarding) and with a check of client-side rules and OAuth consents, which this script cannot see.
2. **On Windows PowerShell 5.1, with exactly one result, the final count prints blank.** All ten scripts end by printing `$report.Count`: on 5.1 a single object does not expose `.Count` (on PowerShell 7 it does), so a space appears where the number should be. The worst case is script 07, where one single hit is the most likely finding: the message becomes "ATTENZIONE:  regole inbox con inoltro ESTERNO". A blank count does not mean zero - count the rows in the CSV.
3. **An error on one single mailbox aborts the whole run and no CSV is written.** The scripts set `$ErrorActionPreference = 'Stop'` and use no `try/catch`: the report builds up in memory and is exported only on the last line. An inactive or soft-deleted mailbox, a denied permission or throttling will lose all the work already collected, without even leaving a partial file. On large tenants, work in batches (scripts 03 and 10 accept `-UserPrincipalName`) and do not treat the report as done until the CSV exists.
4. **The stated role does not certainly cover 07 and 09, and where permissions are missing 07 stays silent.** The single *View-Only Recipients* prerequisite comes from the collection's earlier documentation; 07 uses `Get-InboxRule` and 09 uses `Get-MailboxAutoReplyConfiguration`, which are not EXO REST cmdlets like the `Get-EXO*` ones and plausibly require a wider role - this was not verified against Microsoft's documentation. On top of that, 07 reads the rules with `-ErrorAction SilentlyContinue`: mailboxes the account has no rights on are skipped silently. An empty report can therefore mean "I could not read", not "there is nothing". Before trusting a negative result, try `Get-InboxRule` on a mailbox whose rules you already know.
5. **The CSV files are the access map of the tenant.** They hold Full Access and Send As delegations (01, 02, 03), calendar permissions (10), internal and external forwarding addresses (06, 07), mailbox sizes and holds (04, 05, 08), and staff absence dates (09). The default path is relative, so the file is created in the current directory whatever that is: with a console opened as administrator it lands in `C:\Windows\System32`. Always pass `-OutputCsv` pointing at a directory you control, and treat the files as confidential.
6. **The scan runs per mailbox even in scripts presented as quick.** Besides 01, 03, 07 and 10, one call per mailbox is also made by 04 and 05 (`Get-EXOMailboxStatistics`) and by 09 (`Get-MailboxAutoReplyConfiguration`), which the earlier documentation did not list as slow and which carry no such note in their own help. On a tenant with many mailboxes they run into the same times and the same throttling, and because of warning 3 a throttling error loses the entire run. Treat 01, 03, 04, 05, 07, 09 and 10 as slow.

## Where the output goes

- The CSV is written in the **current** directory, not next to the script: the default is a relative path such as `.\M365-MailboxPermissions-<yyyymmdd>.csv`, so the file is created wherever the prompt is. If you cloned the repository and run from there, the CSV lands **inside the clone**: the `.gitignore` in the root excludes `*.csv`, but do not rely on it - check `git status` before you commit.
- The file name contains **only the date**: a second run on the same day overwrites the previous file without asking. If you need the history, pass `-OutputCsv` with a different name.
- Scripts 06 and 07 write the CSV **only if they find something**: a missing file means no match (with the limits in warning 1), not a failed run.
- The content is sensitive: mailbox delegations and permissions, calendar permissions, the addresses mail is forwarded to, compliance holds, absence dates. Keep it where you keep the customer's confidential documents, not in your working folder.

## Examples

```powershell
.\01-Get-M365MailboxPermissionReport.ps1
.\03-Get-M365MailboxesUserHasAccessTo.ps1 -UserPrincipalName mario.rossi@azienda.it
.\07-Get-M365InboxRulesExternalForwarding.ps1
.\10-Get-M365CalendarPermissionReport.ps1 -UserPrincipalName mario.rossi@azienda.it

# every script accepts -OutputCsv: use it to write outside the clone (warning 5)
.\01-Get-M365MailboxPermissionReport.ps1 -OutputCsv C:\Audit\Customer\delegations.csv
```

## Download and support

The same content is available as a ZIP archive from [synsphere.it/download/toolkit-powershell-exchange-mailbox-microsoft-365](https://synsphere.it/download/toolkit-powershell-exchange-mailbox-microsoft-365/).

If you need help reading the reports, or fixing what they show: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
