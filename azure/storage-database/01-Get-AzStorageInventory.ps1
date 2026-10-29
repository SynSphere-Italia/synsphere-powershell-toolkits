#Requires -Modules Az.Accounts, Az.Storage
<#
.SYNOPSIS
    Inventario degli storage account (SKU/replica, tipo, access tier, sicurezza base).
.DESCRIPTION
    Fotografia di tutti gli storage account: ridondanza (LRS/ZRS/GRS), kind, tier di accesso
    e impostazioni di sicurezza di base (HTTPS, blob pubblici). Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-StorageInventory-<data>.csv
.EXAMPLE
    .\01-Get-AzStorageInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-StorageInventory-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzStorageAccount | ForEach-Object {
    [pscustomobject]@{
        StorageAccount = $_.StorageAccountName
        ResourceGroup  = $_.ResourceGroupName
        Location       = $_.Location
        Replica        = $_.Sku.Name
        Kind           = $_.Kind
        AccessTier     = $_.AccessTier
        HttpsOnly      = $_.EnableHttpsTrafficOnly
        BlobPubblici   = $_.AllowBlobPublicAccess
    }
}
$report | Sort-Object ResourceGroup, StorageAccount | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} storage account → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
