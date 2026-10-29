# Identity governance in Microsoft Entra ID

Ten read-only scripts that answer three questions with a CSV in hand: who holds administrative power, which applications have access to the tenant, and where identity governance has gaps.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

These scripts are written for whoever administers a small or medium business tenant in Microsoft 365 / Entra ID, and for the MSPs who have to produce periodic identity audit evidence — for an internal review or for the security obligations the company is subject to — without buying a dedicated tool. Each one photographs a piece of the configuration through the Microsoft Graph PowerShell SDK and exports a dated CSV; none of them changes the tenant.

They run individually and in any order: there is no mandatory sequence, `01` is simply the most common place to start.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-EntraPrivilegedRoleMembers.ps1` | Lists every directory role activated in the tenant (Global Administrator and the rest) with its members, be they users, groups or service principals. It shows active, permanent assignments, not PIM-eligible roles. | Read-only |
| `02-Get-EntraPimEligibleRoles.ps1` | Lists eligible role assignments in Entra PIM: who **can** activate a privileged role without holding it permanently, with status, assignment type and validity window. It completes `01`. | Read-only |
| `03-Get-EntraAppRegistrations.ps1` | Inventory of app registrations with appId, creation date, audience, publisher domain and owner count: it maps the integrations and surfaces the apps with no owner. | Read-only |
| `04-Get-EntraExpiringAppCredentials.ps1` | Reports the client secrets and certificates of app registrations expiring within N days, including those already expired (negative days). It covers app registrations, not service principals. | Read-only |
| `05-Get-EntraEnterpriseApps.ps1` | Inventory of service principals (enterprise applications) with type, enabled state, whether they require explicit user assignment, and how many credentials they hold between secrets and certificates. | Read-only |
| `06-Get-EntraGuestAccounts.ps1` | Lists the B2B external collaboration guest accounts with email, creation date and last sign-in, so you can review who still comes in from outside and find the inactive guests. | Read-only |
| `07-Get-EntraGroupsWithoutOwners.ps1` | Lists the Microsoft 365 and security groups that have no owner assigned, classified by type. It excludes groups synchronised from on-premises, whose owners are not managed in Entra. | Read-only |
| `08-Get-EntraGroupBasedLicensing.ps1` | Lists the groups that assign licences to their members (group-based licensing) with the SKU names, resolved through the tenant's subscribed SKUs. | Read-only |
| `09-Get-EntraOAuth2PermissionGrants.ps1` | Lists the delegated permission grants: which app obtained which permissions on which resource, and whether the consent covers the whole tenant or a single user. App and resource names are resolved. | Read-only |
| `10-Get-EntraIdentitySummary.ps1` | Summary dashboard: number of Global Administrators, app registrations, credentials expired or expiring within 30 days, service principals and guests. It prints the recap and exports a single row. | Read-only |

The third column says the same thing ten times, and that is the point: none of the ten scripts changes the tenant configuration, and none of the Graph scopes they ask for contains `.ReadWrite`. The only thing written is the CSV on your local disk.

## Before you run them

**PowerShell.** None of the ten scripts declares a minimum version in code. They are written for PowerShell 5.1 or PowerShell 7.

**Modules.** Install the full Graph module:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

Do not stop short of that: every script declares `#Requires -Modules Microsoft.Graph.Authentication`, which only covers `Connect-MgGraph`. The `Get-Mg*` cmdlets that do the actual work live in other submodules, so anyone who installs `Microsoft.Graph.Authentication` alone passes the requirements check and then watches the script fail on its first command with "term not recognized". If you prefer the minimum set over the meta-module, these six are the ones you need:

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Identity.Governance, Microsoft.Graph.Applications, Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Identity.SignIns -Scope CurrentUser
```

**Role.** Global Reader is enough for everything except the PIM data, which also requires an Entra ID P2 licence.

**Delegated Graph permissions, per script.** All of them read-only:

| Script | Scopes requested at `Connect-MgGraph` |
| --- | --- |
| 01 | `RoleManagement.Read.Directory` |
| 02 | `RoleEligibilitySchedule.Read.Directory` (PIM data needs Entra ID P2) |
| 03, 04, 05 | `Application.Read.All` |
| 06 | `User.Read.All`, `AuditLog.Read.All` (guest last sign-in needs Entra ID P1 or P2) |
| 07 | `Group.Read.All` |
| 08 | `Group.Read.All`, `Organization.Read.All` |
| 09 | `Directory.Read.All` |
| 10 | `Directory.Read.All`, `Application.Read.All` |

**Consent.** Consent to the scopes is requested at the first `Connect-MgGraph`. In a tenant where user consent is disabled an administrator has to approve it, otherwise the script does not start.

**Duration.** `03` and `07` query owners one at a time, one Graph call per application and per group: on a tenant with many objects, expect a long run.

## ⚠️ Warnings

1. **The CSVs contain personal data, and they are created in the folder you run the script from.** `06` exports the email addresses of guests, that is, of real people outside the company; `01` and `02` export the UPNs of whoever holds privileged roles; `07` and `09` export object IDs and, for per-user consents, the user's principal ID. The default path is relative, so if you cloned the repository and run the scripts from inside the clone, the files land in the working tree, where one distracted `git add .` publishes them. The `.gitignore` in the root excludes `*.csv`, but do not trust the `.gitignore`: check `git status` before committing, and handle these files the way you handle any other personal data from the tenant (do not attach them to a ticket, do not send them by email).

2. **The `10` dashboard can print a zero that is not a zero.** The Global Administrator role lookup uses `-ErrorAction SilentlyContinue` and, when it returns nothing, the count is `0`: an error or a missing permission therefore becomes the line "Global Administrator: 0", which on screen looks like data. A zero on that line is not a clean tenant, it is a figure to verify — cross-check it against `01`, which fails visibly on the same data.

3. **Without the right licences, two of the scripts do not say what they appear to say.** Without Entra ID P2, `02` prints a warning and exits **without writing any CSV**: anyone who runs the collection as a batch and then looks only at the files finds a hole rather than an error. Without Entra ID P1 or P2, `06` fills the last sign-in column with `n/d (Entra ID P1)` on every row: an inactive-guest review based on that column is not deciding anything at all. Check that the file exists and that the column is populated before using either one as evidence.

4. **None of the "who has access" lists is complete on its own.** `01` shows active, permanent assignments: if PIM is in use in the tenant, a list of administrators based on `01` alone **leaves out everyone who can activate a role at will** — you also need `02`. `04` covers app registration credentials, not service principal credentials: for those you need `05`. `07`, the other way round, is wider than it looks: it excludes groups synchronised from on-premises, and distribution lists created in Exchange show up as "without owner" because the owner is managed in Exchange — check them there before counting them as a gap.

5. **Two runs on the same day: the second overwrites the first, without asking.** The default name has daily granularity (`yyyyMMdd`) and the export uses neither `-NoClobber` nor a confirmation prompt. If you filter a result by hand and re-run the script to compare, the earlier CSV is gone. To keep both, pass an explicit `-OutputCsv`.

6. **`09` and `10` request `Directory.Read.All`, a wider scope than the other eight scripts.** It is read access to the tenant's entire directory, and the consent you grant at the first `Connect-MgGraph` stays valid for that application. For `09` this is deliberate: to list delegated OAuth2 consents, the only scope Microsoft documents as less privileged is `DelegatedPermissionGrant.ReadWrite.All`, which is a **write** permission, so `Directory.Read.All` is the most restrictive choice compatible with a read-only toolkit. For `10` the sum of the specific scopes would be enough (`RoleManagement.Read.Directory`, `User.Read.All`, `Application.Read.All`): if you want the bare minimum, edit that line. In both cases, running as Global Reader grants nothing in writing.

## Where the output goes

All ten scripts export a CSV into the **current directory**, with a name along the lines of `Entra-<name>-<yyyyMMdd>.csv`. Two consequences worth remembering:

- The file is created wherever the prompt is, not next to the script. If you cloned the repository and run from there, the CSV lands inside the clone: the root `.gitignore` excludes `*.csv`, but check `git status` before committing anyway.
- A second run on the same day overwrites the previous one without asking. Use `-OutputCsv` if you need to keep more than one snapshot from the same day.

The content is sensitive: email addresses of people outside the company (`06`), UPNs of administrators and of PIM-eligible principals (`01`, `02`), group object IDs (`07`), principal IDs of the users who granted a consent (`09`). This is personal data, and it should be retained and deleted like any other tenant data.

One last thing, on the difference between the screen and the file: `04` prints only the first twenty rows to the console, while the CSV holds everything; `10` prints the readable recap and exports a single summary row.

## Examples

```powershell
.\01-Get-EntraPrivilegedRoleMembers.ps1
.\04-Get-EntraExpiringAppCredentials.ps1 -Days 60
.\07-Get-EntraGroupsWithoutOwners.ps1
.\10-Get-EntraIdentitySummary.ps1

# With an explicit output path, so the previous collection is not overwritten
.\01-Get-EntraPrivilegedRoleMembers.ps1 -OutputCsv C:\Audit\admin-2026-10-29-1430.csv
```

## Download and support

The same content is available as a ZIP archive from [synsphere.it/download/toolkit-powershell-entra-identity-governance](https://synsphere.it/download/toolkit-powershell-entra-identity-governance/). If you need help reading the results, or fixing what they surface: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
