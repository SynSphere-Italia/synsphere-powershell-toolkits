#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Report di tutte le assegnazioni di ruolo RBAC della subscription.
.DESCRIPTION
    Esporta chi ha quale ruolo e su quale scope (subscription, resource group, risorsa):
    la base di ogni audit degli accessi su Azure. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-RoleAssignments-<data>.csv
.EXAMPLE
    .\01-Get-AzRoleAssignmentReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Reader + Microsoft.Authorization/roleAssignments/read. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-RoleAssignments-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzRoleAssignment | ForEach-Object {
    [pscustomobject]@{
        Principal   = $_.DisplayName
        SignInName  = $_.SignInName
        Tipo        = $_.ObjectType
        Ruolo       = $_.RoleDefinitionName
        Scope       = $_.Scope
    }
}
$report | Sort-Object Ruolo, Principal | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} assegnazioni di ruolo in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
