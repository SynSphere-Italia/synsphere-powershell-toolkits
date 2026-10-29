#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Trova i gruppi vuoti (senza membri): candidati alla pulizia.
.DESCRIPTION
    I gruppi senza membri sono spesso residui di progetti chiusi o errori di creazione e
    affollano la rubrica/elenchi. Lo script li elenca per la dismissione. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-EmptyGroups-<data>.csv
.EXAMPLE
    .\04-Get-M365EmptyGroups.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All, GroupMember.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-EmptyGroups-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'Group.Read.All', 'GroupMember.Read.All' -NoWelcome

$report = foreach ($g in Get-MgGroup -All -Property Id, DisplayName, Mail, GroupTypes, CreatedDateTime) {
    $count = (Get-MgGroupMember -GroupId $g.Id -All -ErrorAction SilentlyContinue).Count
    if ($count -eq 0) {
        [pscustomobject]@{
            Group   = $g.DisplayName
            Mail    = $g.Mail
            Types   = ($g.GroupTypes -join ', ')
            Created = if ($g.CreatedDateTime) { ([datetime]$g.CreatedDateTime).ToString('yyyy-MM-dd') } else { '' }
        }
    }
}
$report | Sort-Object Group | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} gruppi VUOTI (candidati alla pulizia) → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
