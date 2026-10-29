# Azure Compute & VM Toolkit

Ten PowerShell scripts that take stock of an Azure virtual machine estate from the command line: VM and disk inventory, VMs without backup, orphaned disks, patch status, plus one bulk start/stop command.

[Versione italiana](README.md) · [← All the toolkits](../../README.en.md)

## What it's for

The collection is aimed at in-house IT administrators and at MSPs who run Azure subscriptions on behalf of small and medium businesses. Nine scripts read the current subscription and write a CSV; the tenth starts or deallocates VMs in bulk.

They answer the questions that take many clicks in the portal and still give no overview: which VMs are powered off but still allocated (and therefore still billed), which have no backup, which disks are still on the invoice without serving any VM, which VMs are on manual patching.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-AzVmInventory.ps1` | VM inventory: name, resource group, region, SKU, operating system and power state. A base for capacity planning. | Read-only |
| `02-Get-AzVmRightsizing.ps1` | Extracts the Azure Advisor cost recommendations on VMs: which ones to resize or shut down, with the problem and the proposed solution. | Read-only |
| `03-Get-AzVmPowerState.ps1` | The VMs that are not running, telling "stopped" ones (powered off but still allocated: compute is still billed) from "deallocated" ones (only the disks are billed). | Read-only |
| `04-Get-AzVmsWithoutBackup.ps1` | Compares every VM against the ones protected by the Recovery Services vaults and lists those with no backup. | Read-only |
| `05-Get-AzDiskInventory.ps1` | Managed disk inventory: size, SKU, state, encryption type and attached VM. | Read-only |
| `06-Get-AzUnattachedDisks.ps1` | The disks that are attached to no VM, with size, SKU and creation date, plus the total GB still being billed. | Read-only |
| `07-Get-AzVmExtensions.ps1` | The extensions installed on each VM, with publisher, type and version. Note: a VM whose extensions cannot be read is reported as `(nessuna)`, which is indistinguishable from a VM that genuinely has none. | Read-only |
| `08-Get-AzVmsWithoutAutoShutdown.ps1` | The VMs with no automatic shutdown schedule (see warning 6 on what the check actually covers). | Read-only |
| `09-Set-AzVmStartStop.ps1` | Starts or stops (deallocates) in bulk the VMs of a resource group or those carrying a given tag. | **WRITES** |
| `10-Get-AzVmPatchStatus.ps1` | The patch management mode of each VM (AutomaticByPlatform, AutomaticByOS, Manual/ImageDefault) and, on Windows, automatic updates. | Read-only |

## Before you run them

**PowerShell.** PowerShell 5.1 or PowerShell 7. No script enforces a minimum version in code: checking it is up to whoever runs them.

**Modules.** The Az meta-module covers everything:

```powershell
Install-Module Az -Scope CurrentUser
```

If you would rather install only the modules actually used:

```powershell
Install-Module Az.Accounts, Az.Compute, Az.Advisor, Az.RecoveryServices, Az.Resources -Scope CurrentUser
```

`Az.Accounts` is needed by all ten; `Az.Compute` by all but 02; `Az.Advisor` only by 02; `Az.RecoveryServices` only by 04; `Az.Resources` only by 08.

**Authentication.** `Connect-AzAccount`. Each script opens the sign-in window only if it finds no context already active in the session.

**Permissions.**

- **Reader** at subscription scope for the nine reports: that is sufficient, and minimal, for the cmdlets they call.
- **Backup Reader** on top of Reader for 04, which reads the Recovery Services vaults.
- For 09, three actions are enough: `Microsoft.Compute/virtualMachines/read`, `/start/action`, `/deallocate/action`. A custom role holding just those three is the recommended route. The built-in **Virtual Machine Contributor** role works, but it is broader: it also grants deletion of the VMs and management of their disks and NICs.

## ⚠️ Warnings

1. **Without `-ResourceGroupName`, `09-Set-AzVmStartStop.ps1` acts on EVERY VM in the current subscription, and by default it asks for no confirmation.** Only `-Action` is mandatory: scoping is optional. The script declares `SupportsShouldProcess` but does not raise `ConfirmImpact`, so no prompt appears unless you pass `-Confirm` explicitly; on top of that `Stop-AzVM` is called with `-Force`, which suppresses its own native confirmation. Stop means deallocate, so no data is destroyed, but service is interrupted on every selected VM. Always run it with `-WhatIf` first, and add `-Confirm` when you want a prompt per VM.

2. **`-TagName` without `-TagValue` selects the VMs that do NOT carry that tag: the opposite of the intent, with no warning at all.** The filter engages on the mere presence of `-TagName` and compares the tag value against `$TagValue`, which is `$null` when it has not been passed. Combined with point 1, the scope becomes "every VM in the subscription that lacks that tag". Always pass the two parameters together.

3. **No script pins the subscription: they all work on whichever one is current in the session.** None of the ten contains `Set-AzContext`, `Select-AzSubscription` or a `-SubscriptionId` parameter. On a tenant with several subscriptions the reports are silently partial, and for 09 the target depends on session state that is nowhere visible in the command you typed. Check `Get-AzContext` before every run, and before 09 in particular.

4. **04 matches VMs by NAME, not by resource ID, so two VMs with the same name in different resource groups mask each other.** If `vm-sql01` in resource group A is backed up, the `vm-sql01` in resource group B is reported as protected although it is not, and never appears in the report. This is the dangerous direction of the error, because a VM genuinely without backup goes unreported. If your estate reuses names, check those VMs by hand.

5. **Still in 04, if reading a vault fails the error is invisible and EVERY VM comes out as `Backup = 'ASSENTE'`.** The exception from `Get-AzRecoveryServicesBackupItem` lands in an empty catch: if the Backup Reader permission is missing, if the vaults live in another subscription, or if the call gets throttled, the set of protected VMs stays empty, the script exits without an error and the CSV declares the whole estate unprotected. A report in which *all* VMs come out uncovered should be read as a likely permission problem, not as a result: the number of VMs without backup means nothing without the number of vaults that were actually read. Verify at least one of them in the portal before taking the CSV at face value.

6. **08 only recognises the native DevTestLab auto-shutdown.** It looks for `Microsoft.DevTestLab/schedules` resources named `shutdown-computevm-<vm>`: a scheduled shutdown built with an Automation Account, with Azure Policy or with *start/stop VMs during off-hours* is not seen, and those VMs show up as `AutoShutdown ASSENTE` even though they are managed. Here too the comparison is by name, so VMs with the same name in different resource groups mask each other.

## Where the output goes

The nine reports accept `-OutputCsv`, whose default is a path **relative to the current directory**, for example `.\Az-VmInventory-20261029.csv`. Two consequences worth keeping in mind:

- **The file is created wherever the prompt is**, not next to the script. If you have cloned this repository and run the scripts from here, the CSV ends up inside the clone. The `.gitignore` in the root excludes `*.csv`, but do not rely on the automation: check `git status` before you commit, and move the reports out of the clone when you are working on a customer tenant.
- **The name carries only the date**, not the time: a second run on the same day overwrites the previous CSV without asking. No script checks whether the file already exists. If you want to keep both versions, pass your own name to `-OutputCsv`.

The CSV files in this collection contain no personal data: they hold resource names, sizes, SKUs and states. They do, however, map the weak points of the estate — which VMs have no backup (04), which have no scheduled shutdown (08), which are on manual patching (10) — so treat them as confidential infrastructure documentation and keep them off open shares.

## Examples

```powershell
# Sign in (once per session) and check which subscription is active
Connect-AzAccount
Get-AzContext

# Full VM inventory
.\01-Get-AzVmInventory.ps1

# VMs not protected by backup
.\04-Get-AzVmsWithoutBackup.ps1

# Bulk shutdown of a resource group: simulate it first
.\09-Set-AzVmStartStop.ps1 -Action Stop -ResourceGroupName rg-devtest -WhatIf

# Start the VMs tagged Environment=Dev (always pass both parameters)
.\09-Set-AzVmStartStop.ps1 -Action Start -TagName Environment -TagValue Dev
```

## Download and support

The same content is available as a ZIP from [synsphere.it/download/toolkit-powershell-azure-compute/](https://synsphere.it/download/toolkit-powershell-azure-compute/).

If you need help using these scripts or running Azure VMs: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
