#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report licenze Microsoft 365: tutti gli utenti licenziati con i piani assegnati.
.DESCRIPTION
    Esporta in CSV ogni utente con licenza, gli SKU assegnati (nome leggibile) e lo
    stato (utente abilitato/disabilitato). Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-LicenseReport-<data>.csv
.EXAMPLE
    .\01-Get-M365LicenseReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, Organization.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-LicenseReport-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'User.Read.All', 'Organization.Read.All' -NoWelcome

# Mappa SkuId -> nome SKU leggibile (skuPartNumber). Per i nomi commerciali completi
# vedi la tabella ufficiale Microsoft "Product names and service plan identifiers".
$skuMap = @{}
Get-MgSubscribedSku -All | ForEach-Object { $skuMap[$_.SkuId] = $_.SkuPartNumber }

$report = foreach ($user in Get-MgUser -All -Property DisplayName, UserPrincipalName, AccountEnabled, AssignedLicenses) {
    if (-not $user.AssignedLicenses) { continue }   # solo utenti licenziati
    $skus = ($user.AssignedLicenses | ForEach-Object { $skuMap[$_.SkuId] }) -join '; '
    [pscustomobject]@{
        DisplayName       = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        AccountEnabled    = $user.AccountEnabled
        LicenseCount      = $user.AssignedLicenses.Count
        Licenses          = $skus
    }
}

$report | Sort-Object DisplayName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} utenti licenziati in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
