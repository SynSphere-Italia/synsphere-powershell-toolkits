#Requires -Modules Az.Accounts, Az.Advisor
<#
.SYNOPSIS
    VM candidate al rightsizing/shutdown (raccomandazioni di Azure Advisor).
.DESCRIPTION
    Azure Advisor identifica le VM sottoutilizzate da ridimensionare o spegnere: il modo
    più affidabile per risparmiare sul compute senza analisi manuali. Lo script estrae
    queste raccomandazioni. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-VmRightsizing-<data>.csv
.EXAMPLE
    .\02-Get-AzVmRightsizing.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-VmRightsizing-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzAdvisorRecommendation -Category Cost | Where-Object {
    $_.ImpactedField -match 'virtualMachines' -or $_.ShortDescriptionProblem -match 'right-?size|underutilized|shutdown|sottoutilizzat'
} | ForEach-Object {
    [pscustomobject]@{
        VM         = ($_.ResourceId -split '/')[-1]
        Impatto    = $_.Impact
        Problema   = $_.ShortDescriptionProblem
        Soluzione  = $_.ShortDescriptionSolution
        ResourceId = $_.ResourceId
    }
}
$report | Sort-Object Impatto | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} VM candidate a rightsizing/shutdown → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
