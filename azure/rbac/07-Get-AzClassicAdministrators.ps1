#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Report dei classic administrator (Co-Administrator / Service Administrator).
.DESCRIPTION
    I ruoli "classic" (Azure Service Management) hanno privilegi ampi e sono un retaggio
    da bonificare a favore del solo RBAC. Lo script li elenca. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-ClassicAdmins-<data>.csv
.EXAMPLE
    .\07-Get-AzClassicAdministrators.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Reader + lettura roleAssignments. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-ClassicAdmins-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzRoleAssignment -IncludeClassicAdministrators |
    Where-Object { $_.RoleDefinitionName -match 'Administrator' -and $_.Scope -match '^/subscriptions/[^/]+$' -and $_.ObjectType -eq 'User' -and $_.RoleAssignmentId -notmatch '/roleAssignments/' } |
    ForEach-Object {
        [pscustomobject]@{ Principal = $_.SignInName; Ruolo = $_.RoleDefinitionName; Scope = $_.Scope }
    }
# Fallback: includi comunque tutte le righe marcate come classic (RoleDefinitionName con 'Administrator' su scope subscription)
if (-not $report) {
    $report = Get-AzRoleAssignment -IncludeClassicAdministrators |
        Where-Object { $_.RoleDefinitionName -match 'CoAdministrator|ServiceAdministrator|AccountAdministrator' } |
        ForEach-Object { [pscustomobject]@{ Principal = $_.SignInName; Ruolo = $_.RoleDefinitionName; Scope = $_.Scope } }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} classic administrator → {1}. Migra verso RBAC e rimuovi i classic non necessari." -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
