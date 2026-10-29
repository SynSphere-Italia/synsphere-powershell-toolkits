# Microsoft 365 license management

Ten PowerShell scripts that show which licenses in a tenant are assigned, to whom and through which path, and remove the redundant ones: eight are read-only, two change the assignments.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

This collection is aimed at in-house IT administrators and MSPs who hold administrative credentials on a Microsoft 365 tenant and need to see where the license spend goes. It answers questions that require cross-referencing several lists: which shared mailboxes carry a license they normally do not need, which licensed users have not signed in for months, which licenses come from a group and which are assigned directly, and what monthly cost each user accounts for.

Every script stands alone, takes its parameters on the command line and signs in interactively with MFA. The eight read-only scripts produce a CSV you can filter or attach to an assessment; the two writing scripts cover the next step, which is clearing redundant direct assignments and assigning or removing SKUs, in bulk if needed.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-M365LicenseReport.ps1` | Every licensed user, the SKUs assigned with their readable name (skuPartNumber) and whether the account is enabled or disabled. | Read-only |
| `02-Get-M365LicenseExpiryReport.ps1` | The SKUs the organisation subscribes to: purchased, consumed, warning and suspended units, plus capability status. It does not report the renewal date, because `Get-MgSubscribedSku` does not expose it. | Read-only |
| `03-Manage-M365Licenses.ps1` | Four actions: `Report` lists one user's licenses; `Assign` and `Remove` act on a single SKU; `BulkCsv` applies a CSV with the columns UserPrincipalName, SkuPartNumber, Operation. | `Report` read-only; `Assign`, `Remove`, `BulkCsv` **WRITES** |
| `04-Get-M365LicensedSharedMailboxes.ps1` | Shared mailboxes that have a license assigned, cross-referencing Exchange Online and Graph: a shared mailbox normally needs no license up to 50 GB, so this is almost always recoverable spend. | Read-only |
| `05-Get-M365LicensedGroups.ps1` | Groups that have one or more licenses assigned (group-based licensing), with their member count. | Read-only |
| `06-Get-M365LicenseAssignmentPath.ps1` | For each license of each user, whether it is assigned directly or inherited from a group, with the group name. It reads `licenseAssignmentStates`. Use it before removing anything: an inherited license is removed from the group, not from the user. | Read-only |
| `07-Get-M365GroupBasedLicenseReport.ps1` | Group-inherited assignments only, with the source group, the `State` and any assignment error. | Read-only |
| `08-Remove-M365OverlappedLicenses.ps1` | Users who hold the same SKU both directly and through a group, where the direct one is redundant. With no parameters it only reports; with `-RemoveDirect` it removes the direct assignment. | Read-only by default; with `-RemoveDirect` **WRITES** |
| `09-Get-M365UnusedLicenses.ps1` | Licensed users who have not signed in for more than N days (`-InactiveDays`, default 90) or ever, cross-referencing licenses with `signInActivity`. | Read-only |
| `10-Get-M365LicenseCostReport.ps1` | Monthly cost per user, adding up the price of each of their SKUs from a price list inside the script or from `-PriceCsv` (columns SkuPartNumber, MonthlyPrice). | Read-only |

## Before you run them

**PowerShell.** PowerShell 5.1 or PowerShell 7. None of the scripts contains `#Requires -Version`, so the requirement is not checked at startup.

**Modules.**

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser   # script 04 only
```

Install the full `Microsoft.Graph` module, or every submodule listed here. The scripts' `#Requires` directive declares only `Microsoft.Graph.Authentication` (plus `Microsoft.Graph.Users.Actions` in `03` and `08`), but the cmdlets they call live elsewhere too: `Microsoft.Graph.Identity.DirectoryManagement` for `Get-MgSubscribedSku`, used by all ten scripts; `Microsoft.Graph.Users` for `Get-MgUser` and `Get-MgUserLicenseDetail`, used by `01`, `03`, `04`, `06`, `07`, `08`, `09`, `10`; `Microsoft.Graph.Groups` for `Get-MgGroup` and `Get-MgGroupMember`, used by `05`, `06`, `07`. If you install only the declared submodules, the `#Requires` check passes and the script dies later on `Get-MgSubscribedSku` with a "term not recognized" error.

**Delegated Graph scopes.** `User.Read.All` (every script that reads users), `Organization.Read.All` (all ten scripts), `Group.Read.All` (`05`, `06`, `07`), `AuditLog.Read.All` (`09` only), `User.ReadWrite.All` (`03` and `08` only). The scopes requested at runtime by `Connect-MgGraph` are the ones declared in each script's `.NOTES` header.

**Entra ID roles.** Global Reader is enough for the eight read-only scripts. `03` and `08` need License Administrator, or User Administrator.

**Exchange Online.** Script `04` only: a role that allows `Get-EXOMailbox`, that is View-Only Recipients or Recipient Management.

**Tenant licensing.** `09` uses `signInActivity`, which requires Microsoft Entra ID P1 or P2.

**Authentication.** Interactive with MFA: a browser window opens. No script contains an app registration, a client secret or a certificate, and none asks for a password on the command line.

