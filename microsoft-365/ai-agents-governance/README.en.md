# AI Agent Governance in Microsoft 365

Eleven read-only PowerShell scripts to find out which AI agents exist in your tenant, what permissions they actually hold, and who granted them.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

Before switching Copilot on in a tenant, it is worth knowing what is already there: which non-human identities are registered in Microsoft Entra, which application permissions they exercise with no user attached, who granted that consent and when, which apps and flows people have built on their own, and how wide the SharePoint sharing is that an assistant will end up reading. These scripts collect that into CSV files, one area per script, and change nothing. They are aimed at anyone running a pre-Copilot assessment on a tenant they administer or have been handed: MSPs, consultants, internal IT.

One thing has to be said up front, because it is the honest limit of the whole collection: the question "what can this agent see?" has no automatable answer today. No cmdlet joins an agent identity to its effective permissions on SharePoint or OneDrive. The toolkit builds the two ends of the bridge — on one side the list of agents with the permissions granted to them, on the other the sharing posture of the content — and the join between them stays manual analysis.

## The scripts

No script in this folder changes the tenant: all eleven are read-only, and their only effect on disk is a CSV file. Two of them print a command that does change the tenant, without running it: see warning 5.

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `00-Test-Prerequisiti.ps1` | Run this first. For each area it checks whether the module is installed, at which version, and whether the cmdlets the toolkit uses really answer `Get-Command`: half of those cmdlets appeared only in recent module versions, and a script that assumes they exist fails with an error that looks like a permissions problem and is not. It connects to no tenant. | Read-only |
| `01-Get-AgentIdentityInventory.ps1` | Tenant-wide inventory of agent-type non-human identities in Entra: name, `appId`, state, creation date, owning tenant. It uses the generic cmdlet with a filter on `servicePrincipalType`, because the dedicated cmdlets (`Get-EntraAgentIdentity`) only accept an ID and cannot produce an inventory. `-IncludiTutteLeIdentitaNonUmane` widens the search to `Application` and `ManagedIdentity`. | Read-only |
| `02-Get-AgentIdentityPermissions.ps1` | For each identity, lists the permissions actually granted: app role assignments (application permissions, which apply with no user attached) and oauth2 permission grants (delegated, bounded by what the user they act for can see). This is the basis of a least-privilege audit. It feeds from the CSV produced by `01`. | Read-only |
| `03-Get-ConsentAccountability.ps1` | Reads consent events from the directory audit — actor, application, permissions, result — because an app role assignment keeps the date of the consent but not who clicked "accept". Once the audit retention has passed, that "who" no longer exists anywhere: this CSV is meant to be kept, not reconstructed after the fact. | Read-only |
| `04-Test-UnifiedAuditLogEnabled.ps1` | Checks that unified auditing is on, connecting explicitly to Exchange Online and saying so in its output: the same cmdlet run in Security & Compliance PowerShell returns `False` even when auditing is enabled. Run it before `05`. | Read-only — prints a command that writes (warning 5) |
| `05-Get-CopilotInteractionAudit.ps1` | Pulls Copilot interactions and agent invocations out of the unified audit log and flattens them into a CSV. `-FiltraApp` filters on the app identity in post-processing, because that filter is not possible server-side. | Read-only |
| `06-Get-CopilotLicenseInventory.ps1` | Inventory of Microsoft 365 Copilot licences: how many were bought, how many are assigned, how many are free, and who holds them. The `SkuId` is resolved at runtime rather than hard-coded as a GUID, because a GUID written into a script eventually returns zero users without raising an error. | Read-only |
| `07-Get-SharePointOversharingBaseline.ps1` | Captures the tenant sharing policy and the state of every site. The two passes are deliberate, not an oversight: enumeration fills the sharing properties with default values, and the real values can only be read with one call per site. `-MaxSiti` (default 500) stops with a warning. | Read-only |
| `08-Get-RestrictedContentDiscoveryStatus.ps1` | State of Restricted Content Discovery site by site: where content is excluded from organisation-wide search and from Copilot without permissions being touched. | Read-only — prints a command that writes (warning 5) |
| `09-Get-ShadowAIPowerPlatform.ps1` | A census of shadow AI in Power Platform: environments with their generative-AI settings, apps, flows, connections, custom connectors, DLP policies and tenant settings. The header lists four declared gaps in the inventory, among them standard connectors and unpublished drafts. The only script that runs on Windows PowerShell 5.x alone. | Read-only |
| `10-Get-CopilotStudioAgents.ps1` | Inventory of Copilot Studio agents, plus an agent → connector map, through Azure Resource Graph: no dedicated cmdlet exists, and none of the roughly 170 Power Platform administration cmdlets has `bot`, `copilot` or `agent` in its name. Past 200 resources per type, Resource Graph returns 200 random items: the script flags that. | Read-only |

## Before you run them

**PowerShell.** PowerShell 7 (`pwsh.exe`) for scripts `00` through `08` and for `10`. Windows PowerShell 5.x (`powershell.exe`) **only** for `09`: the Power Platform administration module is not compatible with .NET Core, and the script stops by itself if launched on PowerShell 7.

