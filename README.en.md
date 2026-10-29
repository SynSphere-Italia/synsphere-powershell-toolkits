# SynSphere PowerShell Toolkits

247 PowerShell scripts for administering Microsoft 365, Azure and Entra ID.
They come out of [SynSphere Italia](https://synsphere.it)'s daily work on
customer tenants: every script solves a problem we ran into at least once.

[Versione italiana](README.md) · [Apache-2.0 licence](LICENSE) · [Security](SECURITY.md) · [Contributing](CONTRIBUTING.md)

> **A note on language.** The scripts themselves — console output, inline
> comments, CSV column headers — are in **Italian**, because they were written
> for Italian SMEs and their IT staff. The comment-based help in each script
> (`Get-Help .\script.ps1 -Full`) is in Italian too. This documentation is
> bilingual; the code is not. Read that as a fact about scope, not as a plan
> to translate it later.

---

## Before you start: two things that matter

**Most of them are read-only, but not all.** Scripts whose name starts with
`Get-` or `Export-` only read. Any other verb (`Set-`, `Remove-`, `Invoke-`,
`New-`) **changes the tenant**. The script table in every folder marks the two
categories, and where `-WhatIf` exists, use it the first time.

**The Graph `#Requires` declarations are incomplete, and we are telling you so.**
Nearly every script declares only `Microsoft.Graph.Authentication`, which
provides `Connect-MgGraph` and nothing else. The `Get-Mg*` cmdlets they use
live in other submodules. If you install exactly what `#Requires` declares, the
first `Get-Mg*` answers "term not recognized". The short, safe path is the
meta-module:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser
Install-Module Az -Scope CurrentUser          # only for the Azure toolkits
```

Each folder lists the modules its scripts actually need.

---

## The toolkits

### Microsoft 365 — 114 scripts

| Folder | Scripts | What it solves |
| --- | ---: | --- |
| [license-management](microsoft-365/license-management/) | 10 | Who holds which licences, which SKUs are consumed, shared mailboxes licensed by mistake, direct licences overlapping group-based ones, licensed but inactive users |
| [user-lifecycle](microsoft-365/user-lifecycle/) | 10 | Real last sign-in, MFA state, password age, admins and roles, managers, sign-in history, and full user offboarding |
| [exchange-mailbox](microsoft-365/exchange-mailbox/) | 10 | Delegations on mailboxes and shared mailboxes, reverse lookup of one user's access, mailbox and archive sizes, auto-forwarding |
| [groups](microsoft-365/groups/) | 10 | Inventory of groups and distribution lists, owners and members, empty groups, ownerless groups, one user's groups |
| [teams-sharepoint](microsoft-365/teams-sharepoint/) | 10 | Teams with owners, members and guests, orphaned teams, private and shared channels, SharePoint sites and storage consumption |
| [guest-external](microsoft-365/guest-external/) | 10 | External guests with their source domain and invitation state, stale guests to clean up, tenant external-collaboration settings |
| [backup-continuity](microsoft-365/backup-continuity/) | 10 | How recoverable a tenant really is: holds, recovery window, Single Item Recovery, mailboxes with no protection at all, deleted items still recoverable |
| [tenant-to-tenant-preflight](microsoft-365/tenant-to-tenant-preflight/) | 10 | The snapshot to take **before** a tenant-to-tenant migration: domains and DNS, mailbox GUIDs, delegations to rebuild, licences, sizing |
| [mailbox-delegation](microsoft-365/mailbox-delegation/) | 2 | Grants or revokes the four mailbox delegations (FullAccess, SendAs, SendOnBehalf, folder-level), with presets for the assistant-to-manager case |
| [intune-endpoint](microsoft-365/intune-endpoint/) | 10 | Managed endpoint estate: inventory, compliance overall and per OS, policies and profiles with their assignments, deployed apps, Autopilot |
| [windows-11-migration](microsoft-365/windows-11-migration/) | 10 | Hardware readiness on one machine and across the fleet over WinRM (TPM 2.0, Secure Boot, UEFI/GPT, RAM, CPU), Windows 10 and application inventory |
| [aruba-imap-migration](microsoft-365/aruba-imap-migration/) | 1 | Mail migration from Aruba to Microsoft 365 over IMAP |
| [ai-agents-governance](microsoft-365/ai-agents-governance/) | 11 | AI agent governance: agent identities and the permissions they actually hold, who granted them and when, Copilot interactions in the audit log, Copilot licences, shadow AI on Power Platform |

### Azure — 80 scripts

| Folder | Scripts | What it solves |
| --- | ---: | --- |
| [compute](azure/compute/) | 10 | VM and disk inventory, stopped-but-still-allocated VMs, VMs without backup, orphaned disks, extensions, auto-shutdown, patch state |
| [cost-management](azure/cost-management/) | 10 | Where the money goes (by resource group, service, resource, monthly trend) and what can be cut today: unused disks and public IPs |
| [governance](azure/governance/) | 10 | Multi-subscription inventory, missing tags and bulk tagging, empty resource groups, locks, orphaned resources still being billed |
| [monitoring](azure/monitoring/) | 10 | Activity Log, alert rules and action groups, Log Analytics workspaces, backup job outcomes, autoscale, diagnostic settings |
| [networking](azure/networking/) | 10 | VNet and subnet inventory, full NSG rule export, public IPs, orphaned network resources, peerings, Load Balancers and Application Gateways, DNS records |
| [rbac](azure/rbac/) | 10 | Who holds which role at which scope: full assignments, privileged roles, custom roles, orphaned assignments, service principals, inheritance from groups |
| [security](azure/security/) | 10 | Defender for Cloud Secure Score and recommendations, NSG rules open to the Internet on management and database ports, exposed public IPs, Key Vaults |
| [storage-database](azure/storage-database/) | 10 | Storage accounts (redundancy, used capacity, anonymous containers, firewalls, lifecycle policies) and SQL databases |

### Security and compliance — 53 scripts

| Folder | Scripts | What it solves |
| --- | ---: | --- |
| [defender](security/defender/) | 10 | Current and historical Secure Score, improvement actions ranked by gap, open alerts and incidents, risky users and Entra ID Protection detections |
| [purview-compliance](security/purview-compliance/) | 10 | How much of a Purview configuration is actually protecting anything: real scope of retention policies, labels never published, DLP policies |
| [email-security](security/email-security/) | 10 | Mail audit: volumes per user, anti-spam and anti-phishing verdicts, deletions, delegated sends, transport rules, connectors, quarantine |
| [incident-response](security/incident-response/) | 10 | The first hours of an incident: go/no-go check on available evidence, reversible account snapshot, containment, restore, forensic exports |
| [entra-identity-governance](security/entra-identity-governance/) | 10 | Active admins and PIM-eligible roles, app registrations and enterprise apps, expiring secrets and certificates, OAuth consents |
| [acn-cyber-taxonomy](security/acn-cyber-taxonomy/) | 1 | Browse and export the Italian national cybersecurity agency's Cyber Taxonomy, downloaded from the official source on each run |
| [entra-credentials-expiry](security/entra-credentials-expiry/) | 1 | Expiry dates of Entra ID app registration client secrets and certificates |
| [mailbox-retention-exposure](security/mailbox-retention-exposure/) | 1 | Mail retention inventory: litigation hold, inactive mailboxes, applied policies |

---

## ⚠️ Three things to know before running anything

**1. Reports export to the current directory, and they overwrite.** Nearly
every script writes a CSV to `.\` with a name that contains only the date. Two
consequences: if you run a script from the folder where you cloned this
repository, **the CSV lands inside the clone** (`.gitignore` excludes it, but
do not rely on that — check before a `git add`); and a second run on the same
day overwrites the first without asking.

Some of those CSVs hold sensitive data: BitLocker recovery keys, sign-in IP
addresses, mailbox permissions, MFA state, lists of external guests. Each
folder's warnings say which.

**2. An empty report is not good news.** Several scripts produce a result that,
when permissions are insufficient, comes back empty or all-negative with no
error: "no VM has a backup", "no user has MFA". Before acting on an extreme
result, confirm you hold the permissions the folder declares. A numerator
without its denominator is worthless.

**3. Use PowerShell 7 if you can.** The scripts work on Windows PowerShell 5.1,
and the files in this repository are saved as UTF-8 **with BOM** precisely so
that accented messages read correctly on 5.1. If you take one of these scripts
from somewhere else and it prints `perchÃ©` instead of `perché`, that copy has
no BOM: take it from here instead.

---

## Relationship with synsphere.it

This repository is the **source of truth** for the scripts.
[synsphere.it/download](https://synsphere.it/download/) distributes the same
content packaged as ZIP archives, for people who would rather download a file
than clone a repository. The archives are regenerated from this repository by
`tools/Build-DownloadZips.ps1`: there are not two copies to keep in sync by
hand.

Many toolkits have an accompanying article (in Italian) walking through a
concrete case; the link is in each folder's README.

---

## Layout

```
microsoft-365/   13 collections, 114 scripts
azure/            8 collections,  80 scripts
security/         8 collections,  53 scripts
tools/            Build-DownloadZips.ps1  regenerates the website archives
                  Test-Codifica.ps1       checks UTF-8 with BOM and LF endings
.github/          PowerShell analysis on every push and pull request
```

Each folder holds its scripts, a `README.md` in Italian and a `README.en.md`
in English.

---

## Quality

Every push and every pull request runs a pipeline that checks four things: that
each script parses without syntax errors; that PSScriptAnalyzer reports no
errors; that encoding is UTF-8 with BOM and line endings are LF; and that no
literal secret — password, token, key — has entered the repository.

---

## Licence and trademarks

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).

The SynSphere name and logo are not covered by the licence. Microsoft,
Microsoft 365, Azure, Entra, Intune, Purview, Defender, Exchange, SharePoint,
Teams and Windows are trademarks of the Microsoft group of companies; they are
used here referentially, to identify the products these scripts administer.
SynSphere Italia is not affiliated with or endorsed by Microsoft.

The scripts are provided **"as is"**, without warranties. Running them against
a production tenant is the responsibility of whoever runs them: read the
header, use `-WhatIf` where it exists, test on a narrow scope first.

---

**SynSphere Italia SRL** — [synsphere.it](https://synsphere.it) ·
[Get in touch](https://synsphere.it/contattaci) · Milan and Bolzano
