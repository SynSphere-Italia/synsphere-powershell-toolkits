<#
.SYNOPSIS
    Avvia l'upgrade in-place a Windows 11 da supporto/ISO (con controlli preliminari).
.DESCRIPTION
    Esegue un upgrade in-place NON distruttivo (mantiene app, impostazioni e file) usando
    il setup.exe di un supporto Windows 11 (ISO montata, chiavetta o cartella). Prima di
    partire verifica idoneità di base (Secure Boot, RAM, spazio disco) e alimentazione AC,
    e raccomanda di aver esportato le chiavi BitLocker (script 07). Supporta -WhatIf.
    ATTENZIONE: operazione che riavvia il PC. NON eseguire in orario lavorativo senza avviso.
.PARAMETER SetupPath
    Percorso di setup.exe del supporto Windows 11 (es. D:\setup.exe).
.PARAMETER EulaAccept
    Obbligatorio: conferma accettazione dei termini di licenza Microsoft.
.PARAMETER SuspendBitLocker
    Sospende BitLocker per 1 riavvio (evita il prompt della chiave al reboot).
.EXAMPLE
    .\09-Invoke-Windows11Upgrade.ps1 -SetupPath D:\setup.exe -EulaAccept -WhatIf
.EXAMPLE
    .\09-Invoke-Windows11Upgrade.ps1 -SetupPath D:\setup.exe -EulaAccept -SuspendBitLocker
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Eseguire come amministratore.
    Finestra di rollback a Windows 10: circa 10 giorni dopo l'upgrade.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$SetupPath,
    [Parameter(Mandatory)][switch]$EulaAccept,
    [switch]$SuspendBitLocker,
    [string]$LogDir = "$env:ProgramData\SynSphere\Win11Upgrade"
)
$ErrorActionPreference = 'Stop'
if (-not $EulaAccept) { throw 'Specificare -EulaAccept per confermare i termini di licenza Microsoft.' }
if (-not (Test-Path $SetupPath)) { throw "setup.exe non trovato: $SetupPath" }

# Controlli preliminari (bloccanti)
$sb = $false; try { $sb = Confirm-SecureBootUEFI } catch {}
$freeGb = [math]::Round((Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'").FreeSpace / 1GB, 1)
$ramGb  = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
$battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
$onAC = -not $battery -or $battery.BatteryStatus -in 2, 3, 6, 7, 8   # 2 = alimentazione di rete

$block = @()
if (-not $sb)          { $block += 'Secure Boot/UEFI non attivo' }
if ($ramGb -lt 4)      { $block += "RAM $ramGb GB (<4)" }
if ($freeGb -lt 25)    { $block += "spazio libero $freeGb GB (<25)" }
if (-not $onAC)        { $block += 'PC a batteria: collegare l''alimentatore' }
if ($block) { throw ("Precondizioni non soddisfatte: {0}. Risolvere prima di procedere." -f ($block -join '; ')) }

Write-Warning 'Assicurati di aver esportato le chiavi BitLocker (script 07) e informato l''utente: il PC si riavviera.'

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$args = @('/auto', 'upgrade', '/quiet', '/eula', 'accept', '/dynamicupdate', 'enable', '/copylogs', $LogDir)

if ($SuspendBitLocker -and $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Sospendi BitLocker per 1 riavvio')) {
    Get-BitLockerVolume | Where-Object { $_.ProtectionStatus -eq 'On' } | ForEach-Object { Suspend-BitLocker -MountPoint $_.MountPoint -RebootCount 1 | Out-Null }
}

if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Upgrade in-place a Windows 11 (setup.exe $args)")) {
    Write-Host 'Avvio upgrade in-place a Windows 11…' -ForegroundColor Green
    Start-Process -FilePath $SetupPath -ArgumentList $args -Wait
    Write-Host ("Upgrade avviato. Log in {0}. Il PC completera l'installazione con alcuni riavvii." -f $LogDir) -ForegroundColor Green
} else {
    Write-Host '[WhatIf] Nessuna modifica effettuata. Precondizioni verificate OK.' -ForegroundColor Cyan
}
