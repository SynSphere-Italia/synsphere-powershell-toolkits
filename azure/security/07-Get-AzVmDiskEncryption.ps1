#Requires -Modules Az.Accounts, Az.Compute
<#
.SYNOPSIS
    VM e stato di cifratura dei dischi (evidenzia le VM NON cifrate).
.DESCRIPTION
    Verifica per ogni VM lo stato di cifratura di OS e data disk (Azure Disk Encryption).
    Le VM non cifrate sono un rischio di compliance (GDPR, ISO 27001). Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-VmDiskEncryption-<data>.csv
.EXAMPLE
    .\07-Get-AzVmDiskEncryption.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader/VM Contributor per leggere lo stato. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-VmDiskEncryption-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($vm in Get-AzVM) {
    $os = '?'; $data = '?'
    try {
        $enc = Get-AzVMDiskEncryptionStatus -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name -ErrorAction Stop
        $os = $enc.OsVolumeEncrypted; $data = $enc.DataVolumesEncrypted
    } catch { $os = 'n/d'; $data = 'n/d' }
    [pscustomobject]@{
        VM            = $vm.Name
        ResourceGroup = $vm.ResourceGroupName
        OSCifrato     = $os
        DatiCifrati   = $data
    }
}
$report | Sort-Object OSCifrato, VM | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$nonEnc = @($report | Where-Object { $_.OSCifrato -in 'NotEncrypted', $false }).Count
Write-Host ("{0} VM totali, {1} con OS non cifrato → {2}" -f $report.Count, $nonEnc, $OutputCsv) -ForegroundColor Yellow
