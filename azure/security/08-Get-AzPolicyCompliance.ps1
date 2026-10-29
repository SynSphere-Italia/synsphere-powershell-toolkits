#Requires -Modules Az.Accounts, Az.PolicyInsights
<#
.SYNOPSIS
    Stato di conformità ad Azure Policy: risorse non conformi raggruppate per policy.
.DESCRIPTION
    Azure Policy applica gli standard aziendali (naming, region consentite, tag, cifratura…).
    Lo script elenca le risorse NON conformi con la policy violata. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-PolicyCompliance-<data>.csv
.EXAMPLE
    .\08-Get-AzPolicyCompliance.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-PolicyCompliance-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$states = Get-AzPolicyState -Filter "ComplianceState eq 'NonCompliant'"
$report = $states | ForEach-Object {
    [pscustomobject]@{
        Policy        = $_.PolicyDefinitionName
        Assegnazione  = $_.PolicyAssignmentName
        Risorsa       = ($_.ResourceId -split '/')[-1]
        TipoRisorsa   = $_.ResourceType
        ResourceId    = $_.ResourceId
    }
} | Sort-Object Policy, Risorsa | Get-Unique -AsString
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} risorse non conformi alle policy → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
