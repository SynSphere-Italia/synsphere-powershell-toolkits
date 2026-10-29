# Guest and External Access in Microsoft 365

Ten PowerShell scripts to find out who, from outside, has access to your tenant, and to clean up what is no longer needed.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

Guest accounts pile up: a supplier invited for a project that closed two years ago, an invitation never accepted, an "anyone with the link" share created for convenience and never revoked. None of these shows up in a list of tenant users, and none of them raises an error.

These scripts take a picture of a Microsoft 365 tenant's external collaboration — who the guests are, which domains they come from, which groups and teams they belong to, what they have opened, and under which settings the tenant allows them to be invited — and let you remove inactive guests. They are aimed at the Microsoft 365 administrator of a small or medium business, or at the consultant running a security audit on its behalf, including in a NIS2 context. Nine of the ten scripts are read-only and produce a CSV; only `06` changes the tenant.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-M365GuestUsers.ps1` | Exports every account with `userType = Guest`: name, email, originating domain, company, creation date, invitation state and whether the account is enabled. The starting point of any external-collaboration audit. | Read-only |
| `02-Get-M365GuestGroupMemberships.ps1` | For each guest, lists the groups and teams it belongs to, with a count: this is how you see which resources a guest can actually reach. | Read-only |
| `03-Get-M365StaleGuestUsers.ps1` | Lists guests whose last sign-in is older than the `-InactiveDays` threshold, or for whom no sign-in is recorded at all. | Read-only |
| `04-Get-M365PendingGuestInvitations.ps1` | Lists guests in `PendingAcceptance` state: they received an invitation and never redeemed it. | Read-only |
| `05-Get-M365GuestsByDomain.ps1` | Groups guests by originating domain and counts them: which companies you really work with, and which domains are no longer relevant. | Read-only |
| `06-Remove-M365StaleGuests.ps1` | Finds inactive guests and, on request, disables them (`-Action Disable`) or deletes them (`-Action Delete`). The default `-Action Report` touches nothing. Supports `-WhatIf`. | **WRITES** with `-Action Disable` or `-Action Delete` |
| `07-Get-M365ExternalSharingAudit.ps1` | Pulls external sharing events from the Unified Audit Log (sharing invitations, secure links): who shared what, and with whom. | Read-only |
| `08-Get-M365ExternalFileAccessAudit.ps1` | Pulls file accesses and downloads performed by external identities (UPN containing `#EXT#`) from the Unified Audit Log. | Read-only |
| `09-Get-M365AnonymousLinkAudit.ps1` | Pulls creation, update and use of anonymous links — the ones reachable without authentication — from the Unified Audit Log. | Read-only |
| `10-Get-M365ExternalCollaborationSettings.ps1` | Reads the Microsoft Entra authorization policy: who may invite guests, which directory role guests get, and some default user permissions. | Read-only |

## Before you run them

**PowerShell.** PowerShell 5.1 or PowerShell 7. No script declares a minimum version through `#Requires -Version`.

