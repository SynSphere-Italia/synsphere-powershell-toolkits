#Requires -Modules Az.Accounts, Az.Compute, Az.Network
<#
.SYNOPSIS
    Risorse idle/orfane che generano costo inutile (dischi, IP pubblici).
.DESCRIPTION
    Individua le risorse che costano senza essere usate: dischi managed non collegati
    (paghi lo storage) e indirizzi IP pubblici Standard non associati (paghi l'IP).
    Sono i tagli di costo più rapidi. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-IdleCostlyResources-<data>.csv
.EXAMPLE
    .\05-Get-AzIdleCostlyResources.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-IdleCostlyResources-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = [System.Collections.Generic.List[object]]::new()
Get-AzDisk | Where-Object { $_.DiskState -eq 'Unattached' -or -not $_.ManagedBy } | ForEach-Object {
    $report.Add([pscustomobject]@{
        Tipo = 'Disco non collegato'; Name = $_.Name; ResourceGroup = $_.ResourceGroupName
        Dettaglio = "$($_.DiskSizeGB) GB · $($_.Sku.Name)"; Location = $_.Location
    })
}
Get-AzPublicIpAddress | Where-Object { -not $_.IpConfiguration } | ForEach-Object {
    $report.Add([pscustomobject]@{
        Tipo = 'IP pubblico inutilizzato'; Name = $_.Name; ResourceGroup = $_.ResourceGroupName
        Dettaglio = "$($_.Sku.Name) · $($_.PublicIpAllocationMethod)"; Location = $_.Location
    })
}
$report | Sort-Object Tipo, ResourceGroup | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} risorse idle che costano → {1}. Valuta l'eliminazione." -f $report.Count, $OutputCsv) -ForegroundColor Yellow
