# Azure network inventory and audit

Ten read-only scripts that photograph the network side of an Azure subscription — VNets, NSGs, public IPs, peerings, load balancers, DNS, route tables — and write it out as CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

This is for the IT administrator, the engineer at an MSP and the network admin who have to document the network of an Azure environment without touching it: work out what the topology really is, which NSG rules are in force, which public IPs are exposed, where traffic is diverted. The typical scenario is taking over an environment nobody ever documented, or the periodic check before a piece of work or a change review.

None of the ten scripts changes anything in Azure: they use `Get-*` cmdlets only, and the one thing they produce is a CSV file on the machine you run them from.

## The scripts

| File | What it does | Reads / Writes |
|------|--------------|----------------|
| `01-Get-AzVNetInventory.ps1` | Inventory of the VNets and their subnets: address space, region, name and prefix of every subnet, and the NSG attached to the subnet (`(nessuno)` when there is none). The base map of the topology. | Read-only |
| `02-Export-AzNsgRules.ps1` | Exports every custom NSG rule in the subscription, with priority, direction, action, protocol, source, destination and ports: the complete network documentation, for audits and change reviews. | Read-only |
| `03-Get-AzPublicIpReport.ps1` | Every public IP address with its SKU (Basic or Standard), allocation method (static or dynamic) and the resource it is attached to. An inventory of your exposure, and a cost check. | Read-only |
| `04-Get-AzNetworkOrphans.ps1` | Orphaned network resources: NICs with no VM, public IPs with no association, NSGs attached to neither a subnet nor a NIC. Leftovers to clean up, some of which you are paying for. | Read-only |
| `05-Get-AzVNetPeering.ps1` | The peerings of each VNet with the connection state and the options in force (forwarded traffic, gateway transit, use of the remote gateway). Used to read a hub-and-spoke topology and to diagnose connectivity problems. | Read-only |
| `06-Get-AzEffectiveNsgRules.ps1` | The **effective** NSG rules on a single NIC, that is the combination of the subnet NSG and the NIC NSG: what is really allowed or denied on that interface. Requires `-NetworkInterfaceName` and `-ResourceGroupName`. This is the connectivity troubleshooting tool. | Read-only (but read warnings 2 and 3) |
| `07-Get-AzLoadBalancerInventory.ps1` | Load Balancers (SKU, number of rules and backend pools) and Application Gateways (SKU, number of listeners, operational state): the network's application entry points. | Read-only |
| `08-Get-AzSubnetsWithoutNsg.ps1` | Subnets with no NSG attached, that is with no traffic filtering. The code leaves the system subnets out of the report: `GatewaySubnet`, `AzureFirewallSubnet`, `AzureFirewallManagementSubnet`, `AzureBastionSubnet`, `RouteServerSubnet`. | Read-only |
| `09-Export-AzDnsRecords.ps1` | **Public** DNS zones and all their records with TTLs and values. A, AAAA, CNAME, MX, NS and TXT are rendered readably; the other types land in the cell as compact JSON. *Private* DNS zones are not included. | Read-only |
| `10-Get-AzRouteTables.ps1` | Route tables (UDRs) with every route — prefix, next hop type, next hop IP — and the subnets the table is attached to. Used to work out where traffic is diverted, to a firewall for instance. | Read-only |

## Before you run them

- **PowerShell version: none of the ten scripts declares one.** There is no `#Requires -Version` directive in any of them. The kit's old instruction file stated "PowerShell 5.1 or PowerShell 7", but the code does not enforce it: on a different version the scripts start anyway, and any error turns up later.
- **Modules.** The `#Requires -Modules` directives at the top of the scripts name three, and those three cover everything. A script that cannot find its module refuses to start:

  ```powershell
  Install-Module Az.Accounts -Scope CurrentUser   # required by all ten
  Install-Module Az.Network  -Scope CurrentUser   # required by nine: all but 09
  Install-Module Az.Dns      -Scope CurrentUser   # required by 09 only
  ```

  Alternatively, `Install-Module Az -Scope CurrentUser` installs the whole suite, which includes them. Private DNS zones would need `Az.PrivateDns`, but no script in this folder uses it: private zones stay out of the report.
- **Interactive authentication:** `Connect-AzAccount`. Each script checks the context and, if it finds none, opens the sign-in itself. There is no service principal, no certificate and no secret in the code; no Microsoft Graph permission is needed.
- **Permissions: the Azure RBAC Reader role is enough for nine scripts out of ten.** The tenth, `06-Get-AzEffectiveNsgRules.ps1`, additionally needs the `Microsoft.Network/networkInterfaces/effectiveNetworkSecurityGroups/action` action: the Network Contributor role grants it, as does a custom role containing just that action. The reason is in warning 2.
- **For 06 only: the VM attached to the NIC must be running**, otherwise the effective rules do not exist and there is nothing to read.

## ⚠️ Warnings

1. **The report covers the active subscription only, and the CSV does not say which one it was.** None of the ten scripts selects a subscription: they take whatever `Get-AzContext` returns at launch, and none of the exported columns carries the subscription or the tenant the data came from. Two consequences follow. If you administer several environments, two CSVs produced at different times are indistinguishable by eye, and a report can end up attributed to the wrong environment. And if the environment has several subscriptions, the report photographs one of them and still looks complete. On top of that, ARM list calls return only the resources you hold an assignment on: with Reader on a single resource group, `Get-AzVirtualNetwork` does not fail, it returns less. That is what makes the two "negative" reports misleading above all: `0 subnet senza NSG` and `0 risorse di rete orfane` read as good news, but they may mean "zero among the ones you can see". Before you launch, print the context, pick the environment explicitly, and then rename the CSV to carry the subscription name.

