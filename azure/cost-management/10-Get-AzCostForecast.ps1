#Requires -Modules Az.Accounts, Az.Billing
<#
.SYNOPSIS
    Forecast della spesa di fine mese (proiezione lineare dal month-to-date).
.DESCRIPTION
    Calcola la spesa dall'inizio del mese (MTD) e la proietta a fine mese in base ai giorni
    trascorsi: una stima rapida per capire se rientri nel budget. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-CostForecast-<data>.csv
.EXAMPLE
    .\10-Get-AzCostForecast.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Stima lineare (non considera stagionalità/spike). Permessi: Cost Management Reader.
    Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-CostForecast-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$start = (Get-Date -Day 1).Date
$today = (Get-Date).Date
$usage = Get-AzConsumptionUsageDetail -StartDate $start -EndDate $today -ErrorAction Stop
$mtd = [math]::Round(($usage | Measure-Object PretaxCost -Sum).Sum, 2)
$valuta = if ($usage) { $usage[0].Currency } else { '' }
$daysElapsed = ($today - $start).Days + 1
$daysInMonth = [DateTime]::DaysInMonth($today.Year, $today.Month)
$forecast = if ($daysElapsed -gt 0) { [math]::Round($mtd / $daysElapsed * $daysInMonth, 2) } else { 0 }

$report = [pscustomobject]@{
    Mese            = $today.ToString('yyyy-MM')
    SpesaMTD        = $mtd
    GiorniTrascorsi = "$daysElapsed / $daysInMonth"
    ForecastFineMese = $forecast
    Valuta          = $valuta
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$report | Format-List
Write-Host ("Forecast fine mese: {0} {1} (MTD {2}) → {3}" -f $forecast, $valuta, $mtd, $OutputCsv) -ForegroundColor Green
