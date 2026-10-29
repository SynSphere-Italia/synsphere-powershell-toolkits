#Requires -Modules Az.Accounts, Az.Advisor
<#
.SYNOPSIS
    Raccomandazioni Advisor di eccellenza operativa e alta affidabilità.
.DESCRIPTION
    Azure Advisor suggerisce migliorie di operational excellence e reliability (best practice,
    ridondanza, configurazioni a rischio). Lo script le esporta come backlog di miglioramento
    operativo. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-OpsRecommendations-<data>.csv
.EXAMPLE
    .\10-Get-AzOperationalRecommendations.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-OpsRecommendations-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = [System.Collections.Generic.List[object]]::new()
foreach ($cat in 'OperationalExcellence', 'HighAvailability') {
    try {
        Get-AzAdvisorRecommendation -Category $cat | ForEach-Object {
            $report.Add([pscustomobject]@{
                Categoria  = $cat
                Impatto    = $_.Impact
                Problema   = $_.ShortDescriptionProblem
                Soluzione  = $_.ShortDescriptionSolution
                Risorsa    = ($_.ResourceId -split '/')[-1]
            })
        }
    } catch { Write-Warning "$cat : $($_.Exception.Message)" }
}
$report | Sort-Object Categoria, Impatto | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} raccomandazioni operative Advisor → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
