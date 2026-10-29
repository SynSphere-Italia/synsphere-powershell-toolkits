#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Export della matrice RBAC completa: principal × ruolo × scope (con livello di scope).
.DESCRIPTION
    Un unico CSV con tutte le assegnazioni arricchite dal LIVELLO di scope (Subscription /
    ResourceGroup / Resource): la vista completa per audit di sicurezza e compliance. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-RbacMatrix-<data>.csv
.EXAMPLE
    .\10-Export-AzRbacMatrix.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Reader + lettura roleAssignments. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-RbacMatrix-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

function Get-ScopeLevel($scope) {
    if ($scope -match '/resourceGroups/[^/]+/providers/') { 'Resource' }
    elseif ($scope -match '/resourceGroups/[^/]+$') { 'ResourceGroup' }
    elseif ($scope -match '^/subscriptions/[^/]+$') { 'Subscription' }
    elseif ($scope -match '/managementGroups/') { 'ManagementGroup' }
    else { 'Altro' }
}
$report = Get-AzRoleAssignment | ForEach-Object {
    [pscustomobject]@{
        Principal  = $_.DisplayName
        SignInName = $_.SignInName
        Tipo       = $_.ObjectType
        Ruolo      = $_.RoleDefinitionName
        LivelloScope = Get-ScopeLevel $_.Scope
        Scope      = $_.Scope
    }
}
$report | Sort-Object LivelloScope, Ruolo, Principal | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Matrice RBAC: {0} assegnazioni → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
