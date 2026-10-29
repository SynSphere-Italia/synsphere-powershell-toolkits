#Requires -Modules Az.Accounts, Az.Billing
<#
.SYNOPSIS
    Le N risorse più costose del periodo (default mese corrente).
.DESCRIPTION
    Classifica le singole risorse per costo: individua subito i "big spender" su cui
    concentrare l'ottimizzazione. Sola lettura.
.PARAMETER Top
    Quante risorse mostrare. Default: 25.
.PARAMETER StartDate
    Inizio periodo. Default: primo giorno del mese corrente.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-TopCostResources-<data>.csv
.EXAMPLE
    .\04-Get-AzTopCostResources.ps1 -Top 50
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Cost Management Reader / Billing Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [int]$Top = 25,
    [datetime]$StartDate = (Get-Date -Day 1).Date,
    [string]$OutputCsv = (".\Az-TopCostResources-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$usage = Get-AzConsumptionUsageDetail -StartDate $StartDate -EndDate (Get-Date).Date -ErrorAction Stop
$report = $usage | Group-Object InstanceId | ForEach-Object {
    $rg = if ($_.Name -match '/resourceGroups/([^/]+)') { $matches[1] } else { '' }
    [pscustomobject]@{
        Risorsa       = ($_.Name -split '/')[-1]
        ResourceGroup = $rg
        Costo         = [math]::Round(($_.Group | Measure-Object PretaxCost -Sum).Sum, 2)
        Valuta        = $_.Group[0].Currency
    }
} | Sort-Object Costo -Descending | Select-Object -First $Top
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Top {0} risorse per costo → {1}" -f $Top, $OutputCsv) -ForegroundColor Green
