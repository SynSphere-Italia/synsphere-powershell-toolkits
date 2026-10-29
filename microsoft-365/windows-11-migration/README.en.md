# Windows 11 migration — PowerShell toolkit

Ten scripts to work out which PCs can move to Windows 11, in what order to move them, and what to put somewhere safe before you touch them.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

Windows 10 support ended on 14 October 2025, and anyone still running a mixed estate has to decide which machines get upgraded, which get replaced, and in what order. These scripts cover the whole cycle: hardware readiness for a single machine and for the whole fleet over WinRM, an inventory of the Windows 10 devices and of the installed applications, an export of the BitLocker recovery keys before you start, the in-place upgrade with blocking preconditions, and a post-upgrade check with the remaining rollback days.

They are written for in-house IT administrators and for MSPs who have to plan migration waves. Nine of the ten scripts are read-only; the one that changes the machine (09) asks for confirmation.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Test-Windows11Readiness.ps1` | Checks the local PC against the requirements that can be verified locally: TPM 2.0, Secure Boot, UEFI firmware, at least 4 GB of RAM, a system disk of at least 64 GB with enough free space, a 64-bit CPU with at least 2 cores and 1 GHz. Returns a PASS/FAIL verdict and the list of unmet requirements. | Read-only (no file) |
| `02-Get-Windows11ReadinessReport.ps1` | The same checks across a list of PCs over WinRM, with a summary CSV of eligible / not eligible and the missing requirements machine by machine. Takes `-ComputerName`, or a CSV with a `ComputerName` column. | Read-only (+ CSV) |
| `03-Get-TpmStatus.ps1` | Detailed TPM status: presence, version, enabled, activated, ready, manufacturer. It tells "no TPM" apart from "TPM present but disabled in firmware", where turning on PTT or fTPM is often all it takes. | Read-only (+ CSV) |
| `04-Test-SecureBootUEFI.ps1` | Secure Boot state, firmware mode (UEFI or legacy BIOS) and the partition style of the system disk. Says whether enabling Secure Boot is enough or whether the disk has to be converted from MBR to GPT. Diagnosis only: it does not run `mbr2gpt.exe`. | Read-only (+ CSV) |
| `05-Get-Windows10Inventory.ps1` | Inventory of the PCs, local or remote, with edition, version, build, install date and last boot time, flagging which ones are Windows 10. | Read-only (+ CSV) |
| `06-Get-UpgradeDiskSpace.ps1` | Total and free space on the system disk against a threshold (25 GB by default) and, with `-AnalyzeCleanup`, the DISM estimate of the space recoverable from the Windows component store. No cleanup is performed. | Read-only (no file) |
| `07-Export-BitLockerRecoveryKey.ps1` | Exports the key protector id and the numeric recovery password of the protected BitLocker volumes to a CSV. Do this before touching firmware, Secure Boot or the TPM, because a change in TPM state can make the machine ask for the key at boot. | Read-only (+ CSV **holding secrets**) |
| `08-Get-InstalledAppsInventory.ps1` | Snapshot of the installed software, read from the registry uninstall keys (64-bit, WOW6432Node and HKCU): name, version, publisher, date. Use it to compare what is still there before and after the upgrade. | Read-only (+ CSV) |
| `09-Invoke-Windows11Upgrade.ps1` | Starts the in-place upgrade from the `setup.exe` of Windows 11 media (mounted ISO, USB stick or folder), after blocking preconditions on Secure Boot/UEFI, RAM, free space and AC power; on request it suspends BitLocker for one reboot. Supports `-WhatIf`. | **WRITES**: upgrades the system and reboots the PC |
| `10-Test-Windows11PostUpgrade.ps1` | Post-upgrade check: whether the system really is Windows 11, version and build, whether `Windows.old` is present, and the days left in the rollback window (around 10). | Read-only (+ CSV) |

## Before you run them

- **PowerShell**: Windows PowerShell 5.1 or PowerShell 7. None of the ten scripts declares a `#Requires`, so nothing stops them running on a different version: checking is up to you.
- **Modules**: nothing to install. The scripts only use what ships with Windows — `CimCmdlets` (`Get-CimInstance`), `SecureBoot` (`Confirm-SecureBootUEFI`), `TrustedPlatformModule` (`Get-Tpm`), `Storage` (`Get-Disk`), `BitLocker` (`Get-BitLockerVolume`, `Suspend-BitLocker`), `Microsoft.PowerShell.Management` and `Microsoft.PowerShell.Utility` — plus `dism.exe`, which 06 calls. No `Install-Module` is needed.
- **No cloud permissions**: no script connects to Microsoft Graph, to Entra ID or to Azure. No app consent, Graph scope or directory role is required.
- **Local administrator on the machine**: needed for the TPM (03), for Secure Boot (01, 02, 04, 09), for BitLocker (07, 09), for `Get-Disk` (04), for reading `HKLM` (05, 08, 10) and for `setup.exe` (09). `#Requires -RunAsAdministrator` is missing too: without elevation the scripts do not refuse cleanly, they fail with obscure errors.
- **For the fleet reports (02 and 05)**: WinRM enabled on the targets (`Enable-PSRemoting`) and administrative rights on each target. The scripts have no `-Credential`: they use the identity of whoever runs them, so no credential is stored in the code. The remote payload is read-only, but collection is serial, one WinRM session per host: budget time for long lists.
- **For the upgrade (09)**: reachable Windows 11 media and the path to its `setup.exe`.
- **Starting system**: Windows 10, preferably 22H2, or Windows 11.

