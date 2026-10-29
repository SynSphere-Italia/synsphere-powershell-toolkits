# Azure cost analysis and optimisation

Ten read-only PowerShell scripts that show where a subscription's Azure spend goes, what you can cut right away and where the current month is heading: each one exports a CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

This collection is aimed at IT administrators, MSPs and FinOps leads in small and medium businesses who hold a read-only role on Azure (Cost Management Reader, Billing Reader or Reader) and want the figures in a CSV instead of clicking through the portal.

It answers three questions in sequence: where the money goes (cost by resource group, by service, by individual resource, monthly trend), what can be cut right away (unattached managed disks, unassociated public IPs, disks of deallocated VMs, Azure Advisor recommendations) and where things are heading (budget status, increases over the previous month, end-of-month projection).

Every script stands alone, takes its parameters on the command line and works on whichever subscription is active in the `Connect-AzAccount` context.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-AzCostByResourceGroup.ps1` | Sums the period's pre-tax cost per resource group, deriving the group from the usage record's `InstanceId`: the first view for working out where the money goes. Default period runs from the first day of the current month to today (`-StartDate`, `-EndDate`). | Read-only |
| `02-Get-AzCostByService.ps1` | The same usage aggregated by consumed service (`ConsumedService`): which services weigh most on the bill. It also prints the top eight rows on screen. | Read-only |
| `03-Get-AzCostTrend.ps1` | Monthly spend over the last N months (`-Months`, default 6), grouped by usage month: it shows whether costs are growing and by how much. | Read-only |
| `04-Get-AzTopCostResources.ps1` | Ranks individual resources by cost for the period and keeps the top N (`-Top`, default 25), with their resource group: it pinpoints the big spenders to concentrate on. | Read-only |
| `05-Get-AzIdleCostlyResources.ps1` | Resources that cost money without being used: unattached managed disks and unassociated public IP addresses, with size, SKU, allocation method and location. This is a list of candidates — see warning 1. | Read-only |
| `06-Get-AzDeallocatedVmDiskCost.ps1` | Deallocated VMs with their managed disks, OS and data, size and SKU: a deallocated VM pays no compute but keeps paying for its disks. | Read-only |
| `07-Get-AzCostAdvisorRecommendations.ps1` | Azure Advisor recommendations in the Cost category (rightsizing and shutdown of underused VMs, reserved instances and more), with impact, problem, solution and the resource concerned. | Read-only |
| `08-Get-AzBudgetStatus.ps1` | The budgets configured on the subscription with their limit, current spend, usage percentage, period (`TimeGrain`) and currency: so you can see at a glance whether you are about to overrun. | Read-only |
| `09-Get-AzCostAnomalies.ps1` | Compares month-to-date spend per service with the same number of days in the previous month and flags increases above the threshold (`-ThresholdPercent`, default 30). | Read-only |
| `10-Get-AzCostForecast.ps1` | Month-to-date spend and an end-of-month projection from the daily average, with days elapsed and currency. Its header states that the estimate is linear and ignores seasonality and spikes. | Read-only |

"Read-only" here is a measurement, not a promise. Across the ten scripts there is not a single cmdlet with the verb `Remove`, `Set`, `New`, `Update`, `Disable`, `Stop`, `Restart`, `Revoke`, `Reset`, `Clear`, `Add` or `Invoke`: every Azure cmdlet they call is a `Get-*`, and the only non-reading verbs in the whole collection are `Connect-AzAccount` for the sign-in and `Export-Csv` for writing the report. None of them needs `-WhatIf`, because there is nothing in the tenant to protect. The risk in this collection lies elsewhere: in what the reports lead you to believe, and in where the files end up.

## Before you run them

**PowerShell.** PowerShell 5.1 or PowerShell 7. None of the ten scripts contains `#Requires -Version`, so the requirement is not checked at startup: the version quoted here is the one stated by the instructions file that came with the collection.

**Modules.**

```powershell
Install-Module Az -Scope CurrentUser
```

