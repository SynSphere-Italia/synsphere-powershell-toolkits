#Requires -Modules Az.Accounts, Az.Security
<#
.SYNOPSIS
    Raccomandazioni di sicurezza non risolte (assessment "unhealthy") di Defender for Cloud.
.DESCRIPTION
    Esporta gli assessment di sicurezza in stato non integro: la to-do list di hardening
    prioritizzabile. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-SecurityRecommendations-<data>.csv
.EXAMPLE
    .\02-Get-AzSecurityRecommendations.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Richiede Defender for Cloud attivo. Permessi: Security Reader. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-SecurityRecommendations-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzSecurityAssessment | Where-Object { $_.Status.Code -ne 'Healthy' } | ForEach-Object {
    [pscustomobject]@{
        Raccomandazione = $_.DisplayName
        Stato           = $_.Status.Code
        Severita        = $_.Status.Severity
        Risorsa         = ($_.ResourceDetails.Id -split '/')[-1]
        ResourceId      = $_.ResourceDetails.Id
    }
}
$report | Sort-Object Severita, Raccomandazione | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} raccomandazioni di sicurezza aperte → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
