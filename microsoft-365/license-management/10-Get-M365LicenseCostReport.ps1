#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report di spesa licenze per utente, in base a un listino prezzi configurabile.
.DESCRIPTION
    Calcola il costo mensile per utente sommando il prezzo dei suoi SKU. I prezzi
    sono SPECIFICI del tuo contratto (CSP/EA): vanno inseriti nel listino qui sotto
    o in un CSV (-PriceCsv con colonne SkuPartNumber,MonthlyPrice). Sola lettura.
.PARAMETER PriceCsv
    CSV opzionale con i prezzi (SkuPartNumber,MonthlyPrice). Se omesso usa $PriceMap.
.PARAMETER OutputCsv
    Percorso CSV di output. Default: .\M365-LicenseCost-<data>.csv
.EXAMPLE
    .\10-Get-M365LicenseCostReport.ps1 -PriceCsv .\listino.csv
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, Organization.Read.All
#>
[CmdletBinding()]
param(
    [string]$PriceCsv,
    [string]$OutputCsv = (".\M365-LicenseCost-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

# Listino DI ESEMPIO (€/utente/mese). SOSTITUISCI con i prezzi reali del tuo contratto.
$PriceMap = @{
    'O365_BUSINESS_ESSENTIALS' = 6.0    # Business Basic
    'O365_BUSINESS_PREMIUM'    = 12.9   # Business Standard
    'SPB'                      = 22.0   # Business Premium
    'SPE_E3'                   = 35.0   # Microsoft 365 E3
    'SPE_E5'                   = 57.0   # Microsoft 365 E5
}
if ($PriceCsv -and (Test-Path $PriceCsv)) {
    $PriceMap = @{}
    Import-Csv $PriceCsv | ForEach-Object { $PriceMap[$_.SkuPartNumber] = [double]$_.MonthlyPrice }
}

Connect-MgGraph -Scopes 'User.Read.All', 'Organization.Read.All' -NoWelcome
$skuMap = @{}; Get-MgSubscribedSku -All | ForEach-Object { $skuMap[$_.SkuId] = $_.SkuPartNumber }

$report = foreach ($user in Get-MgUser -All -Property DisplayName, UserPrincipalName, AssignedLicenses) {
    if (-not $user.AssignedLicenses) { continue }
    $parts = $user.AssignedLicenses | ForEach-Object { $skuMap[$_.SkuId] }
    $cost = ($parts | ForEach-Object { [double]($PriceMap[$_]) } | Measure-Object -Sum).Sum
    [pscustomobject]@{
        DisplayName       = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        Licenses          = $parts -join '; '
        MonthlyCostEUR    = [math]::Round($cost, 2)
    }
}

$report | Sort-Object MonthlyCostEUR -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$tot = ($report | Measure-Object MonthlyCostEUR -Sum).Sum
Write-Host ("Spesa mensile stimata: {0} EUR su {1} utenti → {2}" -f [math]::Round($tot, 2), $report.Count, $OutputCsv) -ForegroundColor Green
Write-Host "NB: i prezzi sono di esempio. Inserisci il tuo listino reale per un dato corretto." -ForegroundColor Yellow
