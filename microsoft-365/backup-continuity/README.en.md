# Microsoft 365 Backup and Continuity — 10 PowerShell scripts

Ten read-only scripts that measure how much of a Microsoft 365 tenant is actually recoverable, each leaving you a CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

Microsoft 365 does not include a native backup: the shared responsibility model applies, where Microsoft guarantees the infrastructure and the data stays the customer's responsibility. What the service does provide natively is **short-term recoverability** — holds, Single Item Recovery, directory recycle bins, retention policies — and no single console puts it all in one view.

This toolkit measures that recoverability, mailbox by mailbox and policy by policy, and writes it to CSV. It is meant for whoever administers Microsoft 365 for small and medium businesses (MSPs, in-house IT managers) and has to decide what to fix first, and whether a dedicated backup is needed. It measures native recoverability: it does not create it and it is not a substitute for a backup.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-MailboxHoldStatus.ps1` | User and shared mailboxes with Litigation Hold, Retention Hold and In-Place Holds: which mailboxes preservation actually protects, and which it does not. | Read-only |
| `02-Get-MailboxRecoverySettings.ps1` | Deleted-items retention window (`RetainDeletedItemsFor`) and Single Item Recovery status per mailbox: what can be recovered, and for how long. | Read-only |
| `03-Get-MailboxesAtRisk.ps1` | User mailboxes with no hold at all **and** Single Item Recovery disabled: the priority list to act on. | Read-only |
| `04-Get-SoftDeletedMailboxes.ps1` | Deleted but still restorable mailboxes, with the deletion date and the estimated days left. | Read-only |
| `05-Get-InactiveMailboxes.ps1` | Inactive mailboxes: mailboxes of deleted users that are kept because a hold or a retention policy covered them at the time of deletion. | Read-only |
| `06-Get-RetentionPolicies.ps1` | Microsoft Purview retention policies with status, mode and declared workload. The cmdlet's `Workload` field always lists every possible workload, not the scope the policy is actually applied to: that needs `-DistributionDetail`. | Read-only |
| `07-Get-DeletedUsers.ps1` | Deleted users still recoverable from the Entra ID directory recycle bin, with the deletion date and the estimated days left. | Read-only |
| `08-Get-DeletedGroups.ps1` | Deleted groups still recoverable from the directory recycle bin. Only Microsoft 365 groups are recoverable; security groups are not. | Read-only |
| `09-Get-ArchiveMailboxStatus.ps1` | Online archive status per mailbox: archive active, auto-expanding archive, archive name. | Read-only |
| `10-Get-M365ContinuitySummary.ps1` | Single dashboard: mailboxes on hold, mailboxes at risk, soft-deleted, inactive, retention policies and deleted users. It queries the three sources independently; one that is unavailable becomes `n/d`. | Read-only |

None of the ten scripts changes tenant configuration.

## Before you run them

**PowerShell 5.1 or PowerShell 7.** The scripts are saved as UTF-8 with BOM, the only encoding both versions read correctly. If you reopen them and save them without the BOM, accented characters in the output and in `Get-Help` become garbled on PowerShell 5.1.

**Modules.**

```powershell
# Exchange Online and Purview (01-06, 09, 10). Version 3.2.0 or later is required,
# because it provides both Connect-ExchangeOnline and Connect-IPPSSession.
Install-Module ExchangeOnlineManagement -MinimumVersion 3.2.0 -Scope CurrentUser

# Microsoft Graph (07, 08 and part of 10)
Install-Module Microsoft.Graph -Scope CurrentUser

