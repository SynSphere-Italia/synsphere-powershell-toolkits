# Teams and SharePoint Toolkit for Microsoft 365

Ten read-only PowerShell scripts that capture the Microsoft Teams and SharePoint Online governance of a tenant and export all of it to CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

These scripts are for whoever administers a Microsoft 365 tenant, an in-house IT department or an MSP, and needs in exportable form what the admin center shows one screen at a time: which teams exist and who owns them, where external guests have been added, which SharePoint sites allow anonymous links, how much storage each site consumes, who deleted a file, who attended a meeting.

None of the ten scripts modifies the tenant: they read, and they write a CSV. The typical use is periodic access review, offboarding, capacity planning and gathering evidence for an audit.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-M365TeamsReport.ps1` | Lists every team in the tenant (Microsoft 365 groups with "Team" provisioning) with Public/Private visibility, the number of owners, members and guests, and the creation date. | Read-only |
| `02-Get-M365OrphanedTeams.ps1` | Finds orphaned teams, that is teams with no owner at all: nobody is responsible for management and membership, and access is never reviewed again. | Read-only |
| `03-Get-M365TeamsMembership.ps1` | Exports one row per membership (team, person, owner or member role, user type): the full map of who is in which team. | Read-only |
| `04-Get-M365TeamsChannels.ps1` | Lists the channels of each team with their membership type (standard, private, shared) and counts the private and shared ones. | Read-only |
| `05-Get-M365TeamsWithGuests.ps1` | Lists the teams that have at least one external guest, with their addresses, so you know where external collaboration happens. | Read-only |
| `06-Get-M365SPOSitesReport.ps1` | Inventory of SharePoint Online sites: URL, owner, template, storage used and quota, external sharing capability, last content modification. | Read-only |
| `07-Get-M365SPOExternalSharingSettings.ps1` | Reports the `SharingCapability` of each site and of the tenant, flagging the sites set to the most open level (`ExternalUserAndGuestSharing`, that is anonymous links). | Read-only |
| `08-Get-M365SPOStorageReport.ps1` | Sorts sites by storage used, computes the percentage against the quota and the tenant total. | Read-only |
| `09-Get-M365FileDeletionAudit.ps1` | Queries the Unified Audit Log for file deletions in SharePoint and OneDrive (`FileDeleted`, `FileRecycled`, first and second stage recycle bin): who, when, which file, which site. | Read-only |
| `10-Get-M365TeamsMeetingAudit.ps1` | Extracts Teams meeting participation details from the Unified Audit Log: participant, role, join and leave time. | Read-only |

None of the ten scripts writes to the tenant and none requests write permissions. Note warning 5, though: 06, 07 and 08 are read-only, but running them requires a role that can also write.

## Before you run them

**PowerShell.** 5.1 or 7. None of the scripts declares `#Requires -Version`, so on an older host you get no clear message: the first unsupported cmdlet simply fails.

**Modules.**

```powershell
# scripts 01-05 (Microsoft Graph)
Install-Module Microsoft.Graph -Scope CurrentUser

# scripts 06-08 (SharePoint Online Management Shell)
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser

# scripts 09-10 (Exchange Online, for the Unified Audit Log)
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

Scripts 01-05 declare `#Requires -Modules Microsoft.Graph.Authentication` (04 also `Microsoft.Graph.Teams`), but they use `Get-MgGroup`, `Get-MgGroupOwner` and `Get-MgGroupMember`, which live in `Microsoft.Graph.Groups` and are declared by no script: installing the authentication module alone is not enough. The `Microsoft.Graph` meta-module in the command above covers them all.

**Permissions and roles.**

- **01-05**: Microsoft Graph delegated scopes. `Group.Read.All` for all five; `GroupMember.Read.All` also for 01, 03 and 05; `Channel.ReadBasic.All` also for 04. These scopes **require administrator consent**: on the first `Connect-MgGraph` a non-privileged user gets a consent error, not a permission error. A Global Administrator grants it once per tenant.
- **01, 03 and 05** request both `Group.Read.All` and `GroupMember.Read.All`. The former is the broader one and already allows reading a group's owners and members: the latter adds nothing and only shows up as one more entry on the consent screen.
- **06-08**: the **SharePoint Administrator** role, plus the admin center URL (`https://<tenant>-admin.sharepoint.com`) in the mandatory `-AdminUrl` parameter. See warning 5.
- **09-10**: a connection to Exchange Online and the **View-Only Audit Logs** role.

## ⚠️ Warnings

