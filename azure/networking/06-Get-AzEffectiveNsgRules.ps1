#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Regole NSG EFFETTIVE applicate a una scheda di rete (NIC).
.DESCRIPTION
    Le regole effettive combinano NSG di subnet e NSG di NIC e mostrano cosa è davvero
    permesso/negato su quella scheda: lo strumento definitivo per il troubleshooting di
    connettività. Sola lettura. NB: la VM associata deve essere AVVIATA.
.PARAMETER NetworkInterfaceName
    Nome della NIC (obbligatorio).
.PARAMETER ResourceGroupName
    Resource group della NIC (obbligatorio).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-EffectiveNsg-<data>.csv
.EXAMPLE
    .\06-Get-AzEffectiveNsgRules.ps1 -NetworkInterfaceName nic-web01 -ResourceGroupName rg-prod
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$NetworkInterfaceName,
    [Parameter(Mandatory)][string]$ResourceGroupName,
    [string]$OutputCsv = (".\Az-EffectiveNsg-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$eff = Get-AzEffectiveNetworkSecurityGroup -NetworkInterfaceName $NetworkInterfaceName -ResourceGroupName $ResourceGroupName
$report = foreach ($nsg in $eff) {
    foreach ($r in $nsg.EffectiveSecurityRules) {
        [pscustomobject]@{
            Regola      = $r.Name
            Priorita    = $r.Priority
            Direzione   = $r.Direction
            Azione      = $r.Access
            Protocollo  = $r.Protocol
            Sorgente    = ($r.SourceAddressPrefix -join ',')
            Destinazione = ($r.DestinationAddressPrefix -join ',')
            PorteDest   = ($r.DestinationPortRange -join ',')
        }
    }
}
$report | Sort-Object Direzione, Priorita | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} regole effettive su {1} → {2}" -f @($report).Count, $NetworkInterfaceName, $OutputCsv) -ForegroundColor Green
