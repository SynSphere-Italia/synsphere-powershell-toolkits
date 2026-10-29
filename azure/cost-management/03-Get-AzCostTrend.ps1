#Requires -Modules Az.Accounts, Az.Billing
<#
.SYNOPSIS
    Trend di costo degli ultimi N mesi (per mese di fatturazione).
.DESCRIPTION
    Mostra l'andamento mensile della spesa: utile per vedere se i costi crescono e di
    quanto. Sola lettura.
.PARAMETER Months
    Numero di mesi indietro. Default: 6.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-CostTrend-<data>.csv
.EXAMPLE
    .\03-Get-AzCostTrend.ps1 -Months 12
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Cost Management Reader / Billing Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [int]$Months = 6,
    [string]$OutputCsv = (".\Az-CostTrend-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$start = (Get-Date -Day 1).AddMonths(-$Months + 1).Date
$usage = Get-AzConsumptionUsageDetail -StartDate $start -EndDate (Get-Date).Date -ErrorAction Stop
$report = $usage | Group-Object { ([datetime]$_.UsageStart).ToString('yyyy-MM') } | ForEach-Object {
    [pscustomobject]@{
        Mese   = $_.Name
        Costo  = [math]::Round(($_.Group | Measure-Object PretaxCost -Sum).Sum, 2)
        Valuta = $_.Group[0].Currency
    }
}
$report | Sort-Object Mese | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$report | Sort-Object Mese | Format-Table -AutoSize
Write-Host ("Trend {0} mesi → {1}" -f $Months, $OutputCsv) -ForegroundColor Green
