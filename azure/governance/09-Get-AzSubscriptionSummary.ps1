#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Riepilogo per subscription: numero di risorse, resource group e region.
.DESCRIPTION
    Vista d'insieme di tutte le subscription accessibili — quante risorse, quanti
    resource group e in quante region — per orientarsi rapidamente in tenant multi-sub.
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-SubscriptionSummary-<data>.csv
.EXAMPLE
    .\09-Get-AzSubscriptionSummary.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader sulle subscription. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-SubscriptionSummary-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($sub in Get-AzSubscription) {
    Set-AzContext -SubscriptionId $sub.Id | Out-Null
    $res = Get-AzResource
    [pscustomobject]@{
        Subscription   = $sub.Name
        State          = $sub.State
        Risorse        = $res.Count
        ResourceGroup  = (Get-AzResourceGroup).Count
        Region         = ($res.Location | Sort-Object -Unique).Count
    }
}
$report | Sort-Object Risorse -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$report | Format-Table -AutoSize
Write-Host ("Esportate {0} subscription in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
