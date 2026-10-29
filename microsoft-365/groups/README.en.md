# Microsoft 365 Groups and Membership

Ten read-only PowerShell scripts that inventory the groups, distribution lists and memberships of a Microsoft 365 tenant, and export every report to CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

For anyone who administers a Microsoft 365 tenant in-house, and for anyone who does it on behalf of others (MSPs), when the job is cleaning up groups, auditing access or offboarding a user.

In Microsoft 365 the same information sits on two surfaces: Microsoft 365 and security groups live in Microsoft Graph, distribution lists live in Exchange Online — and DLs are not visible from the user's own page. The first five scripts read from Graph, the other five from Exchange Online. Each one answers a single question and leaves the result in a CSV you can filter or attach to a record.

## Scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-M365AllGroupsReport.ps1` | Inventory of every group in the tenant — Microsoft 365, security, mail-enabled security, distribution, dynamic — classified by type, with a member count. | Read-only |
| `02-Get-M365GroupMembersReport.ps1` | For each Microsoft 365 group, its owners and members: one row per membership, with the role and the type (internal or guest). | Read-only |
| `03-Get-M365UserMembershipReport.ps1` | Reverse lookup: given a user, the groups they are a direct member of (see the warnings). | Read-only |
| `04-Get-M365EmptyGroups.ps1` | Groups with no members, listed as candidates for decommissioning. | Read-only |
| `05-Get-M365OwnerlessM365Groups.ps1` | Microsoft 365 groups with no owner: nobody is accountable for the membership or for the connected content (Teams, SharePoint, Planner). | Read-only |
| `06-Get-M365DistributionGroupReport.ps1` | Distribution lists with one row per member: name, email, type. | Read-only |
| `07-Get-M365DynamicDLMembers.ps1` | Dynamic distribution groups: evaluates each group's filter and shows the recipients that match it at that moment. | Read-only |
| `08-Get-M365UserDistributionGroups.ps1` | Reverse lookup on DLs: given a user, the distribution lists that contain them. | Read-only |
| `09-Get-M365GroupMailboxSize.ps1` | Size and item count of the conversation mailbox of each Microsoft 365 group. The storage of the connected SharePoint site is separate and is not included. | Read-only |
| `10-Get-M365NestedDistributionGroups.ps1` | Recursive expansion of nested DLs: a flat list of the final members with the nesting path, with loop protection. | Read-only |

