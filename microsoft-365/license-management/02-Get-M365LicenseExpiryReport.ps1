#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report piani/sottoscrizioni Microsoft 365 con unità e stato.
.DESCRIPTION
    Esporta gli SKU sottoscritti dall'organizzazione: unità acquistate, consumate,
    in warning/sospese e stato di capacità. Utile per capacity planning e rinnovi.
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV di output. Default: .\M365-LicenseExpiry-<data>.csv
.EXAMPLE
    .\02-Get-M365LicenseExpiryReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Organization.Read.All
    NB: Get-MgSubscribedSku NON espone la data di rinnovo/scadenza. Per le date esatte
    di rinnovo consultare Microsoft 365 admin center → Fatturazione → I tuoi prodotti.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-LicenseExpiry-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Organization.Read.All' -NoWelcome

$report = foreach ($sku in Get-MgSubscribedSku -All) {
    [pscustomobject]@{
        SkuPartNumber  = $sku.SkuPartNumber
        CapabilityStatus = $sku.CapabilityStatus       # Enabled / Warning / Suspended / Deleted
        PurchasedUnits = $sku.PrepaidUnits.Enabled
        WarningUnits   = $sku.PrepaidUnits.Warning      # >0 = sottoscrizione in scadenza/grace period
        SuspendedUnits = $sku.PrepaidUnits.Suspended
        ConsumedUnits  = $sku.ConsumedUnits
        AvailableUnits = ($sku.PrepaidUnits.Enabled - $sku.ConsumedUnits)
        AppliesTo      = $sku.AppliesTo
    }
}

$report | Sort-Object SkuPartNumber | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} SKU in {1}. WarningUnits > 0 indica sottoscrizioni vicine al rinnovo." -f $report.Count, $OutputCsv) -ForegroundColor Green
