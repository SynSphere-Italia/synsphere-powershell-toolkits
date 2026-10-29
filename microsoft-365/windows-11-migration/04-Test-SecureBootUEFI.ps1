<#
.SYNOPSIS
    Verifica Secure Boot, modalità firmware (UEFI/BIOS) e stile partizione disco.
.DESCRIPTION
    Windows 11 richiede firmware UEFI con Secure Boot attivo e disco in GPT. Lo script
    riporta: stato Secure Boot, modalità firmware, e stile partizione del disco di sistema.
    Utile per capire se serve solo abilitare Secure Boot nel firmware o convertire il
    disco da MBR a GPT (MBR2GPT). Sola lettura.
.EXAMPLE
    .\04-Test-SecureBootUEFI.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Eseguire come amministratore.
    La conversione MBR→GPT (mbr2gpt.exe) NON è eseguita da questo script: solo diagnosi.
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\SecureBoot-UEFI-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'

$sbSupported = $true; $sbEnabled = $false
try { $sbEnabled = Confirm-SecureBootUEFI } catch { $sbSupported = $false }

$firmware = if ($sbSupported) { 'UEFI' } else { 'BIOS legacy (o Secure Boot non supportato)' }

$sysDisk = Get-Disk | Where-Object { $_.IsSystem -or $_.Number -eq 0 } | Select-Object -First 1
$partStyle = if ($sysDisk) { $sysDisk.PartitionStyle } else { 'N/D' }

$result = [pscustomobject]@{
    Computer          = $env:COMPUTERNAME
    Firmware          = $firmware
    SecureBootAttivo  = $sbEnabled
    StilePartizione   = $partStyle
    Idoneo_Win11      = ($sbEnabled -and $partStyle -eq 'GPT')
    Nota              = if (-not $sbSupported) { 'Firmware in BIOS legacy: possibile conversione MBR2GPT + attivazione UEFI/Secure Boot' }
                        elseif (-not $sbEnabled) { 'UEFI presente: attivare Secure Boot nel firmware' }
                        elseif ($partStyle -ne 'GPT') { 'Disco MBR: valutare mbr2gpt.exe' } else { 'OK' }
}
$result | Format-List
$result | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
if ($result.Idoneo_Win11) { Write-Host 'Secure Boot + UEFI + GPT: OK per Windows 11.' -ForegroundColor Green }
else { Write-Host ("Azione richiesta: {0}" -f $result.Nota) -ForegroundColor Yellow }
