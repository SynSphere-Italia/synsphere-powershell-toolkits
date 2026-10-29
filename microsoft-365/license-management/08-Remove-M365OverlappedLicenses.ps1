#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users.Actions
<#
.SYNOPSIS
    Trova (e opzionalmente rimuove) le licenze DIRETTE sovrapposte a una group-based.
.DESCRIPTION
    Quando lo stesso SKU è assegnato a un utente sia direttamente sia tramite gruppo,
    l'assegnazione diretta è ridondante (la licenza resta garantita dal gruppo).
    Lo script individua queste sovrapposizioni e, se richiesto, rimuove SOLO
    l'assegnazione diretta.

    DEFAULT = solo report. Usa -RemoveDirect per rimuovere (supporta -WhatIf/-Confirm).
.PARAMETER RemoveDirect
    Se presente, rimuove l'assegnazione diretta sovrapposta. Senza, solo report.
.PARAMETER OutputCsv
    Percorso CSV di output. Default: .\M365-OverlappedLicenses-<data>.csv
.EXAMPLE
    .\08-Remove-M365OverlappedLicenses.ps1                       # solo report
.EXAMPLE
    .\08-Remove-M365OverlappedLicenses.ps1 -RemoveDirect -WhatIf # simula la rimozione
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Operazione di scrittura: testare con -WhatIf.
    Permessi Graph: User.ReadWrite.All, Organization.Read.All
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$RemoveDirect,
    [string]$OutputCsv = (".\M365-OverlappedLicenses-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.ReadWrite.All', 'Organization.Read.All' -NoWelcome
$skuMap = @{}; Get-MgSubscribedSku -All | ForEach-Object { $skuMap[$_.SkuId] = $_.SkuPartNumber }

$report = foreach ($user in Get-MgUser -All -Property DisplayName, UserPrincipalName, Id, LicenseAssignmentStates) {
    # Raggruppa gli stati per SkuId: overlap = stesso SKU con almeno una diretta E una da gruppo
    $bySku = $user.LicenseAssignmentStates | Group-Object SkuId
    foreach ($grp in $bySku) {
        $hasDirect = $grp.Group | Where-Object { -not $_.AssignedByGroup }
        $hasGroup  = $grp.Group | Where-Object { $_.AssignedByGroup }
        if ($hasDirect -and $hasGroup) {
            $sku = $skuMap[$grp.Name]
            $removed = $false
            if ($RemoveDirect -and $PSCmdlet.ShouldProcess($user.UserPrincipalName, "Rimuovi licenza DIRETTA sovrapposta $sku")) {
                Set-MgUserLicense -UserId $user.Id -AddLicenses @() -RemoveLicenses @($grp.Name) | Out-Null
                $removed = $true
            }
            [pscustomobject]@{
                DisplayName       = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                OverlappedSku     = $sku
                DirectRemoved     = $removed
            }
        }
    }
}

if ($report) {
    $report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host ("Trovate {0} licenze dirette sovrapposte → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
    if (-not $RemoveDirect) { Write-Host "Solo report. Rilancia con -RemoveDirect (e -WhatIf per simulare) per rimuoverle." -ForegroundColor Yellow }
} else {
    Write-Host "Nessuna licenza diretta sovrapposta trovata." -ForegroundColor Green
}
