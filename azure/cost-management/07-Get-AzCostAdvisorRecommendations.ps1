#Requires -Modules Az.Accounts, Az.Advisor
<#
.SYNOPSIS
    Raccomandazioni di risparmio di Azure Advisor (categoria Cost).
.DESCRIPTION
    Azure Advisor analizza l'ambiente e suggerisce risparmi concreti (rightsizing/shutdown
    VM sottoutilizzate, reserved instance, ecc.). Lo script esporta le raccomandazioni di
    categoria Cost con impatto e risorsa interessata. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-CostAdvisor-<data>.csv
.EXAMPLE
    .\07-Get-AzCostAdvisorRecommendations.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-CostAdvisor-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzAdvisorRecommendation -Category Cost | ForEach-Object {
    [pscustomobject]@{
        Impatto    = $_.Impact
        Problema   = $_.ShortDescriptionProblem
        Soluzione  = $_.ShortDescriptionSolution
        Risorsa    = ($_.ResourceId -split '/')[-1]
        ResourceId = $_.ResourceId
    }
}
$report | Sort-Object Impatto | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} raccomandazioni di risparmio Advisor → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Green
