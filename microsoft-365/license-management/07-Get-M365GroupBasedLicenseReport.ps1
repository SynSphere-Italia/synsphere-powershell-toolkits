#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Esporta gli utenti con licenze assegnate tramite gruppo (group-based licensing).
.DESCRIPTION
    Filtra le sole assegnazioni ereditate da gruppo e indica il gruppo di origine
    e lo stato (eventuali errori di assegnazione). Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV di output. Default: .\M365-GroupBasedLicenses-<data>.csv
.EXAMPLE
    .\07-Get-M365GroupBasedLicenseReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, Group.Read.All, Organization.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-GroupBasedLicenses-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All', 'Group.Read.All', 'Organization.Read.All' -NoWelcome

$skuMap = @{}; Get-MgSubscribedSku -All | ForEach-Object { $skuMap[$_.SkuId] = $_.SkuPartNumber }
$groupCache = @{}
function Get-GroupName($id) {
    if (-not $groupCache.ContainsKey($id)) { $groupCache[$id] = (Get-MgGroup -GroupId $id -Property DisplayName -ErrorAction SilentlyContinue).DisplayName }
    return $groupCache[$id]
}

$report = foreach ($user in Get-MgUser -All -Property DisplayName, UserPrincipalName, LicenseAssignmentStates) {
    foreach ($state in ($user.LicenseAssignmentStates | Where-Object AssignedByGroup)) {
        [pscustomobject]@{
            DisplayName       = $user.DisplayName
            UserPrincipalName = $user.UserPrincipalName
            Sku               = $skuMap[$state.SkuId]
            SourceGroup       = Get-GroupName $state.AssignedByGroup
            State             = $state.State           # Active / Error / ...
            Error             = $state.Error
        }
    }
}

$report | Sort-Object DisplayName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} assegnazioni group-based in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
