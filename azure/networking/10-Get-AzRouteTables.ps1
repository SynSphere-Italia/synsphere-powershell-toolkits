#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Inventario delle route table (UDR) e delle rotte personalizzate.
.DESCRIPTION
    Le user-defined route deviano il traffico (es. verso una NVA/firewall). Lo script elenca
    ogni route table con le sue rotte (prefisso, next hop) e le subnet associate: utile per
    capire i percorsi di rete e diagnosticare problemi. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-RouteTables-<data>.csv
.EXAMPLE
    .\10-Get-AzRouteTables.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-RouteTables-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($rt in Get-AzRouteTable) {
    $subnets = if ($rt.Subnets) { ($rt.Subnets.Id | ForEach-Object { ($_ -split '/')[-1] }) -join ', ' } else { '(nessuna)' }
    if ($rt.Routes) {
        foreach ($r in $rt.Routes) {
            [pscustomobject]@{
                RouteTable = $rt.Name; ResourceGroup = $rt.ResourceGroupName
                Rotta = $r.Name; Prefisso = $r.AddressPrefix; NextHop = $r.NextHopType
                NextHopIp = $r.NextHopIpAddress; SubnetAssociate = $subnets
            }
        }
    } else {
        [pscustomobject]@{ RouteTable = $rt.Name; ResourceGroup = $rt.ResourceGroupName; Rotta = '(nessuna rotta)'; Prefisso = ''; NextHop = ''; NextHopIp = ''; SubnetAssociate = $subnets }
    }
}
$report | Sort-Object RouteTable, Prefisso | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Route table esportate → {0}" -f $OutputCsv) -ForegroundColor Green