The `Az` meta-module is the short way and covers everything. If you prefer to install only what is needed, the scripts' `#Requires` directives declare five modules: `Az.Accounts` (all ten), `Az.Billing` (`01`, `02`, `03`, `04`, `09`, `10` — it is the module that exports `Get-AzConsumptionUsageDetail` and `Get-AzConsumptionBudget`), `Az.Compute` (`05`, `06`), `Az.Network` (`05`), `Az.Advisor` (`07`).

```powershell
Install-Module Az.Accounts, Az.Billing, Az.Compute, Az.Network, Az.Advisor -Scope CurrentUser
```

**One declared dependency is wrong, and we are telling you.** `08` opens with `#Requires -Modules Az.Accounts, Az.Consumption`, but `Az.Consumption` does not exist as an installable module: the cmdlet that script uses, `Get-AzConsumptionBudget`, is exported by `Az.Billing` (verified with `Get-Command`). Where `Az.Consumption` is absent, `08` does not start at all, because `#Requires` stops the script before its first line of code. If you see that missing-module error it is not your environment: it is the `#Requires` line that needs fixing.

**Azure roles.** Cost Management Reader, or Billing Reader, for the usage data (`01`, `02`, `03`, `04`, `09`); Cost Management Reader for budgets and forecast (`08`, `10`); the Reader role on the subscription for the inventory of disks, IPs and VMs (`05`, `06`) and for Azure Advisor (`07`). No script asks for a role with write privileges: there is no reference to Contributor, Owner or Administrator anywhere in the collection.

**Microsoft Graph: no permissions.** The toolkit does not use Graph. There is no `Connect-MgGraph`, no scopes to have approved and no application consent to grant in Entra ID.

**Authentication.** Run `Connect-AzAccount` first. It is the `Az` module's interactive sign-in, with MFA if the tenant requires it; no script contains credentials, client secrets or certificates.

**Subscription type.** The usage data comes from `Get-AzConsumptionUsageDetail`, which is supported on PAYG, EA and MCA subscriptions with some limits; on very large tenants the queries can take time.

## ⚠️ Warnings

1. **`05` produces a list of candidates, not of resources to delete.** The disk filter is `DiskState -eq 'Unattached' -or -not $_.ManagedBy`: that `-or` makes the set wider than the `Unattached` state alone. A disk that is not in the `Unattached` state but has an empty `ManagedBy` is still labelled "Disco non collegato" (unattached disk), and that is exactly the case of shared disks (with `maxShares` above 1 the VMs using them are listed in `ManagedByExtended`) and of disks exposed through SAS or holding an active lease. The CSV reports neither `DiskState` nor `ManagedByExtended`, so the false positive is invisible in the report, and the closing message reads "Valuta l'eliminazione" (consider deleting). The script deletes nothing, but deleting a disk cannot be undone: check every row in the portal before you remove anything. The same applies to public IPs, where the filter is simply the absence of `IpConfiguration`, with no distinction of SKU or allocation method, while the script header speaks of Standard IPs: read the `Dettaglio` column before treating a row as recoverable spend.

2. **The scope is one single subscription, and no report says so.** Every script works on the current context, and none of the ten loops over subscriptions or prints which one it queried. On a tenant with several subscriptions the CSV covers only the active one, yet nothing in the output flags it: "3 idle resources" reads as the tenant total when it is one subscription's total. Set the scope before you run anything, with `Set-AzContext -Subscription <name-or-id>`, and if you have more than one subscription write the loop yourself, putting the identifier in the file name:

   ```powershell
   foreach ($s in Get-AzSubscription) {
       Set-AzContext -Subscription $s.Id | Out-Null
       .\01-Get-AzCostByResourceGroup.ps1 -OutputCsv ".\Az-CostByRG-$($s.Id)-$(Get-Date -Format 'yyyyMMdd').csv"
   }
   ```

3. **The CSVs are a map of the customer's infrastructure.** The reports contain resource names, resource groups, locations, VM and disk names with SKU and size, the `ResourceId` of the Advisor recommendations and the spend amounts. To whoever receives them they are an environment's inventory and its spending profile: do not attach them to a ticket, do not send them unencrypted, do not leave them in shared folders. There is an operational side too: `05` calls `Get-AzDisk` and `Get-AzPublicIpAddress` without `-ResourceGroupName`, and `06` calls `Get-AzVM -Status`, which means one status query per VM. Both enumerate the entire subscription, and on large environments they can take minutes and be slowed down by API throttling.

