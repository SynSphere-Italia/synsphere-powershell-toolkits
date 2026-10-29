#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Inventario dei bilanciatori: Load Balancer e Application Gateway.
.DESCRIPTION
    Elenca Load Balancer (con SKU e regole) e Application Gateway (con SKU e listener):
    i punti di ingresso applicativi della rete. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-LoadBalancers-<data>.csv
.EXAMPLE
    .\07-Get-AzLoadBalancerInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-LoadBalancers-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = [System.Collections.Generic.List[object]]::new()
Get-AzLoadBalancer | ForEach-Object {
    $report.Add([pscustomobject]@{
        Tipo = 'Load Balancer'; Name = $_.Name; ResourceGroup = $_.ResourceGroupName
        Sku = $_.Sku.Name; Dettaglio = "$($_.LoadBalancingRules.Count) regole · $($_.BackendAddressPools.Count) backend pool"
    })
}
Get-AzApplicationGateway | ForEach-Object {
    $report.Add([pscustomobject]@{
        Tipo = 'Application Gateway'; Name = $_.Name; ResourceGroup = $_.ResourceGroupName
        Sku = $_.Sku.Name; Dettaglio = "$($_.HttpListeners.Count) listener · stato $($_.OperationalState)"
    })
}
$report | Sort-Object Tipo, Name | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} bilanciatori → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
