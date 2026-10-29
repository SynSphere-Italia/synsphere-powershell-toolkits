#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Utenti GUEST (esterni) con assegnazioni di ruolo su risorse Azure.
.DESCRIPTION
    Gli ospiti B2B con accesso ad Azure sono spesso dimenticati: lo script elenca le
    assegnazioni di ruolo a utenti guest (UPN con #EXT#). Da rivedere periodicamente per
    sicurezza. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-GuestRoleAssignments-<data>.csv
.EXAMPLE
    .\09-Get-AzGuestUserRoleAssignments.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Reader + lettura roleAssignments. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-GuestRoleAssignments-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzRoleAssignment | Where-Object {
    $_.ObjectType -eq 'User' -and $_.SignInName -match '#EXT#'
} | ForEach-Object {
    [pscustomobject]@{
        Guest      = $_.DisplayName
        SignInName = $_.SignInName
        Ruolo      = $_.RoleDefinitionName
        Scope      = $_.Scope
    }
}
$report | Sort-Object Guest, Ruolo | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} assegnazioni a utenti guest → {1}. Verifica che siano ancora necessarie." -f $report.Count, $OutputCsv) -ForegroundColor Yellow