4. **The automatic sign-in opens an interactive window.** All ten scripts start with `if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }`: in a non-interactive run, such as a scheduled job or a pipeline, the script sits waiting for a sign-in nobody will perform instead of failing immediately with a clear error, and that `| Out-Null` also discards the sign-in result. They are built for interactive use: to automate them, authenticate a service principal first with `Connect-AzAccount -ServicePrincipal` and check `Get-AzContext` yourself in whatever calls them.

5. **In `08` an empty result proves nothing, and the first row is not the budget most at risk.** If `Get-AzConsumptionBudget` returns nothing, the script prints "Nessun budget configurato sulla subscription" (no budget configured on the subscription) and exits without writing the CSV: that message means "no budget visible on the context's subscription, with the role you hold", not "no budget in the tenant". Before concluding that there are no spending controls, check your role and the scope from warning 2. In the same report the `Percent` column is a string (`"95%"`) and the sort is textual, not numeric: a budget at 100% ends up below one at 95%. Do not stop at the first row — re-sort the rows on the spent-to-limit ratio.

6. **`09` and `10` contain figures that are not measurements.** `09` assigns `999%` to services that had no comparable spend in the previous month: it is a placeholder for "nothing to compare against", not a calculated change. The same script only flags increases that clear both the percentage threshold and one unit of currency in absolute terms, and it iterates over the current month's services only, so a service that shrank or disappeared never shows up: the report answers "what grew", not "what changed". The forecast in `10` is the current month's daily average multiplied by the days in the month, as its own header states: a spike in the first few days inflates the projection for the rest of the month. Use these two as a signal to go and look, not as a figure to pass on to anyone else.

One thing that is not a risk, and is worth knowing: none of the ten scripts has a `try/catch`, and all of them set `$ErrorActionPreference = 'Stop'`. A missing permission or a rejected call stops execution and shows the Azure error, rather than producing half a report. The treacherous case is not the error: it is the legitimately empty result in warning 5.

## Where the output goes

All ten scripts declare an `-OutputCsv` parameter, and its default is a relative path, `.\Az-<name>-<yyyyMMdd>.csv`. There are no absolute paths in the collection, and no script uses `Out-File`, `Set-Content` or `New-Item`: the only write to disk is the report's `Export-Csv`.

Two consequences to keep in mind. The file is created in the directory the prompt is sitting in, not next to the script: if you cloned this repository and run from there, the CSV lands inside the clone — the `.gitignore` excludes `*.csv`, but check `git status` before committing instead of trusting it. And the name contains only the date, with no time: a second run on the same day overwrites the first without asking. If you need to keep two runs, or to tell two subscriptions apart, pass `-OutputCsv` with an explicit path.

The content includes no credentials and no user lists, but it is confidential customer material: the resource inventory with its names, the resource groups, the locations, the disks with SKU and size, the VMs, the `ResourceId` values of the Advisor recommendations, and the spend amounts in currency, budget limits and projections included. Treat it the way you would treat that customer's invoice and infrastructure diagram. The only script that may produce no file at all is `08`, when it finds no budgets.

## Examples

```powershell
# Current month's cost by resource group
.\01-Get-AzCostByResourceGroup.ps1

# Spend trend over the last 12 months
.\03-Get-AzCostTrend.ps1 -Months 12

# The 50 most expensive resources in the period
.\04-Get-AzTopCostResources.ps1 -Top 50

# Services up by at least 25% against the same number of days last month
.\09-Get-AzCostAnomalies.ps1 -ThresholdPercent 25
```

## Download and support

The same content is available as a ZIP from [synsphere.it/download/toolkit-powershell-azure-cost-management](https://synsphere.it/download/toolkit-powershell-azure-cost-management/). If you want a hand reading the reports, or deciding what can really be switched off, write to us at [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
