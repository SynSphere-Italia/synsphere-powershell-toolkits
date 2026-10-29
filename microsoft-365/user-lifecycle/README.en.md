# Microsoft 365 — User management and lifecycle

Ten PowerShell scripts that tell you who really signs in to the tenant, who has no MFA, who holds admin roles and who stopped using the tenant — and that close an account when someone leaves.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

A collection for in-house IT administrators and for MSPs running Microsoft 365 tenants of small and medium businesses. Eight scripts export to CSV the inventory the admin console only shows one screen at a time: last sign-in, MFA status, password age, admin roles, managers, sign-in history. Two scripts write to the tenant: cleaning up inactive accounts, and offboarding someone who leaves the company.

All of them go through Microsoft Graph. Each script is self-contained — no shared files, no dependency between one script and the next — takes parameters, and states the Graph permissions it needs in its header.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-M365LastLogonReport.ps1` | For each user, the date of the last **interactive** sign-in and the days of inactivity, as a CSV sorted with the most dormant account first. Meant for finding dormant accounts. | Read-only |
| `02-Get-M365MfaStatusReport.ps1` | MFA status taken from the official Entra "authentication method registration details" report: registered, capable, methods configured. `-OnlyWithoutMfa` exports only users who are not registered. Replaces the old, deprecated MSOnline approach. | Read-only |
| `03-Get-M365RealLastLogonReport.ps1` | The "real" last sign-in: the most recent date between interactive and non-interactive. Keeps service and shared accounts, which only sign in non-interactively, from looking dormant. | Read-only |
| `04-Get-M365PasswordReport.ps1` | Date of the last password change, age in days, and passwords set never to expire (`DisablePasswordExpiration`). | Read-only |
| `05-Get-M365AdminReport.ps1` | Every directory role assignment, with the member type (user, group, service principal) and a count of Global Administrators. | Read-only |
| `06-Get-M365ManagerReport.ps1` | Each user's direct manager, with department and job title; flags users with no manager as `NESSUN MANAGER`. | Read-only |
| `07-Get-M365SignInHistory.ps1` | Sign-in events for the last N days (default 7): user, timestamp, application, IP address, city, country, client and outcome with error code. `-UserPrincipalName` narrows it to a single person. | Read-only |
| `08-Get-M365UserActivitySummary.ps1` | The same logs rolled up per user (default 30 days): total sign-ins, failed sign-ins, distinct applications, distinct IPs, last sign-in. Sorted by failed sign-ins. | Read-only |
| `09-Remove-M365InactiveUsers.ps1` | Selects accounts with no sign-in for more than N days (default 90) and, on request, **disables** or **deletes** them. | **WRITES** with `-Action Disable` or `-Action Delete`; the default `-Action Report` changes nothing, but still asks for a write scope |
| `10-Invoke-M365UserOffboarding.ps1` | Offboards a single UPN in eight steps: block sign-in, revoke sessions, reset the password to a random value, remove from all groups, remove all licences, convert the mailbox to Shared, hide from the address list (GAL), enable the auto-reply. | **WRITES** (Graph + Exchange Online) |

## Before you run them

**PowerShell.** The package targets PowerShell 5.1 and PowerShell 7, but none of the ten scripts declares a minimum version (`#Requires -Version`): on an older version you get no error up front — the script starts and breaks later.

**Modules.** Install the Graph meta-module, not the individual submodules:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser   # script 10 only
```

The `#Requires` line at the top of each script does not list every module it actually uses: `Microsoft.Graph.Reports` (02, 07, 08), `Microsoft.Graph.Identity.DirectoryManagement` (05), `Microsoft.Graph.Groups` (10), `Microsoft.Graph.Users` (01, 03, 04, 06) and `Microsoft.Graph.Users.Actions` (10, for `Set-MgUserLicense` and `Revoke-MgUserSignInSession`) are not declared. Install only the declared submodules and the script passes the `#Requires` check, then stops halfway with `CommandNotFoundException` — in the case of script 10, with the offboarding already under way.

**Graph permissions.** The script requests them itself on the first `Connect-MgGraph`; if your tenant requires admin consent, get them approved beforehand.

| Script | Scopes requested by the code |
| --- | --- |
| 01, 03 | `User.Read.All`, `AuditLog.Read.All` |
| 02 | `AuditLog.Read.All`, `UserAuthenticationMethod.Read.All` |
| 04 | `User.Read.All` |
| 05 | `RoleManagement.Read.Directory`, `Directory.Read.All` |
| 06 | `User.Read.All`, `Directory.Read.All` |
| 07, 08 | `AuditLog.Read.All` |
| 09 | `User.ReadWrite.All`, `AuditLog.Read.All` |
| 10 | `User.ReadWrite.All`, `Group.ReadWrite.All`, `Directory.ReadWrite.All`, `Organization.Read.All`, plus `Connect-ExchangeOnline` |

**Roles.** For 01-08 a read-only role is enough (Global Reader or Security Reader). Script 09 requires User Administrator. Script 10 requires User Administrator and, for steps 6-8, an Exchange role that allows `Set-Mailbox` and `Set-MailboxAutoReplyConfiguration` (Exchange Administrator).

**Entra ID licence.** `signInActivity` (01, 03, 09) and the sign-in logs (07, 08) require Microsoft Entra ID P1 or P2: they do not exist in the Free plan. See the first and fifth warning.

