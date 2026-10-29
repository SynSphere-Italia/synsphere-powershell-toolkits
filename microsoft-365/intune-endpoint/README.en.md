# Intune / Endpoint Management Toolkit

Ten PowerShell scripts that take a snapshot of an endpoint estate managed with Microsoft Intune — inventory, compliance, policies, apps, Autopilot, Windows versions — and export the result to CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

The scripts query Intune through Microsoft Graph and return the state of the managed estate in tabular form: enrolled devices, compliance and the reasons for non-compliance, policies and profiles with their assignments, published apps, machines that have stopped checking in, and the split between Windows 10 and Windows 11. They are aimed at IT administrators and at MSPs running Intune tenants for small and medium businesses, who need a figure covering the whole estate without piecing it together by hand in the console, or a dated file to attach as evidence in a compliance audit. Nine of the ten scripts are read-only; only one acts on the tenant.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-IntuneDeviceInventory.ps1` | Full inventory of enrolled devices: operating system and version, compliance state, ownership (corporate or personal), manufacturer, model, serial number, assigned user and last check-in date. The baseline snapshot of the estate. | Read-only |
| `02-Get-IntuneComplianceOverview.ps1` | Counts managed devices by compliance state and by operating system and works out the percentage of compliant devices. Totals on screen, per-OS detail in the CSV. Exports no identities. | Read-only |
| `03-Get-IntuneNonCompliantDevices.ps1` | Lists devices whose state is not "compliant" (non-compliant, in error, pending evaluation, in grace period) with OS, version, user, ownership and last check-in. | Read-only |
| `04-Export-IntuneCompliancePolicies.ps1` | Every device compliance policy with its target platform, last modified date and the number of groups it is assigned to: shows whether a platform is uncovered, or a policy exists but is assigned to nobody. | Read-only |
| `05-Export-IntuneConfigurationProfiles.ps1` | Device configuration profiles (settings, restrictions, VPN, Wi-Fi, certificates) with type, last modified date and number of assignments. | Read-only |
| `06-Get-IntuneAppInventory.ps1` | Apps published in Intune (Win32, Microsoft Store, LOB, web links) with publisher, type and number of assignments; apps with zero assignments are the ones published and never deployed. | Read-only |
| `07-Get-IntuneStaleDevices.ps1` | Devices that have not synced for longer than the given threshold (`-DaysInactive`, default 30), with the number of days inactive. It lists cleanup candidates: it removes nothing. | Read-only |
| `08-Get-IntuneAutopilotDevices.ps1` | Devices registered for Windows Autopilot with serial number, manufacturer, model, group tag, enrollment state and deployment profile assignment status. | Read-only |
| `09-Get-IntuneWindowsVersionReport.ps1` | Infers from the build whether a Windows PC is Windows 10 or Windows 11 (build 22000 or higher = Windows 11) and produces both an on-screen summary and a per-device CSV; an unparseable version lands in "Windows (n/d)". | Read-only |
| `10-Invoke-IntuneDeviceSync.ps1` | Sends the sync command to the devices whose name matches the `-DeviceNameLike` filter, so policies, profiles and apps apply immediately instead of waiting for the automatic cycle. Supports `-WhatIf`. | **WRITES** (acts on the tenant) |

## Before you run them

**PowerShell.** The prerequisite stated for this collection is PowerShell 5.1 (the one preinstalled on Windows) or PowerShell 7. None of the ten scripts declares a minimum version with `#Requires -Version`.

**Modules.** You need the full Microsoft Graph PowerShell SDK:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

The meta-module is required, not merely convenient. At the top of each script, `#Requires -Modules Microsoft.Graph.Authentication` declares only the module that provides `Connect-MgGraph`, while the cmdlets that read the data live elsewhere: `Microsoft.Graph.DeviceManagement` (01-05, 07, 09, 10), `Microsoft.Graph.Devices.CorporateManagement` (06), `Microsoft.Graph.DeviceManagement.Enrollment` (08).

**Permissions.** An account with the Intune Administrator role or equivalent Graph permissions. All scopes are delegated and interactive: consent is requested at the first `Connect-MgGraph`, there is no app-only authentication, no certificate and no secret in the code. Each script asks only for the scope it uses.

| Graph scope | Scripts |
| --- | --- |
| `DeviceManagementManagedDevices.Read.All` | 01, 02, 03, 07, 09 |
| `DeviceManagementConfiguration.Read.All` | 04, 05 |
| `DeviceManagementApps.Read.All` | 06 |
| `DeviceManagementServiceConfig.Read.All` | 08 |
| `DeviceManagementManagedDevices.PrivilegedOperations.All` + `DeviceManagementManagedDevices.Read.All` | 10 |