**Modules.** Of the Graph modules you need the five submodules below, at version 2.0.0 or later.

```powershell
# PowerShell 7 - scripts 00 to 08 and 10
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Applications, Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Reports -Scope CurrentUser
Install-Module ExchangeOnlineManagement -MinimumVersion 3.2.0 -Scope CurrentUser
Install-Module Microsoft.Online.SharePoint.PowerShell -MinimumVersion 16.0.0 -Scope CurrentUser
Install-Module Az.ResourceGraph -MinimumVersion 0.13.0 -Scope CurrentUser

# Windows PowerShell 5.x - script 09 ONLY
Install-Module Microsoft.PowerApps.Administration.PowerShell -MinimumVersion 2.0.0 -Scope CurrentUser
```

`00` also checks for `Microsoft.Entra` 1.3.0, which no script requires: the agent-specific cmdlets are convenient but cannot produce an inventory, so the toolkit does not use them. The governance surfaces for AI agents change from month to month — the cmdlets in this collection were verified against Microsoft documentation on 19 August 2026 — and that is exactly why `00` exists: run it before anything else.

**Permissions and roles.** The Graph scopes are delegated and need administrator consent on first connection. They are all `.Read.All`: there is not a single `.ReadWrite` in this collection.

| Script | Permission or role |
| --- | --- |
| `00` | none: it connects to nothing |
| `01`, `02` | `Application.Read.All`, `Directory.Read.All` |
| `03` | `AuditLog.Read.All`, `Directory.Read.All` |
| `04`, `05` | Exchange Online, **View-Only Audit Logs** or **Audit Logs** role — from the Exchange Online session, not from Security & Compliance |
| `06` | `Organization.Read.All`, `User.Read.All`, `Directory.Read.All`; plus `AuditLog.Read.All` if you want the `UltimoAccesso` column (warning 2) |
| `07`, `08` | **SharePoint Administrator**, and the tenant admin URL in `-Url` (for example `-Url https://contoso-admin.sharepoint.com`) |
| `09` | **Power Platform Administrator**; the credentials from `Add-PowerAppsAccount` last about 8 hours |
| `10` | **Reader** on the subscriptions you want to query |

- `Directory.Read.All` is a read over every directory object in the tenant, and in `06` it is wider than necessary: `Get-MgSubscribedSku` is covered by `Organization.Read.All` and `Get-MgUser` by `User.Read.All`. If your consent goes through an approver, this table lets you request the minimum for the script you need to run, instead of the broadest consent for the whole collection.
- `AgentIdentity.Read.All` and the **Agent ID Administrator** role are mentioned in a comment inside `01` but never requested by the code: see warning 1.
- Scripts `04` and `05` assume unified auditing is enabled in the tenant; checking that is what `04` is for.
- Licensing: Restricted Content Discovery (`08`) requires at least one **Microsoft 365 Copilot** licence in the tenant, which is what unlocks SharePoint Advanced Management — on plain Business Premium it is not there. The Power Platform inventory (`09`) does not require E5.

## ⚠️ Warnings

1. **The agent inventory runs on `Application.Read.All`, and an empty list is presented as a normal outcome.** A comment inside `01` states that it also asks for `AgentIdentity.Read.All` ("we ask for both"), but the scope array holds only `Application.Read.All` and `Directory.Read.All`: that scope is never taken to consent. Consequence: in a tenant where agent identities are managed and that scope is genuinely needed, the inventory comes back incomplete or empty, and the script's own message in that case reads "the list will be empty: this is not an error" — in other words, it invites you to read a zero as good news. And because `02` feeds from this CSV, the emptiness propagates to everything downstream. Before concluding that the tenant has no agents, re-run with `-IncludiTutteLeIdentitaNonUmane` — an agent registered as an ordinary app registration does not appear among the `ServiceIdentity` objects — and check by hand in the portal. A zero here has to be explained, not accepted.

2. **In the Copilot licence CSV the `UltimoAccesso` (last sign-in) column is empty by construction, and empty does not mean "unused".** `06` connects with `Organization.Read.All`, `User.Read.All` and `Directory.Read.All`, then asks for the `SignInActivity` property, which requires `AuditLog.Read.All`: with that consent the request always fails, the script re-reads without the property (this is by design, and it says so in a warning) and exports `UltimoAccesso` systematically empty. Consequence: whoever opens the CSV sees a column of blank cells and concludes that nobody uses Copilot — a spending decision taken on a value that was never read. If you need that column, add `AuditLog.Read.All` to the consent; otherwise ignore it and do not base renewals on it. The count of licences sitting on disabled accounts, which the script prints separately, is reliable: it comes from `AccountEnabled`, not from `SignInActivity`.