Ten out of ten are read-only: the code contains no cmdlet with a `New-`, `Set-`, `Add-`, `Remove-` or equivalent verb, so there is nothing to confirm and `-WhatIf` is not provided. All ten, however, write a CSV file to disk: see [Where the output goes](#where-the-output-goes).

## Before you run them

**PowerShell** 5.1 or PowerShell 7. None of the ten scripts declares `#Requires -Version`, so nothing checks this for you.

**Modules, scripts 01-05 (Microsoft Graph):**

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Groups -Scope CurrentUser    # scripts 01, 02, 04, 05
Install-Module Microsoft.Graph.Users -Scope CurrentUser      # script 03
```

The `#Requires` line in scripts 01-05 names only `Microsoft.Graph.Authentication`, but the cmdlets they call live elsewhere: `Get-MgGroup`, `Get-MgGroupMember` and `Get-MgGroupOwner` are in `Microsoft.Graph.Groups`, `Get-MgUser` and `Get-MgUserMemberOf` in `Microsoft.Graph.Users`. With only the authentication module installed, the `#Requires` check passes, `Connect-MgGraph` succeeds, and the script dies at the first `Get-Mg*` with "term is not recognized". Install the sub-modules above; the `Microsoft.Graph` meta-module contains them all but downloads the whole SDK.

**Modules, scripts 06-10 (Exchange Online):**

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

**Permissions.** The Graph scripts request their delegated scopes at startup through `Connect-MgGraph`; all of them are read-only.

- scripts 01, 02, 04: `Group.Read.All` and `GroupMember.Read.All`
- script 03: `User.Read.All` and `GroupMember.Read.All`
- script 05: `Group.Read.All`
- scripts 06-10: Exchange Online, **View-Only Recipients** role. It also covers `Get-EXOMailbox` and `Get-EXOMailboxStatistics` in script 09 and the DL scan in script 08, whose help mentions only "Exchange Online" without naming the role.

**Closing the session.** None of the ten scripts disconnects: the connection and its token stay open for the lifetime of the console, and sessions pile up if you run several scripts one after another — which is exactly how a numbered toolkit gets used. Close them by hand when you are done:

```powershell
Disconnect-MgGraph
Disconnect-ExchangeOnline -Confirm:$false
```

## ⚠️ Warnings

One rule applies to every point below: an empty report, or one that is all zeros, is not good news until you have confirmed you actually had permission to read everything the script queried. A number without its denominator misleads.

1. **`04-Get-M365EmptyGroups.ps1` also lists as "empty" any group it failed to read.** The member count runs with `-ErrorAction SilentlyContinue`: if reading the membership fails — permission denied on that group, Graph throttling, a deleted member — the count is 0 exactly as it is for a genuinely empty group, and the group lands in the CSV under the label the script prints on screen, "gruppi VUOTI (candidati alla pulizia)" (empty groups, cleanup candidates). Anyone deleting from that list can delete a group that has members. Check every group before decommissioning it, by reopening its membership in the portal or with a dedicated read. The script also makes one call per group in the tenant: on large tenants throttling is to be expected, so run it outside business hours — and throttling is one of the very causes of those zeros.

2. **`08-Get-M365UserDistributionGroups.ps1` can return zero rows for a user who is in many lists.** It compares the UPN you pass with each member's `PrimarySmtpAddress`, and the two match only by convention: with a UPN on a non-routable domain, a `*.onmicrosoft.com` UPN, or a primary address different from the UPN, the comparison never matches and the script exits successfully with an empty CSV. Aliases (the other addresses in `EmailAddresses`) are ignored in any case. The stated use is offboarding: a false empty result means a user who leaves the company and stays in every distribution list. Before you trust an empty result, check the real primary address with `Get-Recipient -Identity <UPN>` and run the script again with that address.

3. **`05-Get-M365OwnerlessM365Groups.ps1` can declare a group ownerless when it does have an owner.** The owner lookup runs with `-ErrorAction SilentlyContinue`: if it fails, the owner list comes back empty and the group is printed in red with "ATTENZIONE: ... gruppi M365 SENZA owner ... Assegna un proprietario" (warning: M365 groups with no owner, assign one). Check each flagged group individually before opening a governance task or reassigning owners.

4. **The `Members` column in `01-Get-M365AllGroupsReport.ps1` is 0 even when the read failed.** Same mechanism as point 1: the error is swallowed and the inventory presents as certain a count that is the result of an error. This script too queries the whole tenant with one call per group. Any group showing 0 members in the inventory must be re-read on its own before you act on it.

5. **`03-Get-M365UserMembershipReport.ps1` reports direct memberships only.** It uses `Get-MgUserMemberOf`, which does not return groups reached through a nested group, while its help promises "all groups". In an access audit the report under-reports without saying so. Read the result as "groups the user is a direct member of"; for full membership you need `Get-MgUserTransitiveMemberOf`.

6. **`10-Get-M365NestedDistributionGroups.ps1` silently skips dynamic sub-trees.** When it finds a dynamic distribution group inside a DL it treats it as an ordinary DL, but the cmdlet that reads its members does not accept a dynamic group: the error is swallowed and that branch yields zero members. The "flat list of final members" therefore loses every recipient of that sub-tree, with no warning at all. If your DLs contain dynamic DLs, resolve them separately with `07-Get-M365DynamicDLMembers.ps1` and merge the two CSVs. The loop protection, on the other hand, does work: each root starts with a fresh set of visited groups.

## Where the output goes

All ten scripts export a CSV. The default name is relative and contains the date only, not the time: `.\M365-<report>-<date>.csv`.

- **The file is created where the prompt is**, not where the script is. From an elevated console that is typically `C:\Windows\System32`; if you cloned the repository and run from the clone, the CSV is created inside the clone. The root `.gitignore` excludes `*.csv`, but do not rely on it: check `git status` before you commit.
- **A second run on the same day overwrites the first one without asking**: no script uses `-NoClobber`. If you need to keep the reports, pass your own path and file name with `-OutputCsv`.
- **The content is personal data.** The CSVs contain the name, UPN and email address of every user and every external guest of the tenant, the full composition of the distribution lists, and group mailbox sizes. Write them outside the repository, to a location with restricted access, and delete them once the report has served its purpose.

## Examples

```powershell
# Inventory of every group in the tenant
.\01-Get-M365AllGroupsReport.ps1

# Groups of a single user, with the CSV written outside the cloned folder
.\03-Get-M365UserMembershipReport.ps1 -UserPrincipalName mario.rossi@contoso.com -OutputCsv "$env:USERPROFILE\Documents\M365-UserMembership.csv"

# Distribution lists that contain that user (typically before an offboarding)
.\08-Get-M365UserDistributionGroups.ps1 -UserPrincipalName mario.rossi@contoso.com

# Recursive expansion of nested DLs
.\10-Get-M365NestedDistributionGroups.ps1
```

---

The same scripts are available as a ZIP download from [synsphere.it/download/toolkit-powershell-gruppi-microsoft-365](https://synsphere.it/download/toolkit-powershell-gruppi-microsoft-365/). If you would like help reading a report or setting up governance for groups and distribution lists, write to us at [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
