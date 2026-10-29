# Azure Security & Compliance Toolkit

Ten read-only reports that capture the security posture of an Azure subscription and export it to CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

This collection is aimed at IT administrators, managed service providers and security teams who need to produce an assessment of an Azure subscription quickly, or evidence to attach to a compliance effort (GDPR, ISO 27001). Each script inspects a different area — Defender for Cloud, NSG rules, public IPs, storage accounts, Key Vaults, VM disks, Azure Policy, diagnostics — and writes the result to a CSV, with nothing to install beyond the Az module.

None of the ten scripts modifies the tenant: the code audit found no write cmdlet at all, only `Get-*` calls and the CSV export. So this is material you can run on a customer tenant without fear of changing something by accident — the risk, as the warnings section explains, is misreading the result, not damaging the environment.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-AzSecureScore.ps1` | Microsoft Defender for Cloud Secure Score: the overall score and each individual control, with current value, maximum and percentage. | Read-only |
| `02-Get-AzSecurityRecommendations.ps1` | Defender for Cloud assessments that are not healthy: the hardening to-do list, with severity and the affected resource. | Read-only |
| `03-Get-AzNsgOpenPorts.ps1` | Inbound NSG rules that accept traffic from any source (`*`, `0.0.0.0/0`, `Internet`), with ports and priority. Flags management and database ports (22, 3389, 1433, 3306, 5432, 445) and full ranges as HIGH risk. | Read-only |
| `04-Get-AzPublicExposure.ps1` | Every public IP in the subscription, with SKU, allocation method and the resource it is attached to (or "not attached"). | Read-only |
| `05-Get-AzStoragePublicAccess.ps1` | Storage accounts that allow public blob access, do not enforce HTTPS, or leave public network access open. Only accounts with at least one finding reach the CSV. | Read-only |
| `06-Get-AzKeyVaultSecurity.ps1` | Key Vaults: soft delete, purge protection, authorization model (RBAC or access policy) and public network access. | Read-only |
| `07-Get-AzVmDiskEncryption.ps1` | Encryption status of the OS disk and data disks of every VM (Azure Disk Encryption), with a count of VMs whose OS disk is unencrypted. | Read-only |
| `08-Get-AzPolicyCompliance.ps1` | Resources in NonCompliant state against Azure Policy, with the definition and the assignment they violate. | Read-only |
| `09-Get-AzResourcesWithoutDiagnostics.ps1` | Resources with no diagnostic setting at all, that is, the gaps in your logging. `-ResourceTypeLike` narrows the scan to one resource type. | Read-only |
| `10-Get-AzKeyVaultExpiringSecrets.ps1` | Key Vault secrets and certificates expiring within N days (`-Days`, default 30). It exports their names, not their values. | Read-only |

## Before you run them

**PowerShell 5.1 or PowerShell 7.** That is the requirement stated with the collection: none of the ten scripts declares a minimum version through `#Requires -Version`, so on an older host nothing will stop you by itself.

**The Az module.** The simplest route is the umbrella module:

```powershell
Install-Module Az -Scope CurrentUser
```

Alternatively, only the modules actually used:

```powershell
Install-Module Az.Accounts, Az.Security, Az.Network, Az.Storage, Az.KeyVault, Az.Compute, Az.PolicyInsights, Az.Monitor, Az.Resources -Scope CurrentUser
```

Which script needs what: `Az.Accounts` all ten; `Az.Security` 01 and 02; `Az.Network` 03 and 04; `Az.Storage` 05; `Az.KeyVault` 06 and 10; `Az.Compute` 07; `Az.PolicyInsights` 08; `Az.Monitor` and `Az.Resources` 09. No `#Requires` pins a minimum module version.

**Authentication.** `Connect-AzAccount`, interactive. There is no other form of authentication in the code: no app registration, no stored credential.

**Permissions.**

- **Reader** role on the subscription: 03, 04, 05, 06 (control plane), 07, 08, 09.
- **Security Reader** and Defender for Cloud enabled on the subscription: 01 and 02. Without Defender for Cloud enabled those two reports have no data to read.
- **Data-plane** permissions on the Key Vaults for 10: a read access policy on secrets and certificates, or the Key Vault Reader / Key Vault Secrets User role. The control-plane Reader role is not enough.
- No script requires Microsoft Graph permissions: the collection uses the Az modules only.

## ⚠️ Warnings

1. **A result of zero does not prove compliance (09).** The script calls `Get-AzDiagnosticSetting` one resource at a time and the `catch` block discards the error without counting it: a resource type that does not support diagnostics, an access denied for missing permissions, and an ARM 429 rate-limit response all end up in the same silence. The closing message therefore prints a numerator with no denominator, and "0 resources without diagnostics" may mean your logging is in order, or that you lack the permission to see it. Always narrow the scope with `-ResourceTypeLike`, compare the row count in the CSV with the number of resources you expected, and read the result as a floor, not a total. The throttling risk is highest with the default `-ResourceTypeLike '*'`, which queries every resource in the subscription.

