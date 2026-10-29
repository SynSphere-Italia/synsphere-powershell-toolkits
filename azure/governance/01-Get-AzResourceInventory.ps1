#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Inventario completo delle risorse Azure (su tutte le subscription o una sola).
.DESCRIPTION
    Esporta ogni risorsa con tipo, resource group, region, tag e subscription di
    appartenenza. È la fotografia di base per governance, audit e capacity planning.
    Sola lettura.
.PARAMETER SubscriptionId
    Opzionale: limita a una subscription. Default: tutte quelle accessibili.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-ResourceInventory-<data>.csv
.EXAMPLE
    .\01-Get-AzResourceInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [string]$SubscriptionId,
    [string]$OutputCsv = (".\Az-ResourceInventory-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$subs = if ($SubscriptionId) { Get-AzSubscription -SubscriptionId $SubscriptionId } else { Get-AzSubscription }
$report = foreach ($sub in $subs) {
    Set-AzContext -SubscriptionId $sub.Id | Out-Null
    foreach ($r in Get-AzResource) {
        [pscustomobject]@{
            Subscription  = $sub.Name
            Name          = $r.Name
            Type          = $r.ResourceType
            ResourceGroup = $r.ResourceGroupName
            Location      = $r.Location
            Tags          = if ($r.Tags) { ($r.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; ' } else { '' }
        }
    }
}
$report | Sort-Object Subscription, ResourceGroup, Name | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} risorse in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
