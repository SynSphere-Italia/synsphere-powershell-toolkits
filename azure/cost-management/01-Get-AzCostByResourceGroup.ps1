#Requires -Modules Az.Accounts, Az.Billing
<#
.SYNOPSIS
    Costo del periodo per resource group (default: mese corrente).
.DESCRIPTION
    Aggrega il consumo (Get-AzConsumptionUsageDetail) e somma il costo pre-tasse per
    resource group: la prima vista per capire DOVE vanno i soldi. Sola lettura.
.PARAMETER StartDate
    Inizio periodo. Default: primo giorno del mese corrente.
.PARAMETER EndDate
    Fine periodo. Default: oggi.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-CostByRG-<data>.csv
.EXAMPLE
    .\01-Get-AzCostByResourceGroup.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Cost Management Reader / Billing Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [datetime]$StartDate = (Get-Date -Day 1).Date,
    [datetime]$EndDate = (Get-Date).Date,
    [string]$OutputCsv = (".\Az-CostByRG-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$usage = Get-AzConsumptionUsageDetail -StartDate $StartDate -EndDate $EndDate -ErrorAction Stop
$report = $usage | Group-Object { if ($_.InstanceId -match '/resourceGroups/([^/]+)') { $matches[1].ToLower() } else { '(nessuno)' } } |
    ForEach-Object {
        [pscustomobject]@{
            ResourceGroup = $_.Name
            Costo         = [math]::Round(($_.Group | Measure-Object PretaxCost -Sum).Sum, 2)
            Valuta        = $_.Group[0].Currency
        }
    }
$report | Sort-Object Costo -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$tot = [math]::Round(($usage | Measure-Object PretaxCost -Sum).Sum, 2)
Write-Host ("Costo totale {0} → {1} ({2}) su {3} resource group → {4}" -f $StartDate.ToString('dd/MM'), $tot, $report[0].Valuta, $report.Count, $OutputCsv) -ForegroundColor Green
