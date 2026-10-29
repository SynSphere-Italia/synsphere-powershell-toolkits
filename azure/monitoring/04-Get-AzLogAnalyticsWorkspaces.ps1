#Requires -Modules Az.Accounts, Az.OperationalInsights
<#
.SYNOPSIS
    Inventario dei workspace Log Analytics (SKU, retention, region).
.DESCRIPTION
    I workspace Log Analytics raccolgono log e metriche. Questo report mostra SKU, giorni di
    retention e region: utile per controllo costi (retention lunga = costo) e per evitare
    workspace duplicati. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-LogAnalytics-<data>.csv
.EXAMPLE
    .\04-Get-AzLogAnalyticsWorkspaces.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-LogAnalytics-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzOperationalInsightsWorkspace | ForEach-Object {
    [pscustomobject]@{
        Workspace     = $_.Name
        ResourceGroup = $_.ResourceGroupName
        Location      = $_.Location
        Sku           = $_.Sku
        RetentionGiorni = $_.RetentionInDays
    }
}
$report | Sort-Object Workspace | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} workspace Log Analytics → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Green
