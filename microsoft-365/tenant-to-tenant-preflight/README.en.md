# Tenant-to-tenant migration pre-flight (Microsoft 365)

Ten read-only PowerShell scripts that photograph a Microsoft 365 tenant before a tenant-to-tenant migration and export to CSV the data you need to size and plan it.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

Before you move a tenant you need to know what is inside it: which domains and which DNS records are published, how many mailboxes there are and how much they weigh, which delegations will have to be rebuilt by hand, who is synchronised from Active Directory and who was born in the cloud, how many licences you will need on the other side. These scripts collect that data and write it to CSV, one file per area, plus a summary dashboard.

They are aimed at whoever has to size and plan a tenant-to-tenant migration: MSPs, consultants and in-house IT at small and medium businesses. They move nothing and change nothing — every call is a `Get-*`. Where they can, they defuse the Exchange Online, SharePoint and Microsoft Graph defaults that produce a wrong report without showing an error: `ResultSize` stuck at 1000, `Get-SPOSite -Limit` stuck at 200, the eleven properties `Get-MgUser` returns when you do not ask for more, the tri-state of `onPremisesSyncEnabled`, `NT AUTHORITY\SELF` showing up among the delegations of every mailbox.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-T2TDomains.ps1` | Tenant domains (verified, default, initial, managed or federated) and, for each, the service records published on that tenant today: MX, verification and SPF TXT, CNAME, SRV | Read-only |
| `02-Get-T2TMailboxInventory.ps1` | Mailboxes with ExchangeGuid, ArchiveGuid, sizes and item counts: the values to carry over to the mail-enabled objects in the target tenant | Read-only |
| `03-Get-T2TMailboxDelegations.ps1` | FullAccess, SendAs and SendOnBehalf — the list of delegations to rebuild; excludes SELF and entries overridden by a Deny | Read-only |
| `04-Get-T2TGroups.ps1` | Distribution lists, mail-enabled security groups, Microsoft 365 groups and dynamic groups, with members, owners and membership filter | Read-only |
| `05-Get-T2TLicenseGap.ps1` | Licences per user and per SKU, usageLocation, and which licences come from a group rather than from a direct assignment | Read-only |
| `06-Get-T2TSharePointSizing.ps1` | SharePoint sites and personal OneDrive sites with storage used and quota, normalised to bytes | Read-only (closes the SharePoint session: see warning 6) |
| `07-Get-T2TTeamsInventory.ps1` | Teams with their owners and their standard, private and shared channels, read through Microsoft Graph because the Teams module does not expose shared channels | Read-only |
| `08-Get-T2TMailFlow.ps1` | Inbound and outbound connectors, accepted and remote domains, transport rules with their state | Read-only |
| `09-Get-T2TEntraObjects.ps1` | Cloud-only versus on-premises-synchronised users, guests, and the security groups Exchange cannot see | Read-only |
| `10-Get-T2TPreflightSummary.ps1` | Dashboard: tenant counts and volumes in a single CSV; with `-SharePointCsv` it also adds SharePoint and OneDrive | Read-only |

None of them writes to the tenant: the only thing they produce is a CSV on disk.

**Suggested order:** 09 → 05 → 02 → 03 → 04 → 01 → 08 → 06 → 07 → 10. Start from identities, because the cloud-only / synchronised split decides the whole plan, and finish with the dashboard, handing it the CSV produced by script 06.

**Scope.** The toolkit does not produce the DNS records to create on the target tenant: the target's DKIM CNAMEs depend on the prefix of its initial domain and on the partition assigned to it, values that only exist once the domain has been added over there, so a DNS runbook derived from the source would be wrong. And it does not check Organization Relationship, MailboxMoveCapability or whether the migration endpoint is reachable, because in a pre-flight those objects do not exist yet.

## Before you run them

**PowerShell.** Windows PowerShell 5.1 or PowerShell 7. No script enforces a minimum version with `#Requires -Version`; each one does declare the modules it needs with `#Requires -Modules`, and stops straight away if they are missing.

