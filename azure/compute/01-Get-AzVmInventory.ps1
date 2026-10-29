#Requires -Modules Az.Accounts, Az.Compute
<#
.SYNOPSIS
    Inventario delle macchine virtuali: dimensione, OS, power state, region.
.DESCRIPTION
    La fotografia completa del parco VM: SKU, sistema operativo, stato di alimentazione e
    resource group. Base per capacity planning e ottimizzazione. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-VmInventory-<data>.csv
.EXAMPLE
    .\01-Get-AzVmInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-VmInventory-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzVM -Status | ForEach-Object {
    [pscustomobject]@{
        VM            = $_.Name
        ResourceGroup = $_.ResourceGroupName
        Location      = $_.Location
        Size          = $_.HardwareProfile.VmSize
        OS            = $_.StorageProfile.OsDisk.OsType
        PowerState    = $_.PowerState
    }
}
$report | Sort-Object ResourceGroup, VM | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} VM in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