## ⚠️ Warnings

1. **Run non-interactively, 09 reboots the PC without warning anyone.** The script is marked `ConfirmImpact='High'` and does prompt you interactively, but the arguments handed to `setup.exe` include `/quiet`: launched from an RMM or from Intune with `-Confirm:$false` it shows no interface at all to the signed-in user, and the machine restarts while that person is working. Use a maintenance window, warn the user out of band, and run the same command with `-WhatIf` first — it verifies the preconditions without touching anything.

2. **07 writes the BitLocker recovery keys in clear text into the current directory.** The default for `-OutputCsv` is a relative path, so the file is created wherever the prompt happens to be: with a console opened as administrator, as the scripts prescribe, that directory is `C:\Windows\System32`. The CSV is not encrypted, gets no tightened ACL, is not deleted afterwards, and nothing asks you to confirm before it is written. Always pass `-OutputCsv` with a path of your own, on an encrypted or removable volume; delete the file as soon as you are done; and in a managed estate use the proper route, which is key escrow in Entra ID or in Active Directory (`BackupToAAD-BitLockerKeyProtector`, or `manage-bde -protectors -adbackup`).

3. **An "eligible" verdict is not the go-ahead for 09.** The blocking preconditions in 09 cover Secure Boot/UEFI, RAM, free space and power, but they do not check TPM 2.0 nor a system disk of at least 64 GB, which are two of the checks 01 does: the upgrade can therefore start on a machine that 01 marks as NOT eligible, and be refused or rolled back by `setup.exe` after the reboot. On top of that, neither 01 nor 02 compares the exact CPU model against Microsoft's compatibility list, so a PC that comes out eligible can still be rejected on the processor. Always run 01 (or 02) before 09 and, on borderline models, confirm with PC Health Check.

4. **`-SuspendBitLocker` suspends protection while waiting for a reboot that may never come.** The switch suspends BitLocker on every protected volume for one reboot. If the upgrade then does not start, is cancelled, or fails before the restart, the disk is left with protection off and nothing tells you so. After a `-WhatIf`, after a cancellation, and after a completed upgrade, check with `Get-BitLockerVolume` that `ProtectionStatus` is back to `On`; if it is not, run `Resume-BitLocker`.

