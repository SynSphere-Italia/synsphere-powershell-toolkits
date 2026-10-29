<#
.SYNOPSIS
    Verifica lo spazio libero sul disco di sistema per l'upgrade a Windows 11.
.DESCRIPTION
    Un upgrade in-place richiede spazio libero (indicativamente >= 20-25 GB oltre ai file
    di installazione). Lo script riporta dimensione/spazio libero del disco di sistema e,
    se richiesto, stima lo spazio recuperabile analizzando i componenti Windows (DISM
    /AnalyzeComponentStore). Sola lettura (nessuna pulizia eseguita).
.PARAMETER MinFreeGb
    Soglia minima di spazio libero. Default: 25.
.PARAMETER AnalyzeCleanup
    Se presente, esegue l'analisi (sola lettura) dei componenti recuperabili con DISM.
.EXAMPLE
    .\06-Get-UpgradeDiskSpace.ps1 -AnalyzeCleanup
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Eseguire come amministratore.
#>
[CmdletBinding()]
param([int]$MinFreeGb = 25, [switch]$AnalyzeCleanup)
$ErrorActionPreference = 'Stop'

$sys = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
$freeGb = [math]::Round($sys.FreeSpace / 1GB, 1)
$sizeGb = [math]::Round($sys.Size / 1GB, 1)

Write-Host ("Disco {0}  totale {1} GB  libero {2} GB  (soglia {3} GB)" -f $env:SystemDrive, $sizeGb, $freeGb, $MinFreeGb)
if ($freeGb -ge $MinFreeGb) { Write-Host 'Spazio SUFFICIENTE per l''upgrade.' -ForegroundColor Green }
else { Write-Host ("Spazio INSUFFICIENTE: liberare almeno {0} GB." -f ($MinFreeGb - $freeGb)) -ForegroundColor Yellow }

if ($AnalyzeCleanup) {
    Write-Host "`nAnalisi componenti Windows recuperabili (DISM, sola lettura)…"
    & dism.exe /Online /Cleanup-Image /AnalyzeComponentStore
    Write-Host "Per pulire (azione): dism /Online /Cleanup-Image /StartComponentCleanup  oppure  cleanmgr /sagerun" -ForegroundColor Cyan
}
