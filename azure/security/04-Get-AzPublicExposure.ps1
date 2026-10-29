#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Mappa dell'esposizione pubblica: indirizzi IP pubblici e risorsa a cui sono associati.
.DESCRIPTION
    Ogni IP pubblico è una potenziale superficie d'attacco. Lo script elenca tutti gli IP
    pubblici, se sono associati e a quale risorsa (VM, load balancer, gateway…). Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-PublicExposure-<data>.csv
.EXAMPLE
    .\04-Get-AzPublicExposure.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-PublicExposure-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzPublicIpAddress | ForEach-Object {
    $assocId = $_.IpConfiguration.Id
    $assoc = if ($assocId) { ($assocId -split '/')[8] } else { '(non associato)' }
    [pscustomobject]@{
        IPName        = $_.Name
        Indirizzo     = $_.IpAddress
        Sku           = $_.Sku.Name
        Allocazione   = $_.PublicIpAllocationMethod
        AssociatoA    = $assoc
        ResourceGroup = $_.ResourceGroupName
    }
}
$report | Sort-Object AssociatoA, IPName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} IP pubblici (superficie d'attacco) → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
