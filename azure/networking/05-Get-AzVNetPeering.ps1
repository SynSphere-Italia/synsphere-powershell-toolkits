#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Report dei peering tra reti virtuali (stato e impostazioni).
.DESCRIPTION
    Elenca i peering di ogni VNet con lo stato di connessione e le opzioni (traffico inoltrato,
    gateway transit, accesso alla rete virtuale). Utile per capire la topologia hub-spoke e
    diagnosticare problemi di connettività. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-VNetPeering-<data>.csv
.EXAMPLE
    .\05-Get-AzVNetPeering.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-VNetPeering-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($vnet in Get-AzVirtualNetwork) {
    foreach ($p in $vnet.VirtualNetworkPeerings) {
        [pscustomobject]@{
            VNet           = $vnet.Name
            Peering        = $p.Name
            Stato          = $p.PeeringState
            RemoteVNet     = ($p.RemoteVirtualNetwork.Id -split '/')[-1]
            TrafficoInoltrato = $p.AllowForwardedTraffic
            GatewayTransit = $p.AllowGatewayTransit
            UseRemoteGw    = $p.UseRemoteGateways
        }
    }
}
$report | Sort-Object VNet, Peering | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} peering → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Green