## ⚠️ Warnings

1. **Removing a license starts the deletion of data.** When `03` removes a SKU (`-Action Remove` or `BulkCsv`) and the user is left with no license, their Exchange Online mailbox and their OneDrive move to a soft-deleted state: the contents stay recoverable for 30 days, and no longer after that. On a bulk removal this is not a saving, it is a data loss event. Before removing, check with `06` whether the license is direct or inherited, and export or place a hold on the mailbox and OneDrive of the users involved.

2. **`08 -RemoveDirect` acts on the whole tenant and asks for no confirmation.** The script iterates over every user (`Get-MgUser -All`) and removes every overlapping direct assignment in a single run. `SupportsShouldProcess` is declared, but without `ConfirmImpact = 'High'`: with the default value of `$ConfirmPreference` no confirmation prompt appears, so the only barrier between the report and a bulk removal is the switch itself. Always run it with `-WhatIf` first, and add `-Confirm` if you want the prompt. The script also judges the overlap from the mere existence of the group assignment, not from its `State`: if the group assignment is in error, which `07` shows you, removing the direct one leaves the user with no license.

3. **`03 -Action BulkCsv` can stop halfway and leave no trace.** It applies every row of the CSV with no prompt and with `$ErrorActionPreference = 'Stop'`: the first row that fails stops the run, the rows already applied stay applied, and no log says which ones. Re-running the same CSV repeats the initial operations. Run it with `-WhatIf` first, work on small files, and read the real state back with `01` or `06` before you re-run.

4. **An empty, or entirely negative, report can be a missing permission rather than a clean tenant.** Two concrete cases. `09` treats a user with no last sign-in date as inactive and prints it as `Mai`: on a tenant without Microsoft Entra ID P1 or P2, or without consent to `AuditLog.Read.All`, `signInActivity` comes back empty for everyone and every licensed user looks recoverable. `04`, `05`, `06` and `07` resolve users and groups with `-ErrorAction SilentlyContinue`: if `Group.Read.All` has not been granted, resolution fails silently and the CSV comes out with an empty group name (`Gruppo: ` in `06`, an empty `SourceGroup` in `07`), which reads as "no group assignments". That is the wrong premise for a removal, and `06` exists precisely to prepare one. Always compare the number of exported rows with the number of users or groups in the tenant: a figure without its denominator says nothing.

5. **The price list in `10` is an example, so the totals it produces are not your costs.** The `$PriceMap` map inside the script holds five example prices that match no contract, because real prices depend on your CSP or EA agreement. On top of that, a SKU missing from the list counts as zero: the per-user cost and the final total come out lower than the truth, with no warning. Pass `-PriceCsv` with your own price list before you show those figures to anyone.

6. **The two writing scripts ask for more permissions than they use.** `03` and `08` pass `User.ReadWrite.All` to `Connect-MgGraph`, which is write access to every attribute of every user in the tenant, while all they need is to assign and remove licenses. `03` requests it even with `-Action Report`, which is read-only. For license assignment Microsoft documents a less privileged permission, `LicenseAssignment.ReadWrite.All`, which these scripts do not use: by granting consent you grant more than is needed. If all you need is to read, use the eight read-only scripts, none of which asks for write access.

## Where the output goes

Nine scripts out of ten export a CSV; the only one that writes nothing to disk is `03`. The default path is relative (`.\M365-<name>-<date>.csv`), so the file is created in the directory the prompt sits in and not next to the script: from a console opened as administrator it can end up in `C:\Windows\System32`, and if you cloned the repository and run from there it ends up inside the clone. The repository `.gitignore` excludes `*.csv`, but check `git status` before committing rather than trusting it.

The file name contains only the date (`yyyyMMdd`) and none of the nine `Export-Csv` calls uses `-NoClobber`: a second run on the same day overwrites the first one without asking. If you need to keep two runs, pass `-OutputCsv` with an explicit path.

The content is personal data: the display name and UserPrincipalName of every licensed user in the tenant, the last sign-in date (`09`), the addresses of shared mailboxes (`04`) and the groups licenses flow through (`06`, `07`). Treat it as an extract from the company directory: do not leave it in shared folders and do not send it unencrypted. The only export free of personal data is the one from `02`, which stops at SKU level.

## Examples

```powershell
# Inventory of every licensed user, with the SKUs assigned
.\01-Get-M365LicenseReport.ps1

# Licensed users who have not signed in for more than 60 days
.\09-Get-M365UnusedLicenses.ps1 -InactiveDays 60

# Assign a SKU to a user, simulated
.\03-Manage-M365Licenses.ps1 -Action Assign -UserPrincipalName mario.rossi@azienda.it -SkuPartNumber SPE_E3 -WhatIf

# Simulate the removal of overlapping direct licenses, across the whole tenant
.\08-Remove-M365OverlappedLicenses.ps1 -RemoveDirect -WhatIf
```

## Download and support

The same content is available as a ZIP from [synsphere.it/download/toolkit-powershell-licenze-microsoft-365](https://synsphere.it/download/toolkit-powershell-licenze-microsoft-365/). If you want help reading the reports, or setting up a removal safely, write to us at [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
