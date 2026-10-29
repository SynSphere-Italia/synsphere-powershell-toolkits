#Requires -Modules Az.Accounts, Az.Compute
<#
.SYNOPSIS
    Modalità di gestione patch per ogni VM (Automatic / Manual) e aggiornamenti automatici.
.DESCRIPTION
    Verifica come ogni VM gestisce gli aggiornamenti: orchestrazione patch (AutomaticByPlatform,
    AutomaticByOS, Manual/ImageDefault) e, su Windows, gli aggiornamenti automatici. Evidenzia
    le VM in modalità manuale, più esposte a vulnerabilità note. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-VmPatchStatus-<data>.csv
.EXAMPLE
    .\10-Get-AzVmPatchStatus.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-VmPatchStatus-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($vm in Get-AzVM) {
    $os = $vm.StorageProfile.OsDisk.OsType
    if ($os -eq 'Windows') {
        $mode = $vm.OSProfile.WindowsConfiguration.PatchSettings.PatchMode
        $auto = $vm.OSProfile.WindowsConfiguration.EnableAutomaticUpdates
    } else {
        $mode = $vm.OSProfile.LinuxConfiguration.PatchSettings.PatchMode
        $auto = 'n/a'
    }
    [pscustomobject]@{
        VM            = $vm.Name
        ResourceGroup = $vm.ResourceGroupName
        OS            = $os
        PatchMode     = if ($mode) { $mode } else { 'ImageDefault/Manual' }
        AutoUpdate    = $auto
    }
}
$report | Sort-Object PatchMode, VM | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Stato patch di {0} VM → {1}. Verifica quelle in modalità manuale." -f $report.Count, $OutputCsv) -ForegroundColor Yellow
