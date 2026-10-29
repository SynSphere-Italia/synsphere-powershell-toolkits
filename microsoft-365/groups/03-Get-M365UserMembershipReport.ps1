#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Elenca tutti i gruppi a cui appartiene un determinato utente.
.DESCRIPTION
    Lookup inverso: dato un utente, mostra tutti i gruppi (di qualsiasi tipo) di cui è
    membro. Indispensabile prima di un offboarding o per un audit degli accessi. Sola lettura.
.PARAMETER UserPrincipalName
    UPN dell'utente (obbligatorio).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-UserMembership-<data>.csv
.EXAMPLE
    .\03-Get-M365UserMembershipReport.ps1 -UserPrincipalName mario.rossi@azienda.it
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, GroupMember.Read.All
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$UserPrincipalName,
    [string]$OutputCsv = (".\M365-UserMembership-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All', 'GroupMember.Read.All' -NoWelcome

$user = Get-MgUser -UserId $UserPrincipalName -Property Id, DisplayName
$report = Get-MgUserMemberOf -UserId $user.Id -All |
    Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group' } |
    ForEach-Object {
        [pscustomobject]@{
            Group   = $_.AdditionalProperties.displayName
            Mail    = $_.AdditionalProperties.mail
            Types   = ($_.AdditionalProperties.groupTypes -join ', ')
        }
    }
$report | Sort-Object Group | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} appartiene a {1} gruppi → {2}" -f $UserPrincipalName, $report.Count, $OutputCsv) -ForegroundColor Green
