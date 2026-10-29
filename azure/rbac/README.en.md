# Azure RBAC and Access Governance

Ten read-only PowerShell scripts that capture who holds which RBAC role at which scope in an Azure subscription, and export every result to a CSV.

[Versione italiana](README.md) · [← All the toolkits](../../README.en.md)

## What it's for

It is for people who administer Azure in house and for those who do it on someone else's behalf (MSPs), when they have to prepare an access audit, an offboarding or a periodic privilege review without buying a governance product.

On Azure the answer to "who can do what" is not kept in one place: assignments live at scope levels that are inherited downwards (management group, subscription, resource group, individual resource), a role can reach a user through a group rather than directly, automations have principals of their own, and classic administrators still survive alongside RBAC. Each of the ten scripts answers a single question and leaves the result in a CSV, ready to be filtered or attached to a report.

## Scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-AzRoleAssignmentReport.ps1` | Every role assignment in the subscription: who holds which role and at which scope (subscription, resource group, resource). The starting point of any access audit. | Read-only |
| `02-Get-AzPrivilegedRoleAssignments.ps1` | Isolates the high-privilege roles — Owner, Contributor, User Access Administrator, Role Based Access Control Administrator — assigned at subscription scope (see the warnings). | Read-only |
| `03-Get-AzCustomRoleDefinitions.ps1` | Custom, non built-in role definitions, with their allowed and denied actions and their assignable scopes. | Read-only |
| `04-Get-AzOrphanedRoleAssignments.ps1` | Assignments that Azure returns with no display name, presented as belonging to identities that have been deleted (see the warnings). | Read-only |
| `05-Get-AzServicePrincipalRoleAssignments.ps1` | Assignments whose principal is a service principal — app registrations, managed identities, automations — with the role, the scope and the `ObjectId` of each. | Read-only |
| `06-Get-AzUserRoleAssignments.ps1` | Reverse lookup on a single user: every assignment and its scope, including the ones inherited through groups, with a column that tells "direct" from "group: *name*". | Read-only |
| `07-Get-AzClassicAdministrators.ps1` | Classic administrators (Co-Administrator, Service Administrator, Account Administrator): broad Azure Service Management privileges, to be retired in favour of RBAC alone. | Read-only |
| `08-Get-AzManagementGroupRoleAssignments.ps1` | Assignments made at management group level, which are inherited by every subscription underneath, listed per accessible MG. | Read-only |
| `09-Get-AzGuestUserRoleAssignments.ps1` | B2B guest users (UPNs containing `#EXT#`) that hold role assignments on Azure resources. | Read-only |
| `10-Export-AzRbacMatrix.ps1` | The full principal × role × scope matrix, with the scope level (Subscription, ResourceGroup, Resource, ManagementGroup) in a dedicated column. | Read-only |