3. **The per-operation counts from `05` are a floor, not a total.** The script has two loops, and they behave differently: the one over `RecordType` paginates correctly with `-SessionId` and `-SessionCommand ReturnLargeSet`, while the one over the four agent operations (`AIInvokeAgent`, `AIExecuteTool`, `AIInferenceCall`, `AIGuardrail`) calls the search with `-ResultSize 5000` and no pagination, so it stops at 5,000 records per operation without saying so. Consequence: in an active tenant those rows are cut silently, while the total printed at the end looks complete. Work in short windows and add them up, rather than asking for a month in one go; if an operation returns exactly 5,000 records, that is the sign there are more. The two limits declared in the header apply as well: audit latency is 60-90 minutes, so the most recent hours are incomplete by construction, and Microsoft warns that the audit log is not intended as a basis for adoption reporting — these numbers serve security and traceability, not percentages to put in front of someone.

4. **If `09` does not print "Fatto.", the CSV files you find are a partial inventory, and nothing in the files says so.** The script runs with `$ErrorActionPreference = 'Stop'`, and four of its seven collections — apps, flows, connections, custom connectors — are invoked without `try/catch`, while environments, DLP policies and tenant settings are protected. Consequence: if one of those four fails on permissions, throttling or an expired session, the script dies after having already written the earlier CSVs; the files stay on disk, well-formed and incomplete, and the final line of output is never reached. Always check the end of the output: without "Fatto.", throw away that run's CSVs and start again, because a partial shadow-AI census is worse than none.

5. **Two scripts print a tenant-changing command, ready to paste. The toolkit does not run it: the decision belongs to whoever administers the tenant.** `04`, right after announcing that auditing is off — that is, at the moment of maximum hurry — suggests `Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true`: that is a tenant-wide change, and auditing once enabled does not recover the past, events only start appearing from that point on. `08` suggests `Set-SPOSite -Identity <url> -RestrictContentOrgWideSearch $true`: it changes the discoverability of a site's content, it does not apply to OneDrive, and on sites above 500,000 items propagation can take more than a week, so a check the next day does not prove it failed. Before pasting either one, agree it with the tenant administrator and record it as a change, not as a step of the toolkit.

6. **`08` has no cap on the number of sites: in a large tenant it runs for hours and cannot be limited.** It enumerates every site and then makes one call per site — the second pass is necessary, because enumeration returns default values instead of real ones — but unlike its twin `07` it has no `-MaxSiti` parameter to stop with a warning past 500 sites. Consequence: nothing destructive, but SharePoint throttling, a session that drops halfway and a partial CSV, after a long wait. Run `07` against the same tenant first: it tells you how many sites there are and, if they are beyond its limit, stops before making you wait for nothing. Use that number to estimate the time, then decide whether to start `08`.

## Where the output goes

Every script exports one or more CSVs, and the default path is **relative to the current directory**, with a name that contains only the date (for example `.\AI-AgentIdentityInventory-20261029.csv`). `09` writes up to seven files named `AI-PP-<area>-<date>.csv` into the folder given by `-CartellaOutput`, which defaults to the current one; `10` writes two. Two consequences:

- The file is born wherever the prompt is. If you cloned the repository and run the scripts from inside the clone, the CSV lands **inside the clone**: the root `.gitignore` excludes `*.csv`, but do not rely on that net — check `git status` before a commit.
- A second run on the same day **overwrites** the previous export without asking: the name depends only on the date, and `Export-Csv` is not called with `-NoClobber`.

The content is not anonymous. The CSVs hold personal data: UPN, name, department, job title and last sign-in of every Copilot-licensed user (`06`); the UPN of whoever granted a consent (`03`); the identifiers of users who interacted with Copilot, with the thread id and up to 1,500 characters of the raw audit record (`05`); the names of whoever created apps, flows and connections (`09`). They also hold material that amounts to a map of the attack surface: the list of sites that allow anonymous links, with URL and owner (`07`, `08`), and the list of agents with the application permissions they exercise across the whole tenant (`02`). Point `-OutputCsv` at a controlled folder, and delete the exports once the analysis is done.

One clarification about `05`, because it removes a wrong worry and raises a correct one: the text of prompts and responses is **not** in the audit log, which carries only the thread id. That content lives in the data-security tooling, not in these CSVs. What does remain written down is who interacted, when, and with which workload.

## Examples

```powershell
# First step: modules, versions and cmdlets. Connects to no tenant.
.\00-Test-Prerequisiti.ps1

# Agent identity inventory, widened to every non-human identity
.\01-Get-AgentIdentityInventory.ps1 -IncludiTutteLeIdentitaNonUmane

# Granted permissions, starting from the inventory CSV
.\02-Get-AgentIdentityPermissions.ps1 -InventoryCsv .\AI-AgentIdentityInventory-20260819.csv

# Shadow AI in Power Platform: from Windows PowerShell 5.x, not from pwsh
powershell.exe -File .\09-Get-ShadowAIPowerPlatform.ps1
```

## More

The same content is available as a ZIP archive from [synsphere.it/download/toolkit-powershell-governance-agenti-ai](https://synsphere.it/download/toolkit-powershell-governance-agenti-ai/).

If you need help reading the results or setting up a pre-Copilot assessment: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
