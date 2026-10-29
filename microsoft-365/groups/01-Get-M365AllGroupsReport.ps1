#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Inventario di TUTTI i gruppi del tenant con tipo e numero di membri.
.DESCRIPTION
    Elenca i gruppi Microsoft 365, di sicurezza, mail-enabled security, distribution e
    dinamici, classificandoli per tipo e con il conteggio dei membri. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-AllGroups-<data>.csv
.EXAMPLE
    .\01-Get-M365AllGroupsReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All, GroupMember.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-AllGroups-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'Group.Read.All', 'GroupMember.Read.All' -NoWelcome

function Get-GroupType($g) {
    if ($g.GroupTypes -contains 'Unified') { 'Microsoft 365' }
    elseif ($g.GroupTypes -contains 'DynamicMembership') { 'Dinamico' }
    elseif ($g.MailEnabled -and $g.SecurityEnabled) { 'Mail-enabled Security' }
    elseif ($g.SecurityEnabled) { 'Sicurezza' }
    elseif ($g.MailEnabled) { 'Distribution' }
    else { 'Altro' }
}

$report = foreach ($g in Get-MgGroup -All -Property Id, DisplayName, GroupTypes, SecurityEnabled, MailEnabled, Mail, Visibility) {
    $members = (Get-MgGroupMember -GroupId $g.Id -All -ErrorAction SilentlyContinue).Count
    [pscustomobject]@{
        DisplayName = $g.DisplayName
        Type        = Get-GroupType $g
        Mail        = $g.Mail
        Visibility  = $g.Visibility
        Members     = $members
    }
}
$report | Sort-Object Type, DisplayName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} gruppi in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