2. **The scope is whichever subscription is already selected, and the report never says which.** None of the ten scripts takes a `-SubscriptionId` parameter and none calls `Set-AzContext`: the line `if (-not (Get-AzContext)) { Connect-AzAccount }` prompts for credentials only when no context exists, and otherwise silently reuses the open one. On a tenant with several subscriptions — or for a provider working on several customers in the same session — the audit runs against whatever subscription happens to be current, and the CSV keeps nothing that would let you tell afterwards: a partial result reads like a clean one, and a report can end up attributed to the wrong customer. Run `Get-AzContext` before every launch, and pass `-OutputCsv` with the subscription name in the file name.

3. **The CSVs are sensitive material and they land in the current directory.** Taken together these reports are an attack map: 03 lists inbound rules open to the Internet with ports and priorities, 04 the real public IP addresses and the resource behind each one, 05 the storage accounts with public blobs or plain HTTP allowed, 10 the names of secrets and certificates with their expiry dates. The default for `-OutputCsv` is a relative path, so if you run the scripts inside the cloned repository or in a synced folder, those files get committed or uploaded to the cloud. Write them elsewhere with `-OutputCsv` and treat them as the vulnerability inventory they are. One doubt worth settling: 10 calls `Get-AzKeyVaultSecret` without `-Name`, so it reads metadata only — the CSV contains the names of the secrets, never their values.

4. **Seven of the ten scripts stop at the first error, and then write no CSV at all.** 01, 02, 03, 04, 05, 06 and 08 set `$ErrorActionPreference = 'Stop'` with no `try/catch`, and `Export-Csv` is their last statement: if a single resource is inaccessible, the exception ends the run before the write and everything collected so far is lost, without even a partial file. Run them one at a time, and re-run the one that stopped once you have fixed the missing permission. 07, 09 and 10 do handle the error and reach the end.

5. **Script 07 asks for more permission than it uses.** The `.NOTES` of `07-Get-AzVmDiskEncryption.ps1` say "Reader/VM Contributor role", but the script only calls `Get-AzVM` and `Get-AzVMDiskEncryptionStatus`: **Reader is sufficient**. Virtual Machine Contributor is a write role that creates, restarts and deletes VMs and disks, and granting it to yourself or to a service principal just to produce a report opens a destructive permission that will never be used. Assign Reader only. If the `OSCifrato` column shows `n/d`, that is a limitation of the cmdlet or of the ADE extension on that VM, not a missing write permission.

6. **`-Days` accepts values that invert the window without warning (10).** The parameter is declared `[int]$Days = 30` with no validation attribute. With `-Days -30` the computed cut-off falls in the past and the report lists only what expired more than a month ago, while the closing message still says "expiring within -30 days"; with `-Days 0` the window closes on today. Always pass a positive integer. This holds generally: none of the ten scripts validates its parameters beyond their type.

## Where the output goes

All ten scripts export a CSV through `-OutputCsv`, whose default value is a path **relative** to the current directory and carries only the date: `.\Az-SecureScore-20261029.csv`, `.\Az-NsgOpenPorts-20261029.csv` and so on. Two consequences to keep in mind every time:

- **The file is created where the prompt is, not where the script is.** If you cloned this repository and launch from there, the CSV lands inside the clone. The `.gitignore` in the root excludes `*.csv`, but do not rely on it: check `git status` before you commit. The same applies to folders synced to OneDrive, SharePoint or Dropbox, where no `.gitignore` protects you at all.
- **A second run on the same day overwrites the first, without asking.** The file name carries the date but not the time. If you need to compare a before and an after, pass `-OutputCsv` with two different names.

Protect the contents as you would a confidential document: firewall rules open to the Internet, public IP addresses with the resource behind each one, exposed storage accounts, Key Vault security settings, names of secrets and certificates with their expiry dates. This is exactly the information an attacker would use to decide where to start.

## Examples

```powershell
# Sign in once, then run the reports you need
Connect-AzAccount
.\01-Get-AzSecureScore.ps1
.\03-Get-AzNsgOpenPorts.ps1

# Narrow the diagnostics scan to a single resource type
.\09-Get-AzResourcesWithoutDiagnostics.ps1 -ResourceTypeLike '*Microsoft.KeyVault*'

# Use a 60-day expiry window
.\10-Get-AzKeyVaultExpiringSecrets.ps1 -Days 60

# Write the CSV outside the cloned repository and outside any synced folder
.\04-Get-AzPublicExposure.ps1 -OutputCsv 'C:\Audit\prod-sub-public-ips.csv'
```

## More

The same content is available as a ZIP from [synsphere.it/download/toolkit-powershell-azure-security/](https://synsphere.it/download/toolkit-powershell-azure-security/). The walkthrough article for the collection is at [synsphere.it/notizie/script-powershell-azure-security-toolkit-pmi](https://synsphere.it/notizie/script-powershell-azure-security-toolkit-pmi) (in Italian).

If you need help reading the reports, or fixing what they found: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
