# Azure Governance & Resource Management Toolkit

Ten PowerShell scripts that take a snapshot of a Microsoft Azure environment — resources, tags, empty resource groups, locks, waste left on the bill, who created what — and export the result to CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

The scripts query Azure through the Az module and return the state of one or more subscriptions in tabular form: a full resource inventory, resources missing the required tags, resource groups left empty, the resource locks in place, disks and public IP addresses and network interfaces that stay on the bill without being attached to anything, the spread across regions, and a timeline of write operations taken from the Activity Log. They are aimed at IT administrators and at MSPs who need to take a picture of an Azure tenant, allocate costs to cost centres and find waste, without installing anything beyond the Az module. Nine of the ten scripts are read-only; only one writes to the tenant, and all it writes is tags.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-AzResourceInventory.ps1` | Full inventory: every resource with name, type, resource group, region and tags, plus the subscription it belongs to. The baseline snapshot for governance, audit and capacity planning. Without `-SubscriptionId` it iterates over every accessible subscription. | Read-only |
| `02-Get-AzUntaggedResources.ps1` | Resources with no tags at all or, with `-RequiredTags`, those missing one of the mandatory tags you list, naming which ones are missing. Tags are the basis of cost allocation, ownership and automation. | Read-only |
| `03-Set-AzResourceTagsBulk.ps1` | Propagates a set of tags (CostCenter, Owner, Environment and the like) to every resource in a resource group, in merge mode: existing tags under other keys are kept. Supports `-WhatIf`. | **WRITES** (tags on resources) |
| `04-Get-AzEmptyResourceGroups.ps1` | Resource groups that contain no resource at all, with region and provisioning state: leftovers from closed projects or failed deployments, candidates for decommissioning. It lists them, it deletes nothing. | Read-only |
| `05-Get-AzResourceLocks.ps1` | Every resource lock in the subscription with its level (`CanNotDelete` or `ReadOnly`), notes and the scope it applies to: where resources are protected from accidental deletion and change, and by subtraction where they are not. | Read-only |
| `06-Get-AzOrphanedResources.ps1` | Orphaned resources that stay on the bill without giving anything back: unattached managed disks, public IPs with no association, NICs not attached to a VM, NSGs not associated with a subnet or a NIC. | Read-only |
| `07-Get-AzResourcesByRegion.ps1` | How many resources you have in each region, with the three most common types in each: useful for data residency, latency, and for spotting resources scattered across unexpected regions. | Read-only |
| `08-Get-AzResourceCreationTimeline.ps1` | From the successful write operations in the Activity Log: timestamp, author (`Caller`), operation and resource id. Who created or changed what, and when. Window set by `-Days`, up to 90, because the Activity Log covers roughly 90 days. | Read-only |
| `09-Get-AzSubscriptionSummary.ps1` | For every accessible subscription: state, number of resources, of resource groups and of regions. The overview you need to find your way around a tenant with many subscriptions. | Read-only |
| `10-Export-AzResourceGraph.ps1` | Exports name, type, region, resource group, subscription and tags with a single KQL query against Azure Resource Graph, paging automatically: on large tenants it is far faster than `Get-AzResource`. | Read-only |

## Before you run them

**PowerShell.** PowerShell 5.1 (the version preinstalled on Windows) or PowerShell 7. None of the ten scripts declares a minimum version with `#Requires -Version`: the prerequisite is stated by the collection, not enforced by the code.

**Modules.**

```powershell
Install-Module Az -Scope CurrentUser
Install-Module Az.ResourceGraph -Scope CurrentUser   # script 10 only
```

The `Az` rollup covers the modules declared at the top of the scripts: `Az.Accounts` (all ten), `Az.Resources` (01, 02, 03, 04, 05, 07, 09), `Az.Compute` and `Az.Network` (06), `Az.Monitor` (08). `Az.ResourceGraph` is not part of the rollup and has to be installed separately; only script 10 needs it.

**Authentication.** Interactive. Each script opens the browser with `Connect-AzAccount` if it does not find an existing Az context. There are no passwords, secrets, certificates or service principals in the code: sign in once per session, then run the scripts.

**Permissions.** The Reader role on the subscription (or subscriptions) is enough for the nine reporting scripts. Script 03 needs no more than **Tag Contributor** on the resource group: it writes tags, on individual resources, and touches neither the resource group nor the subscription. Contributor works too, but it is wider than required (see warning 6).

## ⚠️ Warnings

1. **Script 03 is the only one that writes, and by default it asks for no confirmation.** `-WhatIf` genuinely works — the script is declared `SupportsShouldProcess` and goes through `ShouldProcess` for every resource — but `ConfirmImpact = 'High'` is missing: without an explicit `-WhatIf` or `-Confirm` it starts immediately and tags every resource in the resource group in sequence, without a single interaction. Always run it with `-WhatIf` the first time. And "merge" does not mean nothing is lost: tags under other keys are kept, but a key that is already there has its **value overwritten**, so if the resources already carry an `Owner`, yours replaces theirs.

