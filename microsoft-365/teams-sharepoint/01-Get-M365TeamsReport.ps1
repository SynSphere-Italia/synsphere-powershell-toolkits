#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report di tutti i Microsoft Teams del tenant con conteggio owner/membri/guest.
.DESCRIPTION
    I Teams sono gruppi Microsoft 365 con il provisioning "Team". Lo script li elenca
    con visibilità (Public/Private) e numero di proprietari, membri e ospiti. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-TeamsReport-<data>.csv
.EXAMPLE
    .\01-Get-M365TeamsReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All, GroupMember.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-TeamsReport-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'Group.Read.All', 'GroupMember.Read.All' -NoWelcome

$teams = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -All -Property Id, DisplayName, Visibility, CreatedDateTime
$report = foreach ($t in $teams) {
    $owners = Get-MgGroupOwner -GroupId $t.Id -All -ErrorAction SilentlyContinue
    $members = Get-MgGroupMember -GroupId $t.Id -All -ErrorAction SilentlyContinue
    $guests = $members | Where-Object { $_.AdditionalProperties.userType -eq 'Guest' }
    [pscustomobject]@{
        Team        = $t.DisplayName
        Visibility  = $t.Visibility
        Owners      = $owners.Count
        Members     = $members.Count
        Guests      = $guests.Count
        Created     = if ($t.CreatedDateTime) { ([datetime]$t.CreatedDateTime).ToString('yyyy-MM-dd') } else { '' }
    }
}
$report | Sort-Object Team | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} team in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
