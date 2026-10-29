#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Export completo di TUTTE le regole NSG (custom) della subscription.
.DESCRIPTION
    Esporta ogni regola di sicurezza di ogni NSG con direzione, azione, protocollo, sorgente,
    destinazione e porte: la documentazione di rete completa, utile per audit e change review.
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-NsgRules-<data>.csv
.EXAMPLE
    .\02-Export-AzNsgRules.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-NsgRules-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($nsg in Get-AzNetworkSecurityGroup) {
    foreach ($r in $nsg.SecurityRules) {
        [pscustomobject]@{
            NSG          = $nsg.Name
            ResourceGroup = $nsg.ResourceGroupName
            Regola       = $r.Name
            Priorita     = $r.Priority
            Direzione    = $r.Direction
            Azione       = $r.Access
            Protocollo   = $r.Protocol
            Sorgente     = ((@($r.SourceAddressPrefix) + @($r.SourceAddressPrefixes)) -join ',')
            PorteSorgente = ((@($r.SourcePortRange) + @($r.SourcePortRanges)) -join ',')
            Destinazione = ((@($r.DestinationAddressPrefix) + @($r.DestinationAddressPrefixes)) -join ',')
            PorteDest    = ((@($r.DestinationPortRange) + @($r.DestinationPortRanges)) -join ',')
        }
    }
}
$report | Sort-Object NSG, Priorita | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} regole NSG → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
