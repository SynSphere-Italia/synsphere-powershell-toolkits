#Requires -Modules Microsoft.Online.SharePoint.PowerShell
<#
.SYNOPSIS
    Report di consumo storage dei siti SharePoint, dai più pesanti ai più leggeri.
.DESCRIPTION
    Ordina i siti per spazio occupato e calcola la percentuale rispetto alla quota.
    Utile per capacity planning e per individuare i siti che stanno saturando la quota.
    Sola lettura.
.PARAMETER AdminUrl
    URL admin center SharePoint, es. https://contoso-admin.sharepoint.com (obbligatorio).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-SPOStorage-<data>.csv
.EXAMPLE
    .\08-Get-M365SPOStorageReport.ps1 -AdminUrl https://contoso-admin.sharepoint.com
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo SharePoint Administrator.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AdminUrl,
    [string]$OutputCsv = (".\M365-SPOStorage-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-SPOService -Url $AdminUrl

$report = foreach ($s in Get-SPOSite -Limit All) {
    [pscustomobject]@{
        Url            = $s.Url
        UsedGB         = [math]::Round($s.StorageUsageCurrent / 1024, 2)
        QuotaGB        = [math]::Round($s.StorageQuota / 1024, 2)
        PercentUsed    = if ($s.StorageQuota -gt 0) { [math]::Round(100 * $s.StorageUsageCurrent / $s.StorageQuota, 1) } else { 0 }
    }
}
$report | Sort-Object UsedGB -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$totGB = [math]::Round((($report | Measure-Object UsedGB -Sum).Sum), 2)
Write-Host ("Storage SharePoint totale: {0} GB su {1} siti → {2}" -f $totGB, $report.Count, $OutputCsv) -ForegroundColor Green