1. **A report that looks complete may not be (01, 03, 05).** The calls that read owners and members use `-ErrorAction SilentlyContinue`: if one of them fails (throttling, permission denied on a single group, a group in a transient state) the error is suppressed and that call's result stays empty. In 05 a team that **does** have external guests is simply omitted from the CSV and the count printed at the end comes out lower than reality; in 01 that team's owners and members become 0; in 03 membership rows go missing, exactly the rows an offboarding audit needs. The script cannot tell "no guests" from "I could not ask". Run the script twice and compare the two results: if they differ, at least one of them is incomplete. Also compare the number of teams reported by 01 with the number of teams you see in the admin center.

2. **The orphaned-teams list can contain false positives (02).** The same mechanism, the other way round: if reading the owners fails, the variable stays empty, the "zero owners" condition evaluates to true and the team lands in the orphans list. The script then prints in red `ATTENZIONE: N team SENZA owner` ("warning: N teams with NO owner" — the scripts' console output is in Italian), so an API error turns into a governance alert and leads you to act on healthy teams. Before assigning owners or closing a team, check in the Teams admin center that those teams really have no owner.

3. **The audits stop at 5,000 events without saying so (09, 10).** Both call `Search-UnifiedAuditLog` with `-ResultSize 5000`, without `-SessionCommand ReturnLargeSet` and without pagination: if the time window contains more events, you get the first 5,000 and the closing message prints that number as if it were the total. If the printed number is 5,000 or close to it, treat the report as truncated and run the extraction again over shorter intervals.

4. **The output is personal data (all of them, 03, 05, 09 and 10 in particular).** The CSVs are not encrypted and no script asks for confirmation before writing one or warns about its contents: 03 contains the userPrincipalName of every person in every team, 05 the e-mail addresses of external guests, 09 the identity of whoever deleted a file along with the file name, 10 the UPN of every attendee of every meeting with join and leave times. The last two touch on remote monitoring of workers' activity: before running them, check on what basis you are collecting that data, who may read it and how long you keep it. Write them outside folders synchronised with OneDrive or SharePoint, and delete them once you no longer need them.

5. **06, 07 and 08 are read-only, but they require a role that can write.** `Get-SPOSite` and `Get-SPOTenant` only work with the SharePoint Administrator role, which is tenant-wide and also allows deleting sites and changing external sharing for the whole tenant; the `Microsoft.Online.SharePoint.PowerShell` module has no read-only equivalent. This is not a flaw in the scripts, it is a delegation not to leave standing: activate the role for a limited time (with PIM, for example), produce the report, then deactivate it, rather than assigning it permanently to someone who only needs to read.

6. **`-Days` is not validated (09, 10).** The help says "max 90", but the parameter is a plain `[int]` with no constraint: `-Days 400` is accepted and produces a start date outside the Unified Audit Log retention, `-Days -5` is accepted and produces a start date later than the end date. In both cases you get an empty CSV or a raw error, not a comprehensible message. An empty CSV here does not mean "no events": it means the window you asked for makes no sense.

## Where the output goes

All ten scripts accept `-OutputCsv`. If you do not pass it, the file is created **in the current directory**, with a name that contains only the date (for example `.\M365-TeamsMembership-20261029.csv`). Two consequences:

- **The file is created where the prompt is, not where the script is.** If you cloned the repository and run the scripts from that folder, the CSVs end up inside the clone. The repository `.gitignore` excludes `*.csv`, but do not rely on that safety net: pass `-OutputCsv` with a path outside the clone and outside folders synchronised with OneDrive or SharePoint.
- **A second run on the same day overwrites the first, without asking.** The name contains the date but not the time. If you need to compare two runs on the same day (that is how you catch the incomplete reports of warning 1), give each one a different `-OutputCsv`.

Warning 4 applies to the contents of these files: they are personal data in the clear.

## Examples

```powershell
# Teams with no owner: no parameters needed
.\02-Get-M365OrphanedTeams.ps1

# SharePoint site inventory: -AdminUrl is mandatory
.\06-Get-M365SPOSitesReport.ps1 -AdminUrl https://contoso-admin.sharepoint.com

# File deletions over the last 30 days
.\09-Get-M365FileDeletionAudit.ps1 -Days 30

# Teams meeting attendees over the last 14 days
.\10-Get-M365TeamsMeetingAudit.ps1 -Days 14
```

## Download and support

The same content can be downloaded as a ZIP from [synsphere.it/download/toolkit-powershell-teams-sharepoint-microsoft-365](https://synsphere.it/download/toolkit-powershell-teams-sharepoint-microsoft-365/). If you need help with Teams and SharePoint: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