## ⚠️ Warnings

1. **Script 09 treats "no data" as "inactive account": with `-Action Delete` it can select every user in the tenant.** The filter is `($null -eq $real) -or ($real -lt $cutoff)`, and `$real` is `$null` not only when the user has never signed in, but whenever `signInActivity` is unavailable: a tenant without Entra ID P1/P2, an administrator without `AuditLog.Read.All`, newly created accounts, service or resource accounts. In those cases every user comes out as inactive and `Remove-MgUser` deletes them one after another. Always run `-Action Report` first and check the `RealLastSignIn` column: if it reads `Mai` for everyone, the data is missing and the selection means nothing.

2. **Without `-WhatIf`, scripts 09 and 10 ask for no confirmation at all.** They declare `SupportsShouldProcess` but not `ConfirmImpact`: the default value stays below PowerShell's confirmation threshold, so `ShouldProcess` returns true without ever prompting. `.\09-Remove-M365InactiveUsers.ps1 -Action Delete` silently deletes every account it selected. `-WhatIf` exists and works, but it is opt-in: use it on the first run, and add `-Confirm` when you act for real.

3. **Script 09 excludes neither administrators nor break-glass accounts.** The loop walks every user without filtering by role, group or UPN to preserve. Emergency-access accounts are by design never used: they are therefore the first to show up as "inactive" and the first to be disabled or deleted — the very accounts you need to get back into the tenant when something goes wrong. Read the report CSV line by line before acting, and keep the list of break-glass accounts to hand.

4. **Step 4 of script 10 removes the user from every group, including groups that assign licences or grant access to resources**, and step 5 then removes all remaining licences. Neither undoes with a single command: memberships have to be rebuilt by hand. The script works on one UPN per run (the parameter is mandatory), so it is not a bulk operation, but it is irreversible. Mind the scope of the switches, too: the description mentions `-Skip*` switches in the plural, but the only one defined is `-SkipMailbox`, which skips steps 6-8 on Exchange Online. There is no `-SkipPassword`, `-SkipGroups` or `-SkipLicenses`: steps 1 to 5 cannot be skipped.

5. **A report can come back empty, or negative across the board, because of a missing licence or missing permissions — and look like good news.** Without Entra ID P1/P2, or without `AuditLog.Read.All`, 01 and 03 write `Mai` and `N/D` for everyone and 07 and 08 return no events at all. An empty column across the whole population does not mean "no recent sign-ins", it means "no data". Before you conclude anything, compare the number of exported rows with the number of users in the tenant: a numerator without its denominator misleads.

6. **Script 09 asks for a write scope even when it only reads, and script 10 asks for a broader one than it needs.** `Connect-MgGraph -Scopes 'User.ReadWrite.All', …` runs every time, including under the default `-Action Report`: to get a plain listing you have to grant write access to the entire user directory. Script 10 requests `Directory.ReadWrite.All`, one of the broadest write scopes in Graph, which none of its eight steps uses (`User.ReadWrite.All`, `GroupMember.ReadWrite.All` and `Organization.Read.All` would be enough). If an administrator has to approve the consent, consider narrowing the scopes in the code before you ask.

## Where the output goes

The nine reporting scripts export a CSV to the **current directory** (`10`, which performs the offboarding, writes no file: it prints each step to the console), with a filename that carries only the date: `M365-LastLogon-20261029.csv`, `M365-MfaStatus-20261029.csv`, and so on. Two consequences worth keeping in mind:

- **The file lands where the prompt is, not where the script is.** If you cloned the repository and run from inside the clone, the CSV ends up in the clone. Do not commit it: the root `.gitignore` excludes `*.csv`, but do not rely on the filter — check `git status` before you stage anything.
- **A second run on the same day overwrites the first one, without asking.** The filename carries the date and not the time, and `Export-Csv` writes without `-NoClobber`. If you need the history, pass `-OutputCsv` with a name of your own.

The contents are not just a list of names: 07 exports the IP address, city and country of every sign-in and 08 counts distinct IPs per user; 02 names the people who have no MFA; 05 lists the administrators and their roles; 04 says whose passwords never expire. This is personal data and, read together, a map of what to attack in that tenant: keep it out of the repository and out of shared folders, and delete it when the analysis is over.

## Examples

```powershell
# Who has no MFA registered
.\02-Get-M365MfaStatusReport.ps1 -OnlyWithoutMfa

# One person's sign-ins over the last 30 days
.\07-Get-M365SignInHistory.ps1 -UserPrincipalName mario.rossi@azienda.it -Days 30

# Accounts idle for more than 120 days: report only, no changes
.\09-Remove-M365InactiveUsers.ps1 -InactiveDays 120

# The same selection as a dry run, before actually disabling it
.\09-Remove-M365InactiveUsers.ps1 -InactiveDays 120 -Action Disable -WhatIf

# Offboarding as a dry run: prints the eight steps without performing them
.\10-Invoke-M365UserOffboarding.ps1 -UserPrincipalName mario.rossi@azienda.it -WhatIf
```

## Download and support

The same content is available as a ZIP archive from [synsphere.it/download/toolkit-powershell-utenti-microsoft-365](https://synsphere.it/download/toolkit-powershell-utenti-microsoft-365/). If you need help: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
