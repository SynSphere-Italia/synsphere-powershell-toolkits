#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report degli ospiti con i gruppi e i team di cui fanno parte.
.DESCRIPTION
    Per ogni utente guest elenca i gruppi/team a cui appartiene: serve per capire a
    quali risorse ha accesso un ospite e per la pulizia degli accessi esterni. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-GuestGroupMemberships-<data>.csv
.EXAMPLE
    .\02-Get-M365GuestGroupMemberships.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, GroupMember.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-GuestGroupMemberships-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All', 'GroupMember.Read.All' -NoWelcome

$guests = Get-MgUser -Filter "userType eq 'Guest'" -All -Property DisplayName, Mail, Id
$report = foreach ($g in $guests) {
    $groups = Get-MgUserMemberOf -UserId $g.Id -All -ErrorAction SilentlyContinue |
        Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group' }
    [pscustomobject]@{
        Guest      = $g.DisplayName
        Email      = $g.Mail
        GroupCount = $groups.Count
        Groups     = ($groups.AdditionalProperties.displayName -join '; ')
    }
}
$report | Sort-Object GroupCount -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} guest con le loro membership in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
