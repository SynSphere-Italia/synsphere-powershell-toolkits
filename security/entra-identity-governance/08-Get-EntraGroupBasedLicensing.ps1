#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Gruppi con licenze assegnate (group-based licensing).
.DESCRIPTION
    Elenca i gruppi che assegnano licenze ai membri (group-based licensing) con i nomi degli
    SKU (risolti tramite gli SKU sottoscritti). È fondamentale per capire come vengono
    distribuite le licenze e per evitare doppie assegnazioni. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-GroupBasedLicensing-<data>.csv
.EXAMPLE
    .\08-Get-EntraGroupBasedLicensing.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All, Organization.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Entra-GroupBasedLicensing-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Group.Read.All', 'Organization.Read.All' -NoWelcome

# Mappa SkuId -> nome SKU leggibile (skuPartNumber)
$skuMap = @{}
Get-MgSubscribedSku -All | ForEach-Object { $skuMap[$_.SkuId] = $_.SkuPartNumber }

$report = foreach ($g in Get-MgGroup -All -Property Id, DisplayName, AssignedLicenses) {
    if (@($g.AssignedLicenses).Count -eq 0) { continue }
    $skus = ($g.AssignedLicenses | ForEach-Object { if ($skuMap.ContainsKey($_.SkuId)) { $skuMap[$_.SkuId] } else { $_.SkuId } }) -join '; '
    [pscustomobject]@{
        Gruppo     = $g.DisplayName
        Licenze    = $skus
        NumLicenze = @($g.AssignedLicenses).Count
    }
}

$report | Sort-Object Gruppo | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovati {0} gruppi con group-based licensing -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
