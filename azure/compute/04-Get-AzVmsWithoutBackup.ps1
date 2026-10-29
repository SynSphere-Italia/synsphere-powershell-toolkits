#Requires -Modules Az.Accounts, Az.Compute, Az.RecoveryServices
<#
.SYNOPSIS
    VM NON protette da backup (Azure Backup / Recovery Services).
.DESCRIPTION
    Confronta tutte le VM con quelle effettivamente protette dai Recovery Services vault e
    segnala le VM senza backup: un rischio operativo serio. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-VmsWithoutBackup-<data>.csv
.EXAMPLE
    .\04-Get-AzVmsWithoutBackup.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader + Backup Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-VmsWithoutBackup-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

# Set delle VM protette (per nome) raccolte da tutti i vault
$protected = New-Object System.Collections.Generic.HashSet[string]
foreach ($vault in Get-AzRecoveryServicesVault) {
    try {
        $items = Get-AzRecoveryServicesBackupItem -VaultId $vault.ID -BackupManagementType AzureVM -WorkloadType AzureVM -ErrorAction Stop
        foreach ($it in $items) { [void]$protected.Add((($it.VirtualMachineId -split '/')[-1]).ToLower()) }
    } catch { }
}
$report = Get-AzVM | Where-Object { -not $protected.Contains($_.Name.ToLower()) } | ForEach-Object {
    [pscustomobject]@{ VM = $_.Name; ResourceGroup = $_.ResourceGroupName; Location = $_.Location; Backup = 'ASSENTE' }
}
$report | Sort-Object ResourceGroup, VM | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} VM senza backup → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
