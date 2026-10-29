#Requires -Modules Az.Accounts, Az.Consumption
<#
.SYNOPSIS
    Stato dei budget Azure: importo, spesa corrente e percentuale di utilizzo.
.DESCRIPTION
    Elenca i budget configurati sulla subscription con la spesa corrente e la % rispetto
    al limite: per sapere a colpo d'occhio se stai per sforare. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-BudgetStatus-<data>.csv
.EXAMPLE
    .\08-Get-AzBudgetStatus.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Cost Management Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-BudgetStatus-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$budgets = Get-AzConsumptionBudget
if (-not $budgets) { Write-Host "Nessun budget configurato sulla subscription." -ForegroundColor Yellow; return }
$report = foreach ($b in $budgets) {
    $spent = [double]$b.CurrentSpend.Amount
    $pct = if ($b.Amount -gt 0) { [math]::Round(100 * $spent / $b.Amount, 1) } else { 0 }
    [pscustomobject]@{
        Budget    = $b.Name
        Limite    = $b.Amount
        Speso     = [math]::Round($spent, 2)
        Percent   = "$pct%"
        TimeGrain = $b.TimeGrain
        Valuta    = $b.CurrentSpend.Unit
    }
}
$report | Sort-Object Percent -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$report | Format-Table -AutoSize
Write-Host ("Stato budget → {0}" -f $OutputCsv) -ForegroundColor Green
