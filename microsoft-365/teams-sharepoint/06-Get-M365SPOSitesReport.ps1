#Requires -Modules Microsoft.Online.SharePoint.PowerShell
<#
.SYNOPSIS
    Report di tutti i siti SharePoint Online: proprietario, template, storage, sharing.
.DESCRIPTION
    Inventario completo dei siti SPO con proprietario, modello, storage usato/quota e
    capacità di condivisione esterna. Sola lettura.
.PARAMETER AdminUrl
    URL dell'admin center SharePoint, es. https://contoso-admin.sharepoint.com (obbligatorio).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-SPOSites-<data>.csv
.EXAMPLE
    .\06-Get-M365SPOSitesReport.ps1 -AdminUrl https://contoso-admin.sharepoint.com
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo SharePoint Administrator. Modulo: Install-Module Microsoft.Online.SharePoint.PowerShell
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AdminUrl,
    [string]$OutputCsv = (".\M365-SPOSites-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-SPOService -Url $AdminUrl

$report = foreach ($s in Get-SPOSite -Limit All) {
    [pscustomobject]@{
        Url               = $s.Url
        Owner             = $s.Owner
        Template          = $s.Template
        StorageUsedMB     = $s.StorageUsageCurrent
        StorageQuotaMB    = $s.StorageQuota
        SharingCapability = $s.SharingCapability
        LastModified      = $s.LastContentModifiedDate
    }
}
$report | Sort-Object StorageUsedMB -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} siti SharePoint in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