2. **Without `-SubscriptionId`, script 01 covers every subscription the account can see, and script 09 has no such parameter: it always covers them all.** Script 10, through Resource Graph, queries every accessible subscription by design. If you have delegated access to several customers, one run collects all of their estates into a single CSV, with data from different customers in the same file. On top of that, 01 and 09 switch the Az context on every iteration and never restore the original one: when they finish, the session points at the last subscription iterated, and the other scripts (02, 04, 05, 06, 07, 08) read **only** the subscription of the current context. A report you run next in the same console therefore describes that subscription, not the one you have in mind. Pass `-SubscriptionId` to 01, and check `Get-AzContext` before the reports — or save it at the start and restore it with `Set-AzContext`.

3. **The CSV produced by script 08 names people.** The `Caller` field of the Activity Log holds the UPN — the corporate email address — of the person who performed the operation: the export is a "who did what and when" with names attached, and it is personal data in full. Treat it as such: a stated purpose, access limited to those who need it, limited retention. Do not pass it on to third parties without assessing it first.

4. **An error on a single subscription aborts the whole run and leaves no file behind.** `$ErrorActionPreference` is set to `Stop` in all ten scripts and none of them catches the exception: in 01 and 09 the report is built in memory and exported only at the end, so one subscription without permissions, or one throttled call, costs you the entire collection, not just the subscription that failed. The missing CSV is the only signal. In 03 the same mechanism leaves the resource group half tagged, with no summary of what was applied: run it again with the same parameters — the merge is repeatable — and check the result with 02.

5. **An empty report, or a total lower than you expect, is a number that needs explaining, not good news.** The scripts show what Azure returns to the account you signed in with, in the current context, and they do not check that the result is complete: with the Reader role on one subscription only, 06 can print "0 orphaned resources" simply because it cannot see the rest of the tenant. Compare the total against the estate you know — that is also what 09 is for — before concluding that there is nothing to do.

6. **The permission requested by script 03's own documentation is wider than needed.** The script header, like the old `00-LEGGIMI.txt`, asks for Contributor on the resource group: Contributor grants full write control over every resource in the group, while the script touches only the tags of individual resources. The built-in **Tag Contributor** role covers exactly that scope: assign that one, not Contributor.

## Where the output goes

All ten scripts expose `-OutputCsv`, and none of them writes anywhere else: there is no `Out-File`, `Set-Content`, `Add-Content` or `New-Item` anywhere in the toolkit. The default value, however, is a **relative** path of the form `.\Az-<content>-<yyyymmdd>.csv`. Script 04 creates the file only if it finds at least one empty resource group; otherwise it prints the outcome on screen and exports nothing.

Two consequences, always true:

- **The file is created where the prompt is, not where the script is.** If you have cloned the repository and run the scripts from there, the CSV lands inside the clone; if you opened the console as administrator, it lands in that console's directory, typically `C:\Windows\System32`. The root `.gitignore` excludes `*.csv`, but do not rely on the filter: check `git status` before committing, or pass `-OutputCsv` with an absolute path outside the repository.
- **A second run on the same day overwrites the first one, without asking.** The default name carries only the date, not the time. If you need the CSVs as evidence to keep, pass `-OutputCsv` with a name of your own, or move the file before running again.

**What is inside those files.** Script 08 exports the operators' UPNs (warning 3). Scripts 01 and 10 export tags verbatim: if a tag holds the name of a contact or an internal reference, that value ends up in the CSV. Scripts 05 and 06 hold no personal data, but they describe, by name, the protections and the disconnected resources of the environment. All of them are internal files, and the rules that apply to any document describing a customer's infrastructure apply here too.

## Examples

```powershell
# Authentication: once per session
Connect-AzAccount

# Full resource inventory (every accessible subscription)
.\01-Get-AzResourceInventory.ps1

# Resources missing one of the mandatory tags
.\02-Get-AzUntaggedResources.ps1 -RequiredTags CostCenter,Owner,Environment

# Who created or changed resources in the last 60 days
.\08-Get-AzResourceCreationTimeline.ps1 -Days 60

# Dry run of the bulk tagging: lists the resources, applies nothing
.\03-Set-AzResourceTagsBulk.ps1 -ResourceGroupName rg-prod -Tags @{CostCenter='IT';Environment='Prod'} -WhatIf
```

## More

The same content is available as a ZIP archive from the toolkit page on our site: [synsphere.it/download/toolkit-powershell-azure-governance](https://synsphere.it/download/toolkit-powershell-azure-governance/).

If you would rather have Azure governance as a managed service, or if a script does not behave as described here: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
