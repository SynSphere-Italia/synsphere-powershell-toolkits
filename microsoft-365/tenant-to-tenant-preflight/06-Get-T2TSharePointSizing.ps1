#Requires -Modules Microsoft.Online.SharePoint.PowerShell
<#
.SYNOPSIS
    Dimensionamento di SharePoint e OneDrive: numero siti, spazio occupato, i piu' grandi.
.DESCRIPTION
    Serve a stimare il volume da spostare e a individuare i siti che meritano un trattamento a
    parte. Due default di Get-SPOSite falsano il risultato senza dare errore:

      - -Limit vale 200: su un tenant con 900 siti ne vengono dimensionati 200 e il totale esce
        sbagliato di quattro quinti.
      - -IncludePersonalSite vale $false: senza attivarlo il report non contiene UN SOLO
        OneDrive, cioe' di solito la meta' del volume da migrare.

    Terzo punto, quello che rende confrontabili i numeri: Get-SPOSite risponde in MEGABYTE.
    I report di Microsoft Graph rispondono in byte ed Exchange in stringhe formattate. Qui tutto
    viene normalizzato in byte alla raccolta, cosi' il cruscotto (script 10) somma grandezze
    omogenee invece di sbagliare di un fattore un milione.

    Sola lettura.
.PARAMETER TenantAdminUrl
    URL del centro di amministrazione SharePoint, es. https://contoso-admin.sharepoint.com
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\T2T-SharePoint-<data>.csv
.EXAMPLE
    .\06-Get-T2TSharePointSizing.ps1 -TenantAdminUrl https://contoso-admin.sharepoint.com
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Ruolo minimo: SharePoint Administrator (oppure Global Reader per la sola lettura)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantAdminUrl,
    [string]$OutputCsv = (".\T2T-SharePoint-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-SPOService -Url $TenantAdminUrl

try {
    Write-Host "Siti SharePoint..." -ForegroundColor Cyan
    $siti = Get-SPOSite -Limit ALL

    Write-Host "OneDrive personali..." -ForegroundColor Cyan
    $onedrive = Get-SPOSite -Limit ALL -IncludePersonalSite $true |
        Where-Object { $_.Url -like '*-my.sharepoint.com/personal/*' }

    $report = foreach ($s in @($siti) + @($onedrive)) {
        $personale = $s.Url -like '*-my.sharepoint.com/personal/*'
        [pscustomobject]@{
            Url               = $s.Url
            Titolo            = $s.Title
            Tipo              = if ($personale) { 'OneDrive' } else { 'SharePoint' }
            Template          = $s.Template
            # StorageUsageCurrent e StorageQuota sono in MEGABYTE: normalizzati in byte.
            UsatoByte         = [int64]$s.StorageUsageCurrent * 1MB
            UsatoGB           = [math]::Round(($s.StorageUsageCurrent * 1MB) / 1GB, 2)
            QuotaByte         = [int64]$s.StorageQuota * 1MB
            QuotaGB           = [math]::Round(($s.StorageQuota * 1MB) / 1GB, 2)
            Stato             = $s.Status
            BloccoCondivisione = $s.SharingCapability
            UltimaModifica    = $s.LastContentModifiedDate
        }
    }

    $report | Sort-Object UsatoByte -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

    $tot = ($report.UsatoByte | Measure-Object -Sum).Sum
    $spo = ($report | Where-Object Tipo -eq 'SharePoint')
    $od  = ($report | Where-Object Tipo -eq 'OneDrive')

    Write-Host ""
    Write-Host ("Siti SharePoint : {0,6}  {1,10} GB" -f @($spo).Count, [math]::Round((($spo.UsatoByte | Measure-Object -Sum).Sum) / 1GB, 2))
    Write-Host ("OneDrive        : {0,6}  {1,10} GB" -f @($od).Count,  [math]::Round((($od.UsatoByte  | Measure-Object -Sum).Sum) / 1GB, 2))
    Write-Host ("TOTALE          : {0,6}  {1,10} GB" -f @($report).Count, [math]::Round($tot / 1GB, 2))
    Write-Host ""
    Write-Host "I cinque piu' grandi:"
    $report | Sort-Object UsatoByte -Descending | Select-Object -First 5 |
        ForEach-Object { Write-Host ("  {0,9} GB  {1}" -f $_.UsatoGB, $_.Url) }
    Write-Host ("Esportato in {0}" -f $OutputCsv)
}
finally {
    Disconnect-SPOService -ErrorAction SilentlyContinue
}
