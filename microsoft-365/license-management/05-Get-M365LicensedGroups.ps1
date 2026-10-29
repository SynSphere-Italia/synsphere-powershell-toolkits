#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Elenca i gruppi con licenze assegnate (group-based licensing).
.DESCRIPTION
    Esporta i gruppi che hanno una o più licenze assegnate, con il numero di membri.
    Utile per mappare il group-based licensing del tenant. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV di output. Default: .\M365-LicensedGroups-<data>.csv
.EXAMPLE
    .\05-Get-M365LicensedGroups.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All, Organization.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-LicensedGroups-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Group.Read.All', 'Organization.Read.All' -NoWelcome

$skuMap = @{}; Get-MgSubscribedSku -All | ForEach-Object { $skuMap[$_.SkuId] = $_.SkuPartNumber }

$report = foreach ($g in Get-MgGroup -All -Property Id, DisplayName, AssignedLicenses, GroupTypes) {
    if (-not $g.AssignedLicenses) { continue }
    $members = (Get-MgGroupMember -GroupId $g.Id -All -ErrorAction SilentlyContinue).Count
    [pscustomobject]@{
        GroupName    = $g.DisplayName
        Licenses     = ($g.AssignedLicenses | ForEach-Object { $skuMap[$_.SkuId] }) -join '; '
        LicenseCount = $g.AssignedLicenses.Count
        Members      = $members
    }
}

$report | Sort-Object GroupName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} gruppi con licenze in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
