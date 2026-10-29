#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Tutti i ruoli Azure di un utente specifico (diretti + ereditati dai gruppi).
.DESCRIPTION
    Lookup inverso: dato un utente, mostra ogni assegnazione di ruolo e su quale scope,
    incluse quelle ereditate tramite gruppi. Indispensabile prima di un offboarding o
    per un audit degli accessi. Sola lettura.
.PARAMETER SignInName
    UPN/email dell'utente (obbligatorio).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-UserRoles-<data>.csv
.EXAMPLE
    .\06-Get-AzUserRoleAssignments.ps1 -SignInName mario.rossi@azienda.it
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Reader + lettura roleAssignments. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SignInName,
    [string]$OutputCsv = (".\Az-UserRoles-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzRoleAssignment -SignInName $SignInName -ExpandPrincipalGroups | ForEach-Object {
    [pscustomobject]@{
        Ruolo      = $_.RoleDefinitionName
        Scope      = $_.Scope
        Tramite    = if ($_.ObjectType -eq 'Group') { "gruppo: $($_.DisplayName)" } else { 'diretto' }
    }
}
$report | Sort-Object Scope, Ruolo | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} ha {1} assegnazioni di ruolo → {2}" -f $SignInName, $report.Count, $OutputCsv) -ForegroundColor Green