**Modules.**

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser                 # 02, 03, 04, 08, 10
Install-Module Microsoft.Graph -Scope CurrentUser                          # 01, 05, 07, 09, 10
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser   # 06 only
```

If you would rather not install the whole Graph meta-module, the submodules actually declared are `Microsoft.Graph.Identity.DirectoryManagement` (01, 05, 10), `Microsoft.Graph.Users` (05, 09, 10), `Microsoft.Graph.Groups` (07, 09) and `Microsoft.Graph.Teams` (07).

**Roles and permissions.** All read-only: none of the ten scripts contains a `.ReadWrite.` or `.Write` scope, any role management, or any app role assignment.

| Script | What the script declares and requests | Minimum set that covers the actual calls |
| --- | --- | --- |
| 01 | Graph: `Domain.Read.All` (Global Reader is enough) | as declared |
| 02, 03, 04, 08 | Exchange: View-Only Organization Management | as declared |
| 05 | Graph: `User.Read.All`, `Organization.Read.All`, `Directory.Read.All` | `User.Read.All` + `Organization.Read.All` |
| 06 | SharePoint Administrator (or Global Reader for read-only access) | as declared |
| 07 | Graph: `Group.Read.All`, `Channel.ReadBasic.All`, `ChannelMember.Read.All`; recommended role: Teams Administrator | `Group.Read.All` + `Channel.ReadBasic.All` |
| 09 | Graph: `User.Read.All`, `Group.Read.All`, `Directory.Read.All` | `User.Read.All` + `Group.Read.All` |
| 10 | Exchange: View-Only Organization Management, plus Graph: `User.Read.All`, `Directory.Read.All`, `Organization.Read.All` | `User.Read.All` + `Organization.Read.All` |

**Two tenants = two separate runs.** `Connect-MgGraph` replaces the session of the whole process, and Exchange Online and SharePoint keep one context per session. To compare source and target you run the toolkit on one tenant at a time, in separate PowerShell processes, and compare the CSV files offline. Two tenants in the same process would report the same tenant twice, without raising an error.

**Running time.** Script 10 calls `Get-MailboxStatistics` once for every mailbox in the tenant, with no progress indicator and no switch to skip the statistics: on a large tenant it looks stuck, but it is working. Script 02 does have `-SkipStatistics` and a progress bar.

## ⚠️ Warnings

1. **The output is an export of personal data.** Script 09 exports, for every user, display name, UserPrincipalName, mail address, ImmutableId, SamAccountName and usageLocation; script 03 the complete map of who has access to whose mailbox; script 04 the address of every member of every group; script 06 the OneDrive URLs, which contain the user's identity. This is personal data under the GDPR and must be handled as such: where you keep it, for how long, and its deletion when the assessment ends. A practical aggravating factor: the default path is the current folder, so if you launch the scripts inside the cloned repository a customer's CSV files end up in your git working tree. Run them from a folder outside the clone.

2. **Five errors are swallowed in silence, and two of them push the numbers down.** In script 10 every `Get-MailboxStatistics` that fails is ignored without a warning: the total mailbox volume — the very number you size the migration with — comes out lower than the truth and looks like a correct result. In script 04, if reading a group's members fails, the group is exported with `NumeroMembri` at 0 and an empty `Membri` column, indistinguishable from a genuinely empty group; the same applies to owners, in both 04 and 07, where a team can appear to have no owner purely because the call failed. Compare the counts with what you see in the portal, and never accept a zero without checking it.

3. **Without the right roles the report comes out incomplete, not in error.** Script 07 without the Teams Administrator role returns private and shared channels incompletely, and the count comes out lower than the truth without a single message. This holds in general: if a Graph consent is missing or narrower than needed, the CSV can come out empty or with every row negative, and a number without its denominator misleads. Check that you hold the roles in the table above before trusting a result — especially when that result is a zero.

4. **A second run on the same day overwrites the previous CSV, without asking.** Every default file name contains only the date (`yyyyMMdd`), and none of the thirteen exports uses `-NoClobber` or checks whether the file already exists. It compounds with the rule above: run the source and then the target in the same folder on the same day and you will find the source CSV replaced by the target's, same file name, no error. Run each tenant in its own subfolder, or pass an explicit path to the parameters (`-OutputCsv`, `-SkuCsv`, `-TeamsCsv`, `-GroupsCsv`): no path is hard-coded in the scripts.

5. **The consent an administrator sees is broader than what the scripts use.** Script 07 requests `ChannelMember.Read.All`, which grants read access to the member list of every channel including private ones, yet it never reads a channel's members: its calls are covered by `Group.Read.All` and `Channel.ReadBasic.All`. Likewise `Directory.Read.All`, requested by scripts 05, 09 and 10, reads the entire directory while narrower scopes would already cover the actual calls. These are all read-only permissions, but if your tenant grants consent sparingly, use the minimum set from the table above.

6. **Script 06 closes your SharePoint session even if it did not open it.** Its final block always runs `Disconnect-SPOService`: if you already had a `Connect-SPOService` open for other work, you will find it closed when the script ends and you will have to reconnect. The Exchange scripts behave differently: they use `Get-ConnectionInformation` to check whether a connection already exists, and never disconnect.

## Where the output goes

Each script writes one or two UTF-8 CSV files to the **current** directory, with a name that contains only the date: `T2T-Domains-<date>.csv`, `T2T-Mailboxes-<date>.csv`, `T2T-Delegations-<date>.csv`, `T2T-Groups-<date>.csv`, `T2T-Licenses-<date>.csv` and `T2T-LicenseSkus-<date>.csv`, `T2T-SharePoint-<date>.csv`, `T2T-Teams-<date>.csv` and `T2T-TeamsChannels-<date>.csv`, `T2T-MailFlow-<date>.csv`, `T2T-EntraUsers-<date>.csv` and `T2T-EntraGroups-<date>.csv`, `T2T-Summary-<date>.csv`.

Two consequences to keep in mind every time:

- The file is born where the prompt is, not where the script is. If you cloned this repository and launch from there, the CSV lands **inside the clone**. The root `.gitignore` does exclude `*.csv`, but do not rely on that filter as your only protection: do not commit those files, and better still work from a folder outside the repository.
- A second run on the same day overwrites the previous one without asking (warning 4).

**Sensitive content.** These CSV files are not anonymous. They contain names, UserPrincipalNames and mail addresses (02, 03, 04, 05, 09), the ImmutableId and SamAccountName of users synchronised from Active Directory (09), the list of external guest users (09), the map of mailbox access permissions (03), the member list of every group (04) and the URLs of personal OneDrive sites (06). Script 08 adds infrastructure configuration: the sender IP addresses allowed by inbound connectors and the smart hosts of the outbound ones. Treat them as the export of a production system, because that is what they are.

## Examples

```powershell
# Start from identities: cloud-only versus synchronised from on-premises
.\09-Get-T2TEntraObjects.ps1

# Mailbox inventory without the size statistics, for large tenants
.\02-Get-T2TMailboxInventory.ps1 -SkipStatistics

# SharePoint and OneDrive sizing
.\06-Get-T2TSharePointSizing.ps1 -TenantAdminUrl https://contoso-admin.sharepoint.com

# Final dashboard, with the SharePoint volume taken from script 06's CSV
.\10-Get-T2TPreflightSummary.ps1 -SharePointCsv .\T2T-SharePoint-20260824.csv
```

## Download and support

The same content is available as a ZIP archive from [synsphere.it/download/toolkit-powershell-migrazione-tenant-to-tenant-preflight](https://synsphere.it/download/toolkit-powershell-migrazione-tenant-to-tenant-preflight/).

The scripts are provided "as is", without warranty: try them in a test environment before running them against a production tenant. If you need help, or a migration assessment run by us: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
