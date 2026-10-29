#Requires -Modules Microsoft.Online.SharePoint.PowerShell
<#
.SYNOPSIS
    Report della capacità di condivisione esterna per ogni sito SharePoint.
.DESCRIPTION
    Mostra l'impostazione SharingCapability di ciascun sito ed evidenzia quelli che
    consentono la condivisione anonima ("ExternalUserAndGuestSharing"), il livello più
    aperto. Riporta anche l'impostazione a livello di tenant. Sola lettura.
.PARAMETER AdminUrl
    URL admin center SharePoint, es. https://contoso-admin.sharepoint.com (obbligatorio).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-SPOSharing-<data>.csv
.EXAMPLE
    .\07-Get-M365SPOExternalSharingSettings.ps1 -AdminUrl https://contoso-admin.sharepoint.com
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo SharePoint Administrator.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AdminUrl,
    [string]$OutputCsv = (".\M365-SPOSharing-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-SPOService -Url $AdminUrl

Write-Host ("Tenant SharingCapability: {0}" -f (Get-SPOTenant).SharingCapability) -ForegroundColor Cyan

$report = foreach ($s in Get-SPOSite -Limit All) {
    [pscustomobject]@{
        Url               = $s.Url
        SharingCapability = $s.SharingCapability   # Disabled / ExistingExternalUserSharingOnly / ExternalUserSharingOnly / ExternalUserAndGuestSharing
        AllowsAnonymous   = ($s.SharingCapability -eq 'ExternalUserAndGuestSharing')
    }
}
$report | Sort-Object SharingCapability | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$anon = ($report | Where-Object AllowsAnonymous).Count
Write-Host ("{0} siti totali, {1} consentono link anonimi → {2}" -f $report.Count, $anon, $OutputCsv) -ForegroundColor Yellow