```powershell
Get-AzContext | Select-Object Name, Subscription, Tenant
Get-AzSubscription                            # every one you have access to
Set-AzContext -Subscription '<name-or-id>'
```

2. **Script 06 does not run under the Reader role alone, whatever its own header says.** The `.NOTES` block of all ten scripts, and the old instruction file, state "Permessi: ruolo Reader": true for nine of them, not for `06-Get-AzEffectiveNsgRules.ps1`. The `Get-AzEffectiveNetworkSecurityGroup` cmdlet requires `Microsoft.Network/networkInterfaces/effectiveNetworkSecurityGroups/action`, which Azure classifies as an *action* and not as a read operation, while the built-in Reader role grants `*/read` only. Under plain Reader that script stops with `AuthorizationFailed` — an error the kit's own documentation tells you cannot happen, so you will go looking for it in the wrong place. For 06, assign Network Contributor, or a custom role that includes that action.

3. **The CSVs are confidential documentation: in clear text they hold what it takes to attack that network.** Taken together, the ten exports contain the complete NSG rules with sources, destinations and ports (02 and 06), the real public IP addresses (03), the entire contents of the public DNS zones record by record (09) and the route tables with their next hop IPs (10). The default path is the current directory, that is the folder you opened the shell in: on a company machine that is often a cloud-synced folder, and the export lands there without anybody asking for it. Decide where they go with `-OutputCsv`, treat them as a customer's network documentation, and do not leave them where they were created.

4. **They are all or nothing: if anything goes wrong, no CSV is written at all.** None of the ten scripts has a `try/catch`, and all of them set `$ErrorActionPreference = 'Stop'`. Since `Export-Csv` is the last statement in all ten, an inaccessible resource group or an unregistered provider halts the run before the write: you do not get a partial report, you get a raw ARM exception and no file. The worst case is `09-Export-AzDnsRecords.ps1`, which loops zone by zone: a single unreadable zone throws away the work done on all the others. The scripts expose no parameter for narrowing the perimeter — the only one that works on a single object is 06, on one NIC — so if the error keeps coming back on the same object, your only lever is the context: the subscription you selected, and what your account can see.

5. **Two runs on the same day: the second overwrites the first, silently.** The default name carries the date only (`yyyyMMdd`) and `Export-Csv` is called without `-NoClobber` in all ten scripts. Run the same script again after changing something and the earlier CSV is gone, with no message to tell you. If you need a "before" and an "after" — the usual case when you are fixing a network — pass `-OutputCsv` with two different names.

## Where the output goes

All ten scripts export a CSV in UTF-8, with no type line, and in all ten the path is the `-OutputCsv` parameter. The default names are `Az-VNetInventory-<yyyyMMdd>.csv` and, on the same pattern, `Az-NsgRules-`, `Az-PublicIp-`, `Az-NetworkOrphans-`, `Az-VNetPeering-`, `Az-EffectiveNsg-`, `Az-LoadBalancers-`, `Az-SubnetsNoNsg-`, `Az-DnsRecords-`, `Az-RouteTables-`. Three things are worth knowing:

- **The file is created where the prompt is, not next to the script.** The default is `.\`, that is the current directory at launch. If you cloned this repository and run from inside the clone, the CSV is created **inside the clone**: the root `.gitignore` excludes `*.csv`, but look at `git status` before you commit rather than trusting it. With an explicit `-OutputCsv` the question does not arise. The parameter is a bare string with no validation: a path that does not exist is not flagged up front, the error arrives at the end, once all the data has already been collected.
- **The name carries only the date, and there is no `-NoClobber`:** a second run on the same day overwrites the previous one without asking (warning 5).
- **The contents are sensitive, not scrap.** Complete NSG rules with sources, destinations and ports; real public IP addresses; every record of the public DNS zones; the next hop IPs of the route tables. Anyone reading these files knows how the network is built and where it is open: keep them the way you keep a customer's network documentation.

## Examples

```powershell
# First of all: sign in and check which environment you are working on (warning 1)
Connect-AzAccount
Get-AzContext | Select-Object Name, Subscription, Tenant

# VNet and subnet inventory
.\01-Get-AzVNetInventory.ps1

# Every NSG rule, to a path of your choosing
.\02-Export-AzNsgRules.ps1 -OutputCsv D:\Audit\NsgRules.csv

# Effective rules on a NIC: the VM must be running, and Reader is not enough (warnings 2 and 3)
.\06-Get-AzEffectiveNsgRules.ps1 -NetworkInterfaceName nic-web01 -ResourceGroupName rg-prod

# Public DNS zones and records
.\09-Export-AzDnsRecords.ps1
```

## More

The same content is available as a ZIP from [synsphere.it/download/toolkit-powershell-azure-networking](https://synsphere.it/download/toolkit-powershell-azure-networking/); the guide that goes with the kit is [here](https://synsphere.it/notizie/script-powershell-azure-networking-toolkit-pmi/), in Italian. If you need a hand: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
