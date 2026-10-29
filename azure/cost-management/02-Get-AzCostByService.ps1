#Requires -Modules Az.Accounts, Az.Billing
<#
.SYNOPSIS
    Costo del periodo per servizio Azure (Compute, Storage, Networking, SQL, ...).
.DESCRIPTION
    Aggrega il consumo per servizio consumato (ConsumedService): mostra quali servizi
    pesano di più sulla bolletta. Sola lettura.
.PARAMETER StartDate
    Inizio periodo. Default: primo giorno del mese corrente.
.PARAMETER EndDate
    Fine periodo. Default: oggi.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-CostByService-<data>.csv
.EXAMPLE
    .\02-Get-AzCostByService.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Cost Management Reader / Billing Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [datetime]$StartDate = (Get-Date -Day 1).Date,
    [datetime]$EndDate = (Get-Date).Date,
    [string]$OutputCsv = (".\Az-CostByService-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$usage = Get-AzConsumptionUsageDetail -StartDate $StartDate -EndDate $EndDate -ErrorAction Stop
$report = $usage | Group-Object ConsumedService | ForEach-Object {
    [pscustomobject]@{
        Servizio = if ($_.Name) { $_.Name } else { '(non specificato)' }
        Costo    = [math]::Round(($_.Group | Measure-Object PretaxCost -Sum).Sum, 2)
        Valuta   = $_.Group[0].Currency
    }
}
$report | Sort-Object Costo -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$report | Sort-Object Costo -Descending | Select-Object -First 8 | Format-Table -AutoSize
Write-Host ("Costo per servizio → {0}" -f $OutputCsv) -ForegroundColor Green
