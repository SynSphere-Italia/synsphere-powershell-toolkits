#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Trova i Teams "orfani": team senza alcun proprietario (owner).
.DESCRIPTION
    Un team senza owner non ha nessuno responsabile della sua gestione e della membership:
    è un rischio di governance e sicurezza (accessi mai revisionati). Lo script li elenca
    per assegnare un nuovo owner. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-OrphanedTeams-<data>.csv
.EXAMPLE
    .\02-Get-M365OrphanedTeams.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-OrphanedTeams-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'Group.Read.All' -NoWelcome

$teams = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -All -Property Id, DisplayName, Mail
$report = foreach ($t in $teams) {
    $owners = Get-MgGroupOwner -GroupId $t.Id -All -ErrorAction SilentlyContinue
    if (-not $owners -or $owners.Count -eq 0) {
        [pscustomobject]@{ Team = $t.DisplayName; Mail = $t.Mail; Owners = 0 }
    }
}
if ($report) {
    $report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host ("ATTENZIONE: {0} team SENZA owner → {1}. Assegna un proprietario." -f $report.Count, $OutputCsv) -ForegroundColor Red
} else {
    Write-Host "Nessun team orfano: tutti i team hanno almeno un owner." -ForegroundColor Green
}
