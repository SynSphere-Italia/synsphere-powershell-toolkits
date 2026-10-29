#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report delle impostazioni di collaborazione esterna del tenant (chi può invitare, ruolo guest).
.DESCRIPTION
    Legge l'authorization policy di Microsoft Entra e mostra la "postura" sugli ospiti:
    chi può invitare guest e quale livello di accesso hanno i guest nella directory.
    Fondamentale per un audit di sicurezza/NIS2. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-ExternalCollabSettings-<data>.csv
.EXAMPLE
    .\10-Get-M365ExternalCollaborationSettings.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Policy.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-ExternalCollabSettings-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'Policy.Read.All' -NoWelcome

# Mappa GUID ruolo guest → significato (dal più al meno permissivo)
$guestRole = @{
    'a0b1b346-4d3e-4e8b-98f8-753987be4970' = 'User (come un membro — PERMISSIVO)'
    '10dae51f-b6af-4016-8d66-8c2a99b929b3' = 'Guest (accesso limitato — default)'
    '2af84b1e-32c8-42b7-82bc-daa82404023b' = 'Restricted Guest (massima restrizione)'
}
$pol = Get-MgPolicyAuthorizationPolicy
$roleId = $pol.GuestUserRoleId
$report = [pscustomobject]@{
    AllowInvitesFrom          = $pol.AllowInvitesFrom          # everyone / adminsAndGuestInviters / none ...
    GuestUserRole             = if ($guestRole[$roleId]) { $guestRole[$roleId] } else { $roleId }
    AllowEmailSubscriptions   = $pol.AllowedToSignUpEmailBasedSubscriptions
    AllowedToCreateApps       = $pol.DefaultUserRolePermissions.AllowedToCreateApps
    AllowedToCreateSecurityGroups = $pol.DefaultUserRolePermissions.AllowedToCreateSecurityGroups
}
$report | Format-List
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Impostazioni di collaborazione esterna esportate in {0}." -f $OutputCsv) -ForegroundColor Green
Write-Host "Consiglio: 'AllowInvitesFrom' = everyone è troppo aperto; valuta 'adminsAndGuestInviters'." -ForegroundColor Yellow
