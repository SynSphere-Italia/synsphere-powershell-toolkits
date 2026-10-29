#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Assegnazioni PRIVILEGIATE (Owner, Contributor, User Access Administrator) a livello subscription.
.DESCRIPTION
    Chi ha il controllo totale sulla subscription? Lo script isola i ruoli ad alto privilegio
    assegnati a scope di subscription: il primo controllo di sicurezza degli accessi. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-PrivilegedRoles-<data>.csv
.EXAMPLE
    .\02-Get-AzPrivilegedRoleAssignments.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Reader + lettura roleAssignments. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-PrivilegedRoles-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$privileged = 'Owner', 'Contributor', 'User Access Administrator', 'Role Based Access Control Administrator'
$subId = (Get-AzContext).Subscription.Id
$report = Get-AzRoleAssignment | Where-Object {
    $_.RoleDefinitionName -in $privileged -and $_.Scope -eq "/subscriptions/$subId"
} | ForEach-Object {
    [pscustomobject]@{
        Principal  = $_.DisplayName
        SignInName = $_.SignInName
        Tipo       = $_.ObjectType
        Ruolo      = $_.RoleDefinitionName
    }
}
$report | Sort-Object Ruolo, Principal | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} assegnazioni privilegiate a livello subscription → {1}. Verifica che siano tutte necessarie." -f $report.Count, $OutputCsv) -ForegroundColor Yellow
