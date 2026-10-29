#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Trova i gruppi Microsoft 365 senza proprietari (ownerless).
.DESCRIPTION
    Un gruppo M365 senza owner non ha nessuno responsabile della membership e dei
    contenuti collegati (Teams, SharePoint, Planner): è un rischio di governance.
    Lo script li elenca per riassegnare un proprietario. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-OwnerlessGroups-<data>.csv
.EXAMPLE
    .\05-Get-M365OwnerlessM365Groups.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-OwnerlessGroups-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'Group.Read.All' -NoWelcome

$groups = Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All -Property Id, DisplayName, Mail
$report = foreach ($g in $groups) {
    $owners = Get-MgGroupOwner -GroupId $g.Id -All -ErrorAction SilentlyContinue
    if (-not $owners -or $owners.Count -eq 0) {
        [pscustomobject]@{ Group = $g.DisplayName; Mail = $g.Mail; Owners = 0 }
    }
}
if ($report) {
    $report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host ("ATTENZIONE: {0} gruppi M365 SENZA owner → {1}. Assegna un proprietario." -f $report.Count, $OutputCsv) -ForegroundColor Red
} else {
    Write-Host "Nessun gruppo M365 ownerless." -ForegroundColor Green
}
