#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Distribuzione delle risorse Azure per region (e per tipo).
.DESCRIPTION
    Mostra quante risorse hai in ogni region: utile per data residency, latenza e per
    individuare risorse "sparse" in region non previste. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-ResourcesByRegion-<data>.csv
.EXAMPLE
    .\07-Get-AzResourcesByRegion.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-ResourcesByRegion-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$all = Get-AzResource
$report = $all | Group-Object Location | ForEach-Object {
    [pscustomobject]@{
        Region    = $_.Name
        Risorse   = $_.Count
        TipiTop   = (($_.Group | Group-Object ResourceType | Sort-Object Count -Descending | Select-Object -First 3 |
                        ForEach-Object { "$($_.Name) ($($_.Count))" }) -join '; ')
    }
}
$report | Sort-Object Risorse -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} risorse in {1} region → {2}" -f $all.Count, $report.Count, $OutputCsv) -ForegroundColor Green
