#Requires -Modules Az.Accounts, Az.Billing
<#
.SYNOPSIS
    Anomalie di costo: servizi cresciuti rispetto allo stesso periodo del mese scorso.
.DESCRIPTION
    Confronta la spesa per servizio del mese corrente (month-to-date) con lo STESSO numero
    di giorni del mese precedente e segnala gli aumenti significativi: utile per intercettare
    spese impreviste. Sola lettura.
.PARAMETER ThresholdPercent
    Soglia di aumento da segnalare. Default: 30 (%).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-CostAnomalies-<data>.csv
.EXAMPLE
    .\09-Get-AzCostAnomalies.ps1 -ThresholdPercent 25
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Cost Management Reader / Billing Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [int]$ThresholdPercent = 30,
    [string]$OutputCsv = (".\Az-CostAnomalies-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$thisStart = (Get-Date -Day 1).Date
$today = (Get-Date).Date
$daysElapsed = ($today - $thisStart).Days + 1
$prevStart = $thisStart.AddMonths(-1)
$prevEnd = $prevStart.AddDays($daysElapsed - 1)

$sumByService = {
    param($from, $to)
    $h = @{}
    Get-AzConsumptionUsageDetail -StartDate $from -EndDate $to -ErrorAction Stop |
        Group-Object ConsumedService | ForEach-Object { $h[$_.Name] = ($_.Group | Measure-Object PretaxCost -Sum).Sum }
    $h
}
$cur = & $sumByService $thisStart $today
$prev = & $sumByService $prevStart $prevEnd

$report = foreach ($svc in $cur.Keys) {
    $c = [double]$cur[$svc]; $p = [double]$prev[$svc]
    $delta = $c - $p
    $pct = if ($p -gt 0) { [math]::Round(100 * $delta / $p, 1) } else { if ($c -gt 0) { 999 } else { 0 } }
    if ($pct -ge $ThresholdPercent -and $delta -gt 1) {
        [pscustomobject]@{ Servizio = $svc; MeseScorso = [math]::Round($p, 2); MeseCorrente = [math]::Round($c, 2); VariazionePct = "$pct%"; Delta = [math]::Round($delta, 2) }
    }
}
$report | Sort-Object Delta -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} servizi con aumento >= {1}% (stessi {2} giorni) → {3}" -f @($report).Count, $ThresholdPercent, $daysElapsed, $OutputCsv) -ForegroundColor Yellow
