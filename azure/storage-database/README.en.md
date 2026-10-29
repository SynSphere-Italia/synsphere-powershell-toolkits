# Azure Storage & Database Toolkit

Ten read-only PowerShell scripts that take a snapshot of the storage accounts and SQL databases in an Azure subscription and export each result to a CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

It produces a security, compliance and cost assessment of an Azure subscription with nothing installed beyond the Az module: storage redundancy and used capacity, blob containers open to anonymous access, network and firewall rules, missing lifecycle policies, an inventory of databases and elastic pools, TDE encryption, auditing and backup retention.

It is meant for IT administrators, MSPs and DBAs who need the state of a tenant on paper without setting up an assessment tool. Each script answers one question and leaves behind a CSV you can attach to a report or compare with the previous run.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-AzStorageInventory.ps1` | A snapshot of every storage account: redundancy (LRS/ZRS/GRS), kind, access tier and basic security settings (HTTPS only, public blob access allowed). | Read-only |
| `02-Get-AzStorageContainerPublicAccess.ps1` | Checks container by container which ones allow anonymous access (`PublicAccess` Blob or Container), one of the most common causes of data exposure on Azure. | Read-only (needs data-plane access) |
| `03-Get-AzStorageNetworkRules.ps1` | For each storage account: the firewall default action (Allow/Deny), public network access, and how many IP and VNet rules are configured. | Read-only |
| `04-Get-AzStorageWithoutLifecycle.ps1` | Lists the storage accounts with no lifecycle management policy, where old blobs stay in the hot tier and are never deleted. | Read-only |
| `05-Get-AzSqlDatabaseInventory.ps1` | Lists the logical SQL servers and their databases with edition, service objective, maximum size and status (`master` excluded). | Read-only |
| `06-Get-AzSqlFirewallRules.ps1` | Lists the server-level firewall rules and flags the risky ones: "Allow Azure services" (0.0.0.0) and the range open to everyone. | Read-only |
| `07-Get-AzSqlSecurity.ps1` | Transparent Data Encryption state database by database, and the auditing state at server level. | Read-only |
| `08-Get-AzStorageCapacity.ps1` | Space used by each storage account, read from the `UsedCapacity` metric. | Read-only |
| `09-Get-AzSqlBackupRetention.ps1` | Short-term backup retention days and long-term retention policies (weekly, monthly, yearly) for each database. | Read-only |
| `10-Get-AzSqlElasticPools.ps1` | Lists the elastic pools with edition, capacity and number of databases they hold. | Read-only |

None of the ten scripts changes the tenant: there is not a single call other than a `Get-` in any of them. No write permission is needed to run them.

## Before you run them

**PowerShell** 5.1 or PowerShell 7. No script declares `#Requires -Version`, so the version is never checked at startup: on an unsupported version the error comes from the cmdlet, not from the script.

**Modules.** Each script declares its own `#Requires -Modules` and stops if they are missing.

```powershell
Install-Module Az -Scope CurrentUser
```

Or just the four modules actually used:

```powershell
Install-Module Az.Accounts, Az.Storage, Az.Sql, Az.Monitor -Scope CurrentUser
```

- `Az.Accounts` — all ten
- `Az.Storage` — 01, 02, 03, 04, 08
- `Az.Sql` — 05, 06, 07, 09, 10
- `Az.Monitor` — 08 only

**Authentication.** `Connect-AzAccount`. If no Azure context is found, each script calls it itself and opens an interactive login.

**Permissions.**

- the **Reader** role on the subscription: eight scripts out of ten (01, 03, 04, 05, 06, 07, 09, 10)
- **02** additionally needs a data-plane role on the storage: **Storage Blob Data Reader**
- **08** needs **Monitoring Reader** to read the `UsedCapacity` metric
- the `.NOTES` of **07** says "Reader/SQL Security Manager": that is wrong, see the warnings

## ⚠️ Warnings

1. **A zero from `02` does not prove there are no public containers.** When data-plane access is denied on a storage account, the script emits a `Write-Warning` and moves on to the next one; at the end it still prints "0 containers with public access". A permission error and a genuinely clean tenant produce the same reassuring message, on the very script meant to find exposed data. Before you trust that zero, make sure the identity running the audit has Storage Blob Data Reader on **every** account, and count the warnings: a zero without its denominator says nothing.

