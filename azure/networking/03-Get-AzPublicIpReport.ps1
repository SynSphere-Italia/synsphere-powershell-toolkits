#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Report degli indirizzi IP pubblici (con SKU, allocazione e risorsa associata).
.DESCRIPTION
    Elenca tutti gli IP pubblici, distinguendo Basic da Standard e statici da dinamici, con
    la risorsa a cui sono collegati. Utile per inventario di rete e controllo costi. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-PublicIp-<data>.csv
.EXAMPLE
    .\03-Get-AzPublicIpReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-PublicIp-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzPublicIpAddress | ForEach-Object {
    [pscustomobject]@{
        IPName        = $_.Name
        ResourceGroup = $_.ResourceGroupName
        Indirizzo     = $_.IpAddress
        Sku           = $_.Sku.Name
        Allocazione   = $_.PublicIpAllocationMethod
        Associato     = if ($_.IpConfiguration) { ($_.IpConfiguration.Id -split '/')[8] } else { '(non associato)' }
    }
}
$report | Sort-Object Associato, IPName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} IP pubblici → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
