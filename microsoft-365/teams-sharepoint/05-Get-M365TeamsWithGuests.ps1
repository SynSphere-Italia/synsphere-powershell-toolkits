#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Trova i Teams che contengono ospiti (guest) esterni.
.DESCRIPTION
    Elenca i team con almeno un membro guest e i relativi indirizzi: serve per sapere
    dove c'è collaborazione esterna e per la revisione periodica degli accessi. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-TeamsWithGuests-<data>.csv
.EXAMPLE
    .\05-Get-M365TeamsWithGuests.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All, GroupMember.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-TeamsWithGuests-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'Group.Read.All', 'GroupMember.Read.All' -NoWelcome

$teams = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -All -Property Id, DisplayName
$report = foreach ($t in $teams) {
    $guests = Get-MgGroupMember -GroupId $t.Id -All -ErrorAction SilentlyContinue |
        Where-Object { $_.AdditionalProperties.userType -eq 'Guest' }
    if ($guests) {
        [pscustomobject]@{
            Team       = $t.DisplayName
            GuestCount = $guests.Count
            Guests     = ($guests.AdditionalProperties.mail -join '; ')
        }
    }
}
$report | Sort-Object GuestCount -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} team con ospiti esterni → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
