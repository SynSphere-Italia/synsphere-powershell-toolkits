#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Determina, per ogni licenza utente, se è assegnata DIRETTAMENTE o EREDITATA da un gruppo.
.DESCRIPTION
    Usa licenseAssignmentStates per distinguere assegnazioni dirette e group-based.
    Fondamentale prima di rimuovere licenze: una licenza ereditata NON si rimuove
    dall'utente ma dal gruppo. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV di output. Default: .\M365-LicenseAssignmentPath-<data>.csv
.EXAMPLE
    .\06-Get-M365LicenseAssignmentPath.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, Group.Read.All, Organization.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-LicenseAssignmentPath-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All', 'Group.Read.All', 'Organization.Read.All' -NoWelcome

$skuMap = @{}; Get-MgSubscribedSku -All | ForEach-Object { $skuMap[$_.SkuId] = $_.SkuPartNumber }
$groupCache = @{}
function Get-GroupName($id) {
    if (-not $id) { return $null }
    if (-not $groupCache.ContainsKey($id)) {
        $groupCache[$id] = (Get-MgGroup -GroupId $id -Property DisplayName -ErrorAction SilentlyContinue).DisplayName
    }
    return $groupCache[$id]
}

$report = foreach ($user in Get-MgUser -All -Property DisplayName, UserPrincipalName, LicenseAssignmentStates) {
    foreach ($state in $user.LicenseAssignmentStates) {
        [pscustomobject]@{
            DisplayName       = $user.DisplayName
            UserPrincipalName = $user.UserPrincipalName
            Sku               = $skuMap[$state.SkuId]
            AssignmentPath    = if ($state.AssignedByGroup) { "Gruppo: $(Get-GroupName $state.AssignedByGroup)" } else { 'Diretta' }
            State             = $state.State
        }
    }
}

$report | Sort-Object DisplayName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} assegnazioni (diretta/gruppo) in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
