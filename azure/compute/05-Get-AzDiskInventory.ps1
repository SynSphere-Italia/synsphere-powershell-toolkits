#Requires -Modules Az.Accounts, Az.Compute
<#
.SYNOPSIS
    Inventario dei dischi gestiti: dimensione, SKU, stato, cifratura, VM associata.
.DESCRIPTION
    Mappa completa dei managed disk con tier di performance, stato (collegato/scollegato),
    tipo di cifratura e VM proprietaria. Base per ottimizzazione storage e audit. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-DiskInventory-<data>.csv
.EXAMPLE
    .\05-Get-AzDiskInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-DiskInventory-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzDisk | ForEach-Object {
    [pscustomobject]@{
        Disco         = $_.Name
        ResourceGroup = $_.ResourceGroupName
        SizeGB        = $_.DiskSizeGB
        Sku           = $_.Sku.Name
        Stato         = $_.DiskState
        Cifratura     = $_.Encryption.Type
        OS            = $_.OsType
        VMAssociata   = if ($_.ManagedBy) { ($_.ManagedBy -split '/')[-1] } else { '(nessuna)' }
    }
}
$report | Sort-Object Stato, ResourceGroup, Disco | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} dischi → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
