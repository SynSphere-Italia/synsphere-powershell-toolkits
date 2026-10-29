#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Teams
<#
.SYNOPSIS
    Report dei canali di ogni Team (standard, privati, condivisi).
.DESCRIPTION
    Elenca i canali per ciascun team con il tipo di membership. I canali privati e
    condivisi (shared) hanno implicazioni di accesso e governance specifiche. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-TeamsChannels-<data>.csv
.EXAMPLE
    .\04-Get-M365TeamsChannels.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All, Channel.ReadBasic.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-TeamsChannels-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'Group.Read.All', 'Channel.ReadBasic.All' -NoWelcome

$teams = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -All -Property Id, DisplayName
$report = foreach ($t in $teams) {
    foreach ($ch in Get-MgTeamChannel -TeamId $t.Id -All -ErrorAction SilentlyContinue) {
        [pscustomobject]@{
            Team           = $t.DisplayName
            Channel        = $ch.DisplayName
            MembershipType = $ch.MembershipType        # standard / private / shared
        }
    }
}
$report | Sort-Object Team, MembershipType | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$priv = ($report | Where-Object { $_.MembershipType -ne 'standard' }).Count
Write-Host ("Esportati {0} canali ({1} privati/condivisi) → {2}" -f $report.Count, $priv, $OutputCsv) -ForegroundColor Green