All ten are read-only: no cmdlet with a `New-`, `Set-`, `Add-` or `Remove-` verb appears anywhere in the code. The only occurrence of `Remove-AzRoleAssignment` in the whole folder sits inside an on-screen message printed by script 04 (warning 1). There is therefore nothing to confirm, and none of the ten offers `-WhatIf`. All ten, however, write a CSV file to disk: see [Where the output goes](#where-the-output-goes).

## Before you run them

**PowerShell** 5.1 or PowerShell 7. None of the ten scripts declares `#Requires -Version`, so the check is not automatic.

**Modules.** All ten declare `#Requires -Modules Az.Accounts, Az.Resources`, and those are the only two modules the code uses:

```powershell
Install-Module Az.Accounts -Scope CurrentUser
Install-Module Az.Resources -Scope CurrentUser
```

The `Az` meta-module contains both, but downloads the whole set: install it only if you use the other Azure toolkits as well. Microsoft Graph is not needed — the `Microsoft.Graph` module is neither imported nor used by any of the ten scripts.

**Authentication.** `Connect-AzAccount`. The scripts call it themselves only when they find no open context: if a context already exists, they work against whichever subscription is selected in it, without asking and without saying so (warning 5).

**Permissions.**

- scripts 01, 02, 04, 05, 06, 07, 09, 10: the **Reader** role on the subscription, plus `Microsoft.Authorization/roleAssignments/read`
- script 03: **Reader** plus `Microsoft.Authorization/roleDefinitions/read`
- script 08: **Reader** at **management group** level, not only at subscription level
- scripts 01, 04, 05, 06, 09, 10, additionally and **not declared in their help**: read access to the Entra ID directory (the **Directory Readers** role, or **Global Reader**). Script 06 needs it to expand group membership, and the others need it for the `Principal`, `SignInName` and `Tipo` columns to be populated: with ARM Reader alone those fields come back empty, and four scripts (04, 05, 07, 09) build a filter on top of them. This is the cause of warnings 1 and 2.

**Closing the session.** None of the ten runs `Disconnect-AzAccount`: once a script ends, the Azure session stays available in the console. Close it by hand when you are finished, especially on a shared machine:

```powershell
Disconnect-AzAccount
```

## ⚠️ Warnings

A rule that applies to every point below: with these ten scripts an empty report, or a count of zero, is not good news until you have confirmed that you had permission to read everything the script queried. Nine out of ten write the CSV even when they found nothing, and the closing message prints the numerator without the denominator: a number without its denominator misleads.

1. **`04-Get-AzOrphanedRoleAssignments.ps1` can list live assignments as orphaned, and its closing message invites you to delete them.** The script classifies an assignment as orphaned whenever both `DisplayName` and `ObjectType` are empty. Those two fields are also empty when the caller does not have read access to the Entra ID directory — that is, with exactly the permissions the help declares — not only when the identity really was deleted. With ARM Reader alone the CSV can therefore contain perfectly active assignments, while the screen reads "N ORPHANED assignments → ... remove them with `Remove-AzRoleAssignment`", with no mention of `-WhatIf`. The script removes nothing itself, but following that advice on an unvalidated result means taking away access that is in use, and a removed assignment cannot be undone: it has to be recreated by hand. Before you touch anything, check for each row that the `ObjectId` is genuinely no longer resolvable in Entra ID, and in any case start from `-WhatIf`:

   ```powershell
   Remove-AzRoleAssignment -ObjectId <ObjectId> -RoleDefinitionName <Role> -Scope <Scope> -WhatIf
   ```

2. **Scripts 06 and 09 can return zero with no error at all because of missing permissions, and in an audit that zero reads as "has no roles".** Script 06 expands group membership with `-ExpandPrincipalGroups`, an operation that requires read access to the Entra ID directory, while its help declares only "Reader + roleAssignments read": with the declared permissions alone the script either fails or returns an incomplete result. Script 09 filters guests on `SignInName -match '#EXT#'`: without directory read, `SignInName` is empty, the filter matches no guest, and the CSV comes out empty with a count of zero and no error message. The same mechanism affects the `ObjectType` column that 05, 07 and 09 filter on. Add directory read to the prerequisites and, before trusting a result, open the CSV and check that `Principal` and `SignInName` are actually populated: if they are empty, the perimeter you read is not the one you think.

3. **`02-Get-AzPrivilegedRoleAssignments.ps1` sees neither privileges inherited from above nor those granted further down.** The filter compares the assignment scope with the subscription scope for exact equality. An Owner assigned on a management group — which the subscription inherits — and an Owner or Contributor assigned on a resource group or on a single resource do not appear in the report, even though they hold those privileges over the resources. The script presents itself as "the first access security check" and answers the question "who has full control of the subscription?": read on its own, it can lead you to conclude that nobody is Owner when somebody is. Always read it together with `08-Get-AzManagementGroupRoleAssignments.ps1` for the level above, and with `10-Export-AzRbacMatrix.ps1`, which reports every assignment with its scope level.

4. **`08-Get-AzManagementGroupRoleAssignments.ps1` counts zero for the management groups it cannot read, and does not distinguish them from those with no assignments.** The read of each MG runs with `-ErrorAction SilentlyContinue`: if you do not have Reader on a management group, that MG contributes zero rows and the total printed at the end looks complete. And if it is the list of management groups that cannot be read, the script prints "management groups not accessible or not configured" and ends without writing the CSV, conflating two different cases — a hierarchy that exists but that you cannot read, and a hierarchy that does not exist. Because MG assignments are the ones inherited by every subscription underneath, an absence at this level is the most expensive one: compare the list of MGs present in the CSV against the tenant's real hierarchy before declaring that level clean.

5. **The perimeter is the subscription selected in the current context, and no CSV has a column that says which one.** Eight of the ten scripts read assignments without passing a scope, so they cover the subscription of the context; 03 reads role definitions in that same context; only 08 leaves that perimeter, by passing management group scopes. None of the ten switches subscription or iterates over the others. If the tenant has more than one, a single run captures only one of them, and the choice is made by the context that is already open: with a `Connect-AzAccount` session in progress you are asked nothing. Check the context before you start, and if you have to cover the whole tenant, repeat on each subscription and give every CSV a different name with `-OutputCsv`:

   ```powershell
   Get-AzContext | Select-Object -ExpandProperty Subscription
   Set-AzContext -Subscription '<subscription name or id>'
   ```

## Where the output goes

All ten scripts export a CSV. The path is parameterised — each one exposes `-OutputCsv` — but the default value is relative and contains only the date, not the time: `.\Az-<report>-<date>.csv`.

- **The file is created wherever the prompt is**, not where the script sits. From a console opened as administrator that is typically `C:\Windows\System32`; if you cloned the repository and run from the cloned folder, the CSV is created inside the clone. The root `.gitignore` excludes `*.csv`, but do not rely on it: check `git status` before you commit.
- **A second run on the same day overwrites the previous one without asking anything**: none of the ten uses `-NoClobber` or `-Append`, and the default name stays identical for the whole day. If you need to keep the reports — the "before" and "after" of a privilege clean-up, for instance — pass a path and a name of your own with `-OutputCsv`.
- **The content describes who has access to what.** The CSVs contain the display name, UPN and email address of internal users and external guests, the `ObjectId` of the principals, the full identifiers of the assignments, the service principals of your automations with their roles, and the map of administrative privileges over the subscription, classic administrators included. For anyone looking for a target, that is precisely the list they want. Write these files outside the repository, to a path with restricted access, and delete them once the report has served its purpose.

## Examples

```powershell
# Every role assignment in the selected subscription
.\01-Get-AzRoleAssignmentReport.ps1

# Roles of a single user, direct and from groups (typically before an offboarding)
.\06-Get-AzUserRoleAssignments.ps1 -SignInName mario.rossi@company.com

# Privileges inherited from the level above, with the CSV written outside the cloned folder
.\08-Get-AzManagementGroupRoleAssignments.ps1 -OutputCsv "$env:USERPROFILE\Documents\Az-MgRoleAssignments.csv"

# The full principal x role x scope matrix
.\10-Export-AzRbacMatrix.ps1
```

---

The same scripts are available as a ZIP download from [synsphere.it/download/toolkit-powershell-azure-rbac](https://synsphere.it/download/toolkit-powershell-azure-rbac/). If you would like help reading a report or setting up access governance on Azure, write to us at [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