5. **Two of the reports can come out incomplete without saying so.** In 05 the error object carries one property more than the success object (`Nota`, holding the reason for the failure) and `Export-Csv` takes its headers from the first object in the pipeline: if the first computer answers, the `Nota` column is never created and the cause of every failure disappears from the CSV, where only `Edizione = ERRORE` is left. In 08, one of the registry keys read is `HKCU`, which resolves to the hive of the account running the script: run as administrator, the inventory misses the per-user installations of the person who actually uses the workstation — exactly the class of application most easily lost in an upgrade. And in 02 as in 05, a machine that is unreachable, or where you lack rights, ends up among the ERRORE rows rather than among the "not eligible" ones: if WinRM is off or your rights fall short, the summary line (`Idonei 0/50`, `PC Windows 10 rilevati: 0/50`) is not telling you that no machine is eligible, it is telling you that none answered. Count the ERRORE rows before you use that total as a denominator.

6. **06 prints two destructive commands as a suggestion.** The script itself only runs the read-only analysis (`dism /Online /Cleanup-Image /AnalyzeComponentStore`), then prints `dism /Online /Cleanup-Image /StartComponentCleanup` and `cleanmgr /sagerun` on screen. The first permanently removes superseded components and makes already installed updates no longer uninstallable: it is not reversible, so decide before you run it. The second does not work as printed: `cleanmgr` wants an index, so run `cleanmgr /sageset:1` first to choose what to clean, then `cleanmgr /sagerun:1`.

## Where the output goes

Seven of the ten scripts export a CSV whose name contains only the date, in some cases together with the machine name: 02, 03, 04, 05, 07, 08 and 10. 01 and 06 write nothing. 09 writes its logs to `%ProgramData%\SynSphere\Win11Upgrade`, creating that folder on the machine.

Two consequences always hold:

- **The file is created wherever the prompt is.** The default for `-OutputCsv` is relative (`.\`), so the output lands in the current directory, whatever that is. If you cloned this repository and run the scripts from inside the clone, the CSVs are written into the clone: do not commit them. The `.gitignore` excludes `*.csv` and `*.log`, but do not rely on the `.gitignore` — check `git status` before you stage anything. The clean way is to always pass `-OutputCsv` with a path of your own.
- **A second run on the same day overwrites the first one, without asking.** The name holds the date, not the time, and `Export-Csv` overwrites. If you need the history, rename the file or pass a different `-OutputCsv`.

As for the content:

- The CSV from **07 holds security secrets**: the BitLocker recovery keys in clear text. Treat it like a password, not like a report.
- The other CSVs hold machine names, OS versions, per-workstation software inventories and install dates. The moment you correlate them with the employee the machine is assigned to, they become personal data: keep them for as long as the migration needs and no longer, limit who can read them, and delete them once the wave is closed.
- In 09 the value of `-LogDir` is passed to `setup.exe` inside an argument list without quoting: a path containing spaces is split in two and `/copylogs` receives a truncated value, which means the logs do not end up where you expect. Use a path without spaces.

## Examples

```powershell
# Readiness of a single machine
.\01-Test-Windows11Readiness.ps1

# Readiness across the whole fleet
.\02-Get-Windows11ReadinessReport.ps1 -ComputerName PC01,PC02,PC03

# BitLocker keys, before touching firmware, Secure Boot or the TPM
.\07-Export-BitLockerRecoveryKey.ps1

# In-place upgrade: the first run is always with -WhatIf
.\09-Invoke-Windows11Upgrade.ps1 -SetupPath D:\setup.exe -EulaAccept -WhatIf
```

## Download and support

The same content is available as a ZIP from [synsphere.it/download/toolkit-powershell-windows-11-migrazione](https://synsphere.it/download/toolkit-powershell-windows-11-migrazione/). If you want a hand with the estate assessment or with the migration itself, get in touch at [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
