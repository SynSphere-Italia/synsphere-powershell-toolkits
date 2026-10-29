#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Dettaglio membership dei Teams: owner, membri e ospiti per ogni team.
.DESCRIPTION
    Esporta una riga per ogni appartenenza (team + persona + ruolo + tipo), così da avere
    la mappa completa di chi è in quale team. Utile per audit accessi e offboarding. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-TeamsMembership-<data>.csv
.EXAMPLE
    .\03-Get-M365TeamsMembership.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All, GroupMember.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-TeamsMembership-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'Group.Read.All', 'GroupMember.Read.All' -NoWelcome

$teams = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -All -Property Id, DisplayName
$report = foreach ($t in $teams) {
    foreach ($o in Get-MgGroupOwner -GroupId $t.Id -All -ErrorAction SilentlyContinue) {
        [pscustomobject]@{ Team = $t.DisplayName; Person = $o.AdditionalProperties.userPrincipalName; Role = 'Owner'; Type = $o.AdditionalProperties.userType }
    }
    foreach ($m in Get-MgGroupMember -GroupId $t.Id -All -ErrorAction SilentlyContinue) {
        [pscustomobject]@{ Team = $t.DisplayName; Person = $m.AdditionalProperties.userPrincipalName; Role = 'Member'; Type = $m.AdditionalProperties.userType }
    }
}
$report | Sort-Object Team, Role | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} appartenenze in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
