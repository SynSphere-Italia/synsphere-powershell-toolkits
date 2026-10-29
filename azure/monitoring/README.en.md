# Azure Monitoring and Operations

Ten read-only PowerShell scripts that capture the state of monitoring, alerting, backup and diagnostics on an Azure subscription, and export every report to CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

For anyone who administers Azure in-house, and for anyone who does it on behalf of others (MSPs), when the job is to answer one question quickly: on this subscription, what is monitored and what is not.

Alert rules, action groups, Log Analytics workspaces, diagnostic settings, autoscale and backup are configured in different places in the portal, and no single screen shows them together: the missing piece gets discovered during the incident. Each of the ten scripts reads one of those surfaces, without changing anything, and leaves the result in a CSV you can filter or attach to a record.

## Scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Export-AzActivityLog.ps1` | The Activity Log for the last N days: management operations (create, update, delete, administrative actions) with who performed them, when, on which resource and with what outcome. The Activity Log covers roughly 90 days; there is nothing beyond that. | Read-only |
| `02-Get-AzAlertRules.ps1` | Inventory of the alert rules — metric alerts and scheduled query alerts — with the resource each one watches, its severity and whether it is enabled: the point is to see what is monitored and what is not. | Read-only |
| `03-Get-AzActionGroups.ps1` | Action groups, that is, who gets notified when an alert fires: short name, state, and how many email, SMS and webhook receivers each one has. If there are none, the alerts notify nobody. | Read-only |
| `04-Get-AzLogAnalyticsWorkspaces.ps1` | Log Analytics workspaces with SKU, retention days and region: long retention is a cost, and duplicate workspaces mean telemetry scattered across several places. | Read-only |
| `05-Get-AzBackupJobStatus.ps1` | Recent backup jobs for each Recovery Services vault, with outcome, start time and duration, plus a count of the failed ones. A backup that is configured but failing is worse than no backup, because it gives false confidence. | Read-only |
| `06-Get-AzVmMetricSnapshot.ps1` | CPU usage of every VM over the period, with size and resource group: it is meant as objective evidence for rightsizing decisions. Only running VMs produce metrics. Read warning 1 before you use the peak column. | Read-only |
| `07-Get-AzAutoscaleSettings.ps1` | Autoscale settings with their target resource, whether they are enabled and how many profiles they have: to check what actually adapts capacity to load and what stays fixed. | Read-only |
| `08-Get-AzDiagnosticSettingsReport.ps1` | For the resources that have them, the diagnostic settings and where they send logs (Log Analytics, Storage, Event Hub). It queries one resource at a time, so on large tenants it can take a while; `-ResourceTypeLike` narrows the scope to one type. | Read-only |
| `09-Get-AzActivityLogAlerts.ps1` | Activity Log alerts, including Service Health notifications (Azure incidents and planned maintenance), with scope and state. | Read-only |
| `10-Get-AzOperationalRecommendations.ps1` | Azure Advisor recommendations in the operational excellence and high availability categories, with impact, problem and proposed solution: an operational improvement backlog, already written. | Read-only |