**Modules.** The simplest route is the Graph meta-module, which contains every submodule needed:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser            # scripts 01-06 and 10
Install-Module ExchangeOnlineManagement -Scope CurrentUser   # scripts 07-09
```

If you prefer installing the individual submodules instead of the meta-module, you need all three of the following, because the scripts' `#Requires` directives are incomplete: six scripts out of ten pass the check and then stop with "term not recognized" (`01`, `02`, `03`, `04` and `05` use `Get-MgUser`/`Get-MgUserMemberOf`, which live in `Microsoft.Graph.Users`; `10` uses `Get-MgPolicyAuthorizationPolicy`, which lives in `Microsoft.Graph.Identity.SignIns`). `06` declares `Microsoft.Graph.Users` correctly and is the only one that does not break.

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Identity.SignIns -Scope CurrentUser
```

**Permissions and roles.** The Graph scopes are delegated and need administrator consent on first connection.

| Script | Graph scope or role |
| --- | --- |
| `01`, `04`, `05` | `User.Read.All` |
| `02` | `User.Read.All`, `GroupMember.Read.All` |
| `03` | `User.Read.All`, `AuditLog.Read.All` |
| `06` | `User.ReadWrite.All`, `AuditLog.Read.All` (see warning 6) |
| `07`, `08`, `09` | Exchange Online, **View-Only Audit Logs** or **Audit Logs** role |
| `10` | `Policy.Read.All` |

- Directory role: **Global Reader** is enough for `01`-`05` and `10`. Script `06` with `-Action Disable` or `-Action Delete` requires **User Administrator** or higher.
- Scripts `07`-`09` require unified auditing (Purview) to be **turned on** in the tenant.
- The `signInActivity` property, which `03` and `06` rely on, requires a **Microsoft Entra ID P1 or P2** licence.

## ⚠️ Warnings

1. **`06 -Action Delete` does not ask for confirmation: it just deletes.** The script declares `SupportsShouldProcess` but without `ConfirmImpact = 'High'`, and with PowerShell's default preferences that means the prompt never appears. Consequence: `.\06-Remove-M365StaleGuests.ps1 -Action Delete` removes every guest above the threshold in one go, without a single "are you sure?". **Always** run it with `-WhatIf` first, and remember that the default `-Action Report` changes nothing. A deleted Entra account stays recoverable from the directory recycle bin for about 30 days; after that, it does not.

2. **The set the script acts on can be far larger than you think.** Two separate causes, both affecting `03` and `06`. First: both scripts treat a guest with no recorded sign-in as stale (the CSV shows `Mai`), but `signInActivity` requires the Entra ID P1/P2 licence and the `AuditLog.Read.All` scope — without them the value may not arrive at all, and perfectly active guests look as though they never signed in. Second: `-InactiveDays` has no range validation, so a negative value such as `-InactiveDays -30` moves the threshold into the future and widens the set instead of narrowing it. With `-Action Delete`, that set is the list of accounts being removed. Check the licence, pass positive values only, run `03` read-only first and read the CSV row by row: if almost every guest shows `Mai`, the data is missing — that is not a picture of your tenant.

3. **A run of `06` interrupted halfway leaves no record of what it already did.** The scripts have no error handling and `$ErrorActionPreference` is set to `Stop`: the first failure (insufficient permissions on one guest, Graph throttling) aborts the whole loop *before* the final `Export-Csv`. Consequence: the disables or deletions that already succeeded are written nowhere, and you do not know which guests you acted on. Work in small batches, raising the threshold so the set stays short, and start `Start-Transcript` before any run with `-Action Delete`.

4. **A zero from `08` or `09` is not proof that nothing happened.** The three audit scripts ask the server for at most 5000 events. `08` applies that ceiling to *all* file accesses in the tenant and only afterwards, locally, keeps the external actors: in a busy tenant the 5000 most recent events can all be internal, and the script prints "0 file accesses by external users" while external accesses did occur. `09`, on any empty result, prints "No anonymous links in the period: good sharing posture" — including when the emptiness comes from unified auditing being off, from a missing audit role, from a `-Days` window beyond your plan's retention, or from a `-Days` value of zero or below, which, being unvalidated, produces a start date in the future and therefore an always-empty result. Before reading the output, confirm that auditing is on and that you hold the role; then narrow `-Days` and repeat over short windows so you do not hit the ceiling. A number without its denominator is not a measurement.

5. **`02` undercounts silently: `GroupCount = 0` can mean "could not be read".** Reading each guest's memberships suppresses errors (`-ErrorAction SilentlyContinue`): if it fails for a guest, that guest appears in the report with zero groups, indistinguishable from a guest that genuinely belongs to nothing. The report presents as complete a list that may have lost accesses. Re-check the guests that come back with no groups by hand, either by running `02` against that single guest or from the portal.

6. **`06` asks for write access to every user in the tenant even when it writes nothing.** The script always connects with `User.ReadWrite.All`, including under `-Action Report`, the case in which it changes nothing: to get a plain list you grant — or have your administrator grant — tenant-wide write consent. If all you want is the list of inactive guests, use `03`, which asks for `User.Read.All`.

## Where the output goes

Every script exports a CSV, and the default path is **relative to the current directory**, with a file name that contains only the date (for example `.\M365-GuestUsers-20261029.csv`). Two consequences follow:

- The file is created wherever the prompt happens to be. If you cloned the repository and run the scripts from inside the clone, the CSV lands **inside the clone**: the root `.gitignore` excludes `*.csv`, but do not rely on that safety net — check `git status` before committing.
- A second run on the same day **overwrites** the previous export without asking: the name depends only on the date, and `Export-Csv` is not called with `-NoClobber`.

The contents are personal data belonging to third parties: names and email addresses of external guests, with originating domain and company (`01`-`06`); external users' UPNs, names of the files they opened and site URLs (`07`-`09`). These exports are GDPR-relevant: always pass `-OutputCsv` pointing at a controlled folder, and delete them once the analysis is over. Script `10` also prints the tenant settings to the console.

## Examples

```powershell
# Baseline inventory: every guest in the tenant
.\01-Get-M365GuestUsers.ps1

# Guests with no sign-in for more than six months (read-only)
.\03-Get-M365StaleGuestUsers.ps1 -InactiveDays 180

# External sharing over the last month
.\07-Get-M365ExternalSharingAudit.ps1 -Days 30

# Clean-up: dry run first, changing nothing
.\06-Remove-M365StaleGuests.ps1 -InactiveDays 180 -Action Disable -WhatIf
```

## More

The same content is available as a ZIP archive from [synsphere.it/download/toolkit-powershell-guest-esterni-microsoft-365](https://synsphere.it/download/toolkit-powershell-guest-esterni-microsoft-365/).

If you need help interpreting the results or securing external collaboration: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
