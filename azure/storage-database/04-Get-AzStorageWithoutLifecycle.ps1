#Requires -Modules Az.Accounts, Az.Storage
<#
.SYNOPSIS
    Storage account SENZA criterio di lifecycle management (spreco di costo).
.DESCRIPTION
    Senza una lifecycle policy, i blob vecchi restano nel tier caldo (costoso) e non vengono
    mai eliminati. Lo script segnala gli storage account privi di policy: candidati a tiering
    automatico verso Cool/Archive. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-StorageNoLifecycle-<data>.csv
.EXAMPLE
    .\04-Get-AzStorageWithoutLifecycle.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-StorageNoLifecycle-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($sa in Get-AzStorageAccount) {
    $hasPolicy = $false
    try {
        $p = Get-AzStorageAccountManagementPolicy -ResourceGroupName $sa.ResourceGroupName -StorageAccountName $sa.StorageAccountName -ErrorAction Stop
        if ($p -and $p.Rules) { $hasPolicy = $true }
    } catch { $hasPolicy = $false }
    if (-not $hasPolicy) {
        [pscustomobject]@{ StorageAccount = $sa.StorageAccountName; ResourceGroup = $sa.ResourceGroupName; AccessTier = $sa.AccessTier; Lifecycle = 'ASSENTE' }
    }
}
$report | Sort-Object ResourceGroup, StorageAccount | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} storage account senza lifecycle → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