**Two notes on the in-file documentation.** `Get-Help` on these scripts does not show the description, only the auto-generated syntax: the help is there, at the top of the file, and you read it by opening the `.ps1`. And the `.NOTES` block of script 10 places the `Sync-MgDeviceManagementManagedDevice` cmdlet in a module called `Microsoft.Graph.DeviceManagement.Actions`: that module does not exist in version 2 of the SDK, where the cmdlet is exported by `Microsoft.Graph.DeviceManagement`. Do not try to install it.

## ⚠️ Warnings

1. **Script 10 accepts `-DeviceNameLike '*'`, which selects every device in the tenant.** It normally asks for confirmation device by device, because it declares `ConfirmImpact = 'High'`, but `-Confirm:$false` turns the prompt off: the two together send the check-in to the entire fleet without a single interaction. The operation itself is benign — it is a sync, not a wipe — but it is still a command issued to the whole estate. Run it with `-WhatIf` first, which lists the selected devices without sending anything, and keep the filter as narrow as possible.

2. **The CSVs contain personal data about employees.** The exports include `UserPrincipalName`, device name and assigned user (01, 03, 07, 09) and the machine serial number (01, 08). That is personal data in the full sense, and the default path is relative: the file is created wherever you run the command. Treat it accordingly — limited retention, no sharing beyond what is necessary — and if all you need is an aggregate count, use 02, which exports no identities.

3. **`-DaysInactive` accepts a negative value and script 07 does not reject it.** With `-DaysInactive -30` the cutoff moves into the future and the condition becomes true for every device: the report lists the entire fleet as inactive, and the list looks perfectly legitimate. The script is read-only, so the harm is not to the tenant but to the decision you make from reading it. Always pass a positive number of days, and compare the count against the size of the estate before acting on that list.

4. **No script handles errors: there is neither `try/catch` nor retry.** `$ErrorActionPreference` is set to `Stop` in all ten and none of them catches the exception: any Graph error — throttling on a large tenant, denied consent, an expired token, a missing module — stops execution with a raw stack trace. Since the export happens at the very end, in that case you get no CSV at all: the missing file is the only signal. The device-based scripts also enumerate the whole tenant and filter client-side. If it happens, run the script again.

5. **An empty report, or a total lower than expected, is not good news: it is a number that needs explaining.** The scripts show whatever Graph returns to the account you signed in with, and they do not verify that the result is complete. If 03 prints "Trovati 0 dispositivi non conformi", or if the total from 02 is below the estate you know, compare that total with the headcount you expect before concluding that your posture is sound: a compliance percentage computed over a subset is the wrong percentage.

6. **The `#Requires` at the top of each script gives a green light that is not enough.** It declares only `Microsoft.Graph.Authentication`: install that module on its own and you clear the check, authenticate successfully, and then stop at the first `Get-Mg*` call with a command-not-recognised error that looks like a permissions problem and is not. Install the full `Microsoft.Graph` meta-module.

## Where the output goes

The nine read-only scripts export a CSV; the `-OutputCsv` parameter defaults to a relative path of the form `.\Intune-<content>-<yyyymmdd>.csv`. Script 10 writes no file.

Two consequences, always worth knowing:

- **The file is created where the prompt is, not where the script is.** The default path is relative to the current directory: if you have cloned the repository and run the scripts from there, the CSV ends up inside the clone. The root `.gitignore` excludes `*.csv`, but do not rely on the filter: check with `git status` before committing, or pass `-OutputCsv` with a path outside the repository.
- **A second run on the same day overwrites the first one, without asking.** The default name contains only the date, not the time. If you need the history — and you do when the CSVs are evidence to keep — pass `-OutputCsv` with a name of your own, or move the file before running again.

## Examples

```powershell
# Full inventory of managed devices
.\01-Get-IntuneDeviceInventory.ps1

# Compliance percentage, counts by state and per-OS detail
.\02-Get-IntuneComplianceOverview.ps1

# Devices that have not synced for more than 60 days
.\07-Get-IntuneStaleDevices.ps1 -DaysInactive 60

# Dry run of the sync: lists the selected devices, sends nothing
.\10-Invoke-IntuneDeviceSync.ps1 -DeviceNameLike 'NB-*' -WhatIf
```

## More

The same content is available as a ZIP archive from the toolkit page on our site: [synsphere.it/download/toolkit-powershell-intune-endpoint](https://synsphere.it/download/toolkit-powershell-intune-endpoint/).

If you would rather have endpoint management as a managed service, or if a script does not behave as described here: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
