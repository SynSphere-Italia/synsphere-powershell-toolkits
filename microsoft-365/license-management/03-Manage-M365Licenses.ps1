#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users.Actions
<#
.SYNOPSIS
    Gestione licenze Microsoft 365: report, assegna, rimuovi (anche in massa da CSV).
.DESCRIPTION
    Script multi-azione per la gestione delle licenze. Supporta -WhatIf per simulare
    le operazioni di scrittura (Assign/Remove) senza applicarle.

    Azioni (-Action):
      Report  : elenca le licenze di un utente (sola lettura).
      Assign  : assegna uno SKU a un utente.
      Remove  : rimuove uno SKU da un utente.
      BulkCsv : assegna/rimuove in massa da un CSV (colonne: UserPrincipalName,SkuPartNumber,Operation).
.PARAMETER Action
    Report | Assign | Remove | BulkCsv
.PARAMETER UserPrincipalName
    UPN dell'utente (per Report/Assign/Remove).
.PARAMETER SkuPartNumber
    SKU da assegnare/rimuovere (es. SPE_E3, O365_BUSINESS_PREMIUM).
.PARAMETER CsvPath
    CSV per l'azione BulkCsv. Colonne: UserPrincipalName,SkuPartNumber,Operation (Assign|Remove).
.EXAMPLE
    .\03-Manage-M365Licenses.ps1 -Action Report -UserPrincipalName mario.rossi@azienda.it
.EXAMPLE
    .\03-Manage-M365Licenses.ps1 -Action Assign -UserPrincipalName mario.rossi@azienda.it -SkuPartNumber SPE_E3 -WhatIf
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Testare con -WhatIf.
    Permessi Graph: User.ReadWrite.All, Organization.Read.All
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][ValidateSet('Report', 'Assign', 'Remove', 'BulkCsv')][string]$Action,
    [string]$UserPrincipalName,
    [string]$SkuPartNumber,
    [string]$CsvPath
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.ReadWrite.All', 'Organization.Read.All' -NoWelcome

# Mappe SkuPartNumber <-> SkuId
$skus = Get-MgSubscribedSku -All
$idByPart = @{}; $skus | ForEach-Object { $idByPart[$_.SkuPartNumber] = $_.SkuId }
$partById = @{}; $skus | ForEach-Object { $partById[$_.SkuId] = $_.SkuPartNumber }

function Set-License {
    param([string]$Upn, [string]$Part, [ValidateSet('Assign', 'Remove')][string]$Op)
    $skuId = $idByPart[$Part]
    if (-not $skuId) { Write-Warning "SKU '$Part' non trovato nel tenant."; return }
    if (-not $PSCmdlet.ShouldProcess("$Upn", "$Op licenza $Part")) { return }
    if ($Op -eq 'Assign') {
        Set-MgUserLicense -UserId $Upn -AddLicenses @{ SkuId = $skuId } -RemoveLicenses @() | Out-Null
    } else {
        Set-MgUserLicense -UserId $Upn -AddLicenses @() -RemoveLicenses @($skuId) | Out-Null
    }
    Write-Host ("{0}: {1} {2}" -f $Upn, $Op, $Part) -ForegroundColor Green
}

switch ($Action) {
    'Report' {
        if (-not $UserPrincipalName) { throw "Specificare -UserPrincipalName." }
        Get-MgUserLicenseDetail -UserId $UserPrincipalName |
            Select-Object @{N = 'User'; E = { $UserPrincipalName } }, SkuPartNumber,
                @{N = 'EnabledPlans'; E = { ($_.ServicePlans | Where-Object ProvisioningStatus -eq 'Success').Count } }
    }
    'Assign' { Set-License -Upn $UserPrincipalName -Part $SkuPartNumber -Op Assign }
    'Remove' { Set-License -Upn $UserPrincipalName -Part $SkuPartNumber -Op Remove }
    'BulkCsv' {
        if (-not (Test-Path $CsvPath)) { throw "CSV non trovato: $CsvPath" }
        Import-Csv $CsvPath | ForEach-Object { Set-License -Upn $_.UserPrincipalName -Part $_.SkuPartNumber -Op $_.Operation }
    }
}
