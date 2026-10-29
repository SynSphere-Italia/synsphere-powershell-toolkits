#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Risorse di rete orfane: NIC, IP pubblici e NSG non associati.
.DESCRIPTION
    Schede di rete senza VM, IP pubblici senza associazione e NSG non collegati a subnet/NIC:
    residui da ripulire (alcuni anche a pagamento). Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-NetworkOrphans-<data>.csv
.EXAMPLE
    .\04-Get-AzNetworkOrphans.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-NetworkOrphans-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = [System.Collections.Generic.List[object]]::new()
Get-AzNetworkInterface | Where-Object { -not $_.VirtualMachine } | ForEach-Object {
    $report.Add([pscustomobject]@{ Tipo = 'NIC non collegata'; Name = $_.Name; ResourceGroup = $_.ResourceGroupName })
}
Get-AzPublicIpAddress | Where-Object { -not $_.IpConfiguration } | ForEach-Object {
    $report.Add([pscustomobject]@{ Tipo = 'IP pubblico inutilizzato'; Name = $_.Name; ResourceGroup = $_.ResourceGroupName })
}
Get-AzNetworkSecurityGroup | Where-Object { -not $_.Subnets -and -not $_.NetworkInterfaces } | ForEach-Object {
    $report.Add([pscustomobject]@{ Tipo = 'NSG non associato'; Name = $_.Name; ResourceGroup = $_.ResourceGroupName })
}
$report | Sort-Object Tipo, ResourceGroup | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} risorse di rete orfane → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
