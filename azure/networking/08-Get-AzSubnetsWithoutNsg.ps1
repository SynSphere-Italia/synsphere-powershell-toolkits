#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Subnet SENZA un NSG associato (gap di sicurezza di rete).
.DESCRIPTION
    Una subnet senza NSG non filtra il traffico: best practice è proteggerle tutte (con le
    eccezioni di GatewaySubnet/AzureFirewallSubnet/AzureBastionSubnet, escluse dal report).
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-SubnetsNoNsg-<data>.csv
.EXAMPLE
    .\08-Get-AzSubnetsWithoutNsg.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-SubnetsNoNsg-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$skip = 'GatewaySubnet', 'AzureFirewallSubnet', 'AzureBastionSubnet', 'AzureFirewallManagementSubnet', 'RouteServerSubnet'
$report = foreach ($vnet in Get-AzVirtualNetwork) {
    foreach ($sub in $vnet.Subnets) {
        if ($sub.Name -in $skip) { continue }
        if (-not $sub.NetworkSecurityGroup) {
            [pscustomobject]@{ VNet = $vnet.Name; ResourceGroup = $vnet.ResourceGroupName; Subnet = $sub.Name; Prefix = ($sub.AddressPrefix -join ',') }
        }
    }
}
$report | Sort-Object VNet, Subnet | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} subnet senza NSG → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
