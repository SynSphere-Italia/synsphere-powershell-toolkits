#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report dei gruppi Microsoft 365 (unified) con proprietari e membri.
.DESCRIPTION
    Per ogni gruppo Microsoft 365 elenca owner e membri (una riga per appartenenza),
    con il ruolo e il tipo (membro interno o ospite). Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-GroupMembers-<data>.csv
.EXAMPLE
    .\02-Get-M365GroupMembersReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All, GroupMember.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-GroupMembers-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'Group.Read.All', 'GroupMember.Read.All' -NoWelcome

$groups = Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All -Property Id, DisplayName
$report = foreach ($g in $groups) {
    foreach ($o in Get-MgGroupOwner -GroupId $g.Id -All -ErrorAction SilentlyContinue) {
        [pscustomobject]@{ Group = $g.DisplayName; Person = $o.AdditionalProperties.userPrincipalName; Role = 'Owner'; Type = $o.AdditionalProperties.userType }
    }
    foreach ($m in Get-MgGroupMember -GroupId $g.Id -All -ErrorAction SilentlyContinue) {
        [pscustomobject]@{ Group = $g.DisplayName; Person = $m.AdditionalProperties.userPrincipalName; Role = 'Member'; Type = $m.AdditionalProperties.userType }
    }
}
$report | Sort-Object Group, Role | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} appartenenze ai gruppi M365 in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
