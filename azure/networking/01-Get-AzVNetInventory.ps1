#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Inventario delle reti virtuali (VNet) e relative subnet.
.DESCRIPTION
    Elenca ogni VNet con address space, region e l'elenco delle subnet (nome + prefisso):
    la mappa di base della topologia di rete. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-VNetInventory-<data>.csv
.EXAMPLE
    .\01-Get-AzVNetInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-VNetInventory-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($vnet in Get-AzVirtualNetwork) {
    foreach ($sub in $vnet.Subnets) {
        [pscustomobject]@{
            VNet          = $vnet.Name
            ResourceGroup = $vnet.ResourceGroupName
            Location      = $vnet.Location
            AddressSpace  = ($vnet.AddressSpace.AddressPrefixes -join ', ')
            Subnet        = $sub.Name
            SubnetPrefix  = ($sub.AddressPrefix -join ', ')
            NSG           = if ($sub.NetworkSecurityGroup) { ($sub.NetworkSecurityGroup.Id -split '/')[-1] } else { '(nessuno)' }
        }
    }
}
$report | Sort-Object VNet, Subnet | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} subnet → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