Ten out of ten are read-only: every Azure cmdlet in the code is a `Get-Az*`, plus `Connect-AzAccount` for authentication, and there is no cmdlet with a `New-`, `Set-`, `Add-`, `Remove-` or equivalent verb. So there is nothing to confirm and `-WhatIf` is not provided. All ten, however, write a CSV file to disk: see [Where the output goes](#where-the-output-goes).

## Before you run them

**PowerShell** 5.1 or PowerShell 7. None of the ten scripts declares `#Requires -Version`, so nothing checks this for you.

**Modules.** Each script declares its own in `#Requires -Modules`, so a missing module stops execution immediately, before anything connects:

```powershell
Install-Module Az.Accounts -Scope CurrentUser             # all ten
Install-Module Az.Monitor -Scope CurrentUser              # scripts 01, 02, 03, 06, 07, 08, 09
Install-Module Az.OperationalInsights -Scope CurrentUser  # script 04
Install-Module Az.RecoveryServices -Scope CurrentUser     # script 05
Install-Module Az.Compute -Scope CurrentUser              # script 06
Install-Module Az.Resources -Scope CurrentUser            # script 08
Install-Module Az.Advisor -Scope CurrentUser              # script 10
```

The rollup module `Install-Module Az -Scope CurrentUser` is the alternative, but it downloads the whole set; afterwards check with `Get-Module -ListAvailable Az.*` that every module in the list above is actually there.

**Authentication.** `Connect-AzAccount`, once per session. Each script calls it itself if it does not find a context already open.

**Permissions.** The **Reader** role on the subscription is enough for eight of the ten scripts. The exceptions:

- `05-Get-AzBackupJobStatus.ps1`: the **Backup Reader** role;
- `06-Get-AzVmMetricSnapshot.ps1`: Reader to list the VMs and **Monitoring Reader** to read the metrics, as its own help states.

No script asks for Microsoft Graph permissions: there is no `Connect-MgGraph` and no scope for an administrator to consent to. The roles required are the minimum needed for read-only cmdlets.

## ⚠️ Warnings

Two rules apply to every point below. An empty report, or one that is all zeros, is not good news until you have confirmed you actually had permission to read everything the script queried: a number without its denominator misleads. And the scope of every report is a single subscription, even when the tenant has twelve.

1. **`06-Get-AzVmMetricSnapshot.ps1`: the `CPUPiccoPct` column is not the peak.** The script asks Azure Monitor for the `Average` aggregation only, at one-hour granularity, and then takes the maximum of those hourly averages: the value in the column is the highest hourly average, not the highest value recorded. A VM that runs at 100% for five minutes within an otherwise idle hour is reported at around 10%. The error runs in the expensive direction: it understates spikes, and the script's stated purpose is rightsizing, so it pushes you to shrink exactly the VMs that do have peaks. Do not base a resizing decision on this column. Read `CPUMediaPct` for what it is, an average, and check the real peaks on the `Percentage CPU` metric with the Max aggregation, from the portal or by asking `Get-AzMetric` for `-AggregationType Maximum`.

2. **Every report covers one subscription only, and says so nowhere.** None of the ten scripts accepts `-SubscriptionId` and none iterates over `Get-AzSubscription`: the scope is always the subscription of the current context. On a tenant with several subscriptions you get the inventory of one, and the closing message stays green — the omission produces no error, so "no alerts configured" actually means "no alerts in this subscription". Before you run anything, check where you are with `Get-AzContext`; to cover everything, loop by hand with `Set-AzContext -Subscription <id>` and keep the CSVs apart, because the default file name does not include the subscription and the second pass would overwrite the first.

3. **The Activity Log CSV is a named list of people's work activity.** The `Caller` column in `01-Export-AzActivityLog.ps1` holds the identity (UPN or email address) of the person who performed each individual operation, together with the date, the time and the resource. The file left on disk is personal data in the full sense, in clear text, and the purpose is an audit: keep it for the duration of the analysis and no longer, write it to a location with restricted access, and do not attach it to a ticket or an email. If you have to share the result, remove or replace the `Caller` column before you hand it over.

4. **The help of `01-Export-AzActivityLog.ps1` promises a filter the code does not apply.** Its `.DESCRIPTION` states that the script exports "filtrando le operazioni riuscite" (filtering for successful operations): it does not, no filter is applied anywhere. The CSV contains every operation, successful and failed alike, and the outcome sits in the `Stato` column. Anyone reading that help in an audit context believes the failures have already been excluded, and counts as successful something that was not — an attempted deletion that was refused, for instance. Filter on the `Stato` column yourself, according to what you need to show.

5. **In `08` and in `06`, per-resource errors are swallowed silently, and a zero is indistinguishable from a failure.** `08-Get-AzDiagnosticSettingsReport.ps1` enumerates every resource in the subscription and queries the diagnostic settings one by one inside an empty `catch`: if you lack permission on a class of resources, or if that resource type does not support diagnostic settings, the result is identical to "no diagnostics configured" — and the final count is still printed in green, as a success. The same mechanism in `06-Get-AzVmMetricSnapshot.ps1` shows `n/d` both for a stopped VM and for a VM whose metric call failed. Compare the rows in the CSV against the number of resources examined — `(Get-AzResource).Count` — and if the report is empty or nearly so, check your permissions before concluding that the diagnostics are not there.

6. **In `05` and in `06`, a negative `-Days` produces an empty report with no error at all.** The parameter is a bare `[int]` with no validation: with a negative value the start date lands in the future, the requested interval is empty, and the script finishes with its success message and zero rows. On `05` that reads as "zero backup jobs, zero failures", which at a glance looks like good news. Always pass a positive number. `01-Export-AzActivityLog.ps1` is the only one that defends itself, with an accepted range of 1-90 days aligned to the Activity Log retention.

## Where the output goes

All ten scripts export a CSV. The default name is relative and contains the date only, not the time: `.\Az-<report>-<yyyymmdd>.csv`.

- **The file is created where the prompt is**, not where the script is. If you cloned the repository and run from the clone, the CSV is created inside the clone. The root `.gitignore` excludes `*.csv`, but do not rely on it: check `git status` before you commit.
- **A second run on the same day overwrites the first one without asking**: the name carries the date, and no script uses `-NoClobber`. If you need to keep the reports, or to compare two subscriptions, pass your own path and file name with `-OutputCsv`.
- **Treat the content as customer data.** The CSV from `01` contains the identities of real people: see warning 3. The other nine export no identities — `03`, in particular, reports how many receivers an action group has, not their addresses — but they do describe the infrastructure: VM names and sizes, vault and workspace names, resource groups, and above all which resources are not monitored and where the logs do or do not go. Write them outside the repository, to a location with restricted access, and delete them once the report has served its purpose.

## Examples

```powershell
# Authenticate, and check where you are (see warning 2)
Connect-AzAccount
Get-AzContext

# Activity Log for the last 30 days
.\01-Export-AzActivityLog.ps1 -Days 30

# Backup jobs from the last two weeks
.\05-Get-AzBackupJobStatus.ps1 -Days 14

# CPU snapshot of the VMs over 14 days (on the peak column, see warning 1)
.\06-Get-AzVmMetricSnapshot.ps1 -Days 14

# Diagnostic settings for network resources only
.\08-Get-AzDiagnosticSettingsReport.ps1 -ResourceTypeLike '*Microsoft.Network*'
```

---

The same scripts are available as a ZIP download from [synsphere.it/download/toolkit-powershell-azure-monitoring](https://synsphere.it/download/toolkit-powershell-azure-monitoring/). If you would like help reading a report, or making sure your alerts and backups actually notify someone, write to us at [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
