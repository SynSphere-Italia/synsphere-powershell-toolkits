#Requires -Modules Az.Accounts, Az.Compute
<#
.SYNOPSIS
    VM deallocate che pagano ancora i dischi: elenco dei dischi associati.
.DESCRIPTION
    Una VM "deallocata" non paga il compute, ma continua a pagare i dischi gestiti.
    Lo script elenca le VM deallocate con i loro dischi (OS + dati), dimensione e SKU:
    candidate al ridimensionamento dischi o all'eliminazione. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-DeallocatedVmDisks-<data>.csv
.EXAMPLE
    .\06-Get-AzDeallocatedVmDiskCost.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-DeallocatedVmDisks-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$disksById = @{}
Get-AzDisk | ForEach-Object { $disksById[$_.Id] = $_ }

$report = [System.Collections.Generic.List[object]]::new()
foreach ($vm in Get-AzVM -Status) {
    if ($vm.PowerState -notmatch 'deallocated') { continue }
    $diskIds = @($vm.StorageProfile.OsDisk.ManagedDisk.Id) + @($vm.StorageProfile.DataDisks.ManagedDisk.Id) | Where-Object { $_ }
    foreach ($id in $diskIds) {
        $d = $disksById[$id]
        $report.Add([pscustomobject]@{
            VM = $vm.Name; PowerState = $vm.PowerState; ResourceGroup = $vm.ResourceGroupName
            Disco = if ($d) { $d.Name } else { ($id -split '/')[-1] }
            DiscoGB = if ($d) { $d.DiskSizeGB } else { '' }; Sku = if ($d) { $d.Sku.Name } else { '' }
        })
    }
}
$report | Sort-Object ResourceGroup, VM | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} dischi su VM deallocate → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
