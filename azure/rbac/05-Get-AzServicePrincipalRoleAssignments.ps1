#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Assegnazioni di ruolo dei service principal (app/automazioni) su Azure.
.DESCRIPTION
    App registration, managed identity e automazioni accumulano ruoli spesso dimenticati.
    Lo script elenca le assegnazioni il cui principal è un ServicePrincipal: utile per
    capire cosa può fare ogni automazione. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-SPRoleAssignments-<data>.csv
.EXAMPLE
    .\05-Get-AzServicePrincipalRoleAssignments.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Reader + lettura roleAssignments. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-SPRoleAssignments-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzRoleAssignment | Where-Object { $_.ObjectType -eq 'ServicePrincipal' } | ForEach-Object {
    [pscustomobject]@{
        ServicePrincipal = $_.DisplayName
        Ruolo            = $_.RoleDefinitionName
        Scope            = $_.Scope
        ObjectId         = $_.ObjectId
    }
}
$report | Sort-Object ServicePrincipal, Ruolo | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} assegnazioni a service principal → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
