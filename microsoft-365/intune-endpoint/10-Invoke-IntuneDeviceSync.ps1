#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Forza il check-in (sync) remoto di uno o più dispositivi Intune.
.DESCRIPTION
    Invia il comando di sincronizzazione a Intune per i dispositivi il cui nome corrisponde
    al filtro indicato, così da applicare subito policy, profili e app senza aspettare il
    ciclo automatico. È l'UNICO script del toolkit che esegue un'azione (di scrittura):
    supporta -WhatIf per una prova a vuoto e, essendo ConfirmImpact High, chiede conferma
    prima di agire su ciascun dispositivo.
.PARAMETER DeviceNameLike
    Filtro sul nome dispositivo (wildcard). Es. 'NB-*' per tutti i notebook, oppure il nome
    esatto di un singolo PC.
.PARAMETER WhatIf
    Mostra i dispositivi che verrebbero sincronizzati senza inviare il comando.
.EXAMPLE
    .\10-Invoke-IntuneDeviceSync.ps1 -DeviceNameLike 'NB-*' -WhatIf
.EXAMPLE
    .\10-Invoke-IntuneDeviceSync.ps1 -DeviceNameLike 'NB-MILANO-07'
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: DeviceManagementManagedDevices.PrivilegedOperations.All + .Read.All
    Richiede il cmdlet Sync-MgDeviceManagementManagedDevice (Microsoft.Graph.DeviceManagement.Actions).
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [string]$DeviceNameLike
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.PrivilegedOperations.All', 'DeviceManagementManagedDevices.Read.All' -NoWelcome

$targets = Get-MgDeviceManagementManagedDevice -All | Where-Object { $_.DeviceName -like $DeviceNameLike }
if (-not $targets) {
    Write-Host ("Nessun dispositivo corrisponde a '{0}'." -f $DeviceNameLike) -ForegroundColor Yellow
    return
}

Write-Host ("Dispositivi selezionati: {0}" -f @($targets).Count) -ForegroundColor Cyan
$targets | Select-Object DeviceName, OperatingSystem, UserPrincipalName, LastSyncDateTime | Format-Table -AutoSize

$done = 0
foreach ($d in $targets) {
    if ($PSCmdlet.ShouldProcess($d.DeviceName, 'Sync Intune (check-in remoto)')) {
        Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $d.Id
        $done++
    }
}
Write-Host ("Comando di sync inviato a {0} dispositivi." -f $done) -ForegroundColor Green