# instead of the meta-module, the only two submodules actually needed
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
```

**Connection contexts and permissions.** There are three, and they are separate: being connected to Exchange Online does not give you the Purview cmdlets.

| Context | Needed for | Minimum permission |
| --- | --- | --- |
| `Connect-ExchangeOnline` | 01, 02, 03, 04, 05, 09 and the Exchange part of 10 | read-only **View-Only Recipients** role |
| `Connect-IPPSSession` | 06 and the retention part of 10 | a read role on retention policies in the Microsoft Purview portal |
| `Connect-MgGraph` | 07 and the Graph part of 10; 08 | **User.Read.All** (07, 10) and **Group.Read.All** (08) |

Both Graph scopes are read-only and are the least privilege needed to read `/directory/deletedItems`: no script asks for a `.ReadWrite.All` scope. They are tenant-wide scopes, however, so the first run requires an administrator's consent.

## ⚠️ Warnings

1. **Script 03 and dashboard 10 do not look at shared mailboxes.** Both query `-RecipientTypeDetails UserMailbox` only, while 01, 02 and 09 also include `SharedMailbox`. A shared mailbox with no hold and Single Item Recovery disabled will therefore never show up in the "at risk" list and will not be counted by the dashboard, even though that is exactly the most exposed case. Always cross-check 03 against 01 and 02 before declaring a scope covered.

2. **Scripts 07, 08 and 10 trigger admin consent before they can work.** All three declare `#Requires -Modules Microsoft.Graph.Authentication`, but the cmdlets they call (`Get-MgDirectoryDeletedItemAsUser`, `Get-MgDirectoryDeletedItemAsGroup`) live in `Microsoft.Graph.Identity.DirectoryManagement`. If you installed only the Authentication submodule, the `#Requires` guard passes, `Connect-MgGraph` raises the tenant consent prompt, and only then does the script die with `CommandNotFoundException`: you granted consent for nothing. In 10 the `try/catch` degrades it to `n/d` with no obvious error. Install `Microsoft.Graph`, or the two submodules shown above, before the first run.

3. **Dashboard 10 exports its CSV even when a source did not answer.** The three queries sit in separate `try/catch` blocks: if one fails — missing role, consent not granted, throttling — the metric becomes `n/d`, a yellow "non disponibile" line is printed, and the CSV is written anyway. `n/d` is not a zero, but the exported row looks exactly like a complete picture, so a permission gap reads as "nothing wrong". Before you use the numbers, check that no "non disponibile" line appeared and that no field in the CSV is `n/d`.

4. **`GiorniResidui` is an estimate, and in 04 it is computed in local time.** The 30-day window is an assumption written into the script, not a value read from the tenant. On top of that, 04 compares `WhenSoftDeleted`, which is UTC, against local time, while 07 and 08 correctly use `(Get-Date).ToUniversalTime()`: the value in 04 is off by the local offset (one or two hours in Italy) and around midnight can show a day more or a day less. Do not schedule a restore for the last day the column shows: check the real window in the portal.

5. **The CSVs hold personal data in clear text.** Display name, primary SMTP address and UPN of employees and former employees land in the files unmasked, and reports 04, 05 and 07 are in effect lists of people who have left the organisation. Running these scripts therefore produces, on the operator's own disk, a file that is in scope for the GDPR. Run them from a local folder outside any sync, or pass `-OutputCsv` with a path of your choosing, and delete the files once the analysis is done.

6. **In 06, a permission denial shows up as a login prompt.** The script wraps `Get-RetentionCompliancePolicy` in a `try/catch` that reads any error as "I am not connected" and responds by calling `Connect-IPPSSession`; the second call is unprotected. A missing Purview read role, or throttling, therefore surfaces as a second sign-in prompt instead of a clear message, and the retention policy list can come back empty for a reason nobody tells you. If the script asks you to sign in to Purview twice in a row, suspect the missing role, not an expired session.

## Where the output goes

All ten scripts export a CSV. The default path is **relative** — `.\M365-<name>-<date>.csv` — and the name contains only the date, not the time. Two consequences always follow:

- **The file is created wherever the prompt happens to be.** If you cloned this repository and run the scripts from there, the CSV lands inside the clone. The repository root excludes `*.csv` from version control, but do not rely on that exclusion: run `git status` before you commit.
- **A second run on the same day overwrites the first one without asking.** `Export-Csv` uses neither `-Append` nor `-NoClobber`: to compare two runs on the same day, rename the first file or pass `-OutputCsv`.

The content is personal data, not aggregates: display names, primary SMTP addresses, UPNs, names of deleted users and groups, retention policy names. Warning 5 applies.

## Examples

```powershell
# the two most useful for deciding where to act
.\03-Get-MailboxesAtRisk.ps1
.\10-Get-M365ContinuitySummary.ps1

# inventory of holds and of deleted users
.\01-Get-MailboxHoldStatus.ps1
.\07-Get-DeletedUsers.ps1

# outside the current folder: every script accepts -OutputCsv
.\03-Get-MailboxesAtRisk.ps1 -OutputCsv 'C:\Audit\mailboxes-at-risk.csv'
```

## Download and support

The same content is available as a ZIP from [synsphere.it/download/toolkit-powershell-backup-continuita-m365](https://synsphere.it/download/toolkit-powershell-backup-continuita-m365/).

For a backup and continuity strategy on Microsoft 365 — the Microsoft 365 Backup add-on or third-party solutions, hold and retention configuration — get in touch at [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