2. **With no explicit context, the audit runs against the current subscription, whichever that is.** None of the ten scripts accepts `-SubscriptionId` and none calls `Set-AzContext`: they query the subscription of the active context. The CSV contains neither TenantId nor SubscriptionId, so afterwards there is no way to tell which customer it refers to. Run `Get-AzContext` before you start, select the subscription with `Set-AzContext`, and pass `-OutputCsv` with the customer name in the path. Note too that the automatic `Connect-AzAccount` opens an interactive login: as they stand, these scripts cannot be scheduled.

3. **`04` reports "ASSENTE" (missing) even for a lifecycle policy that exists but cannot be read.** The `catch` turns any exception — including a 403/AuthorizationFailed on `Get-AzStorageAccountManagementPolicy` — into "no policy", and the storage account lands in the CSV with `Lifecycle = ASSENTE`. The cost report then recommends work on resources that are already compliant. Before acting on a row, check the policy in the portal, or run again with an identity that definitely has Reader on that resource group.

4. **Do not use the storage account key to run `02`.** The script's help and the old LEGGIMI offer it as an alternative for data-plane access, and the runtime message repeats the suggestion. The key grants full read **and write** access to all the data in the account: it is the broadest credential there is, handled in clear text, for a read-only check. Assign the Storage Blob Data Reader RBAC role to the identity running the audit instead, and leave the keys alone.

5. **`07` asks for more permissions than it uses.** Its `.NOTES` says "Reader/SQL Security Manager", but SQL Security Manager is a **write** role: it allows auditing, security policies, firewall rules and TDE settings to be changed. The script only runs `Get-AzSqlServerAudit` and `Get-AzSqlDatabaseTransparentDataEncryption`, both covered by Reader alone. Anyone following that note grants write permissions on the customer's SQL in order to produce a read-only report: ask for Reader and nothing else.

6. **A column of nothing but "n/d" in `08` is almost always an error, not a measurement.** The `catch` around `Get-AzMetric` is empty: any failure — missing Monitoring Reader, a metric not yet populated, an unsupported resource — produces `UsataGB = 'n/d'` with no message at all. If you see "n/d", check the Monitoring Reader role before concluding that the storage is empty; keep in mind that the `UsedCapacity` metric is refreshed roughly once a day, so a freshly created account may legitimately have no value yet.

## Where the output goes

All ten scripts export a CSV. The path is a parameter (`-OutputCsv`), but the default value is **relative to the current directory** and the file name contains only the date: `.\Az-StorageInventory-<date>.csv`, `.\Az-SqlSecurity-<date>.csv` and so on. Two consequences:

- **The file is created wherever the prompt is.** If you cloned the repository and run the scripts from there, the CSV ends up inside the clone. The root `.gitignore` excludes `*.csv`, but do not rely on that safety net: always pass `-OutputCsv` pointing at a folder you chose.
- **A second run on the same day overwrites the previous file, silently.** `Export-Csv` is called without `-NoClobber` and without `-Confirm`. If you want to keep a comparison, change the path on each run.

The content is not harmless: storage account names, logical SQL server names, firewall rules with the IP ranges allowed to reach the databases, TDE and auditing state, publicly open containers, backup retention. Taken together they are a map of the weak points of the customer's infrastructure. Treat them as confidential documents, do not leave them in a synced or network folder unless that is what you intend, and delete them once the assessment is closed.

An empty or missing CSV is not good news in itself: only `10` guards the export with a check on the results and says so on screen when it finds nothing. The other nine pipe the result straight into `Export-Csv`: with zero rows you get an empty file with no explanation, indistinguishable from a failed run.

## Examples

```powershell
# Authentication: once per session
Connect-AzAccount

# Storage account inventory
.\01-Get-AzStorageInventory.ps1

# SQL database inventory
.\05-Get-AzSqlDatabaseInventory.ps1

# Blob containers with anonymous access, CSV in a folder of your choice
.\02-Get-AzStorageContainerPublicAccess.ps1 -OutputCsv 'C:\Audit\production-subscription\public-containers.csv'
```

## Download and support

The same content is available as a ZIP from [synsphere.it/download/toolkit-powershell-azure-storage-db](https://synsphere.it/download/toolkit-powershell-azure-storage-db/). If you need a hand reading the results, or fixing what they bring to light, write to us at [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
