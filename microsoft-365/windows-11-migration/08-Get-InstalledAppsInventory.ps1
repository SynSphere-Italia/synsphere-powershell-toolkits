<#
.SYNOPSIS
    Inventario delle applicazioni installate (snapshot pre-upgrade).
.DESCRIPTION
    Esporta l'elenco dei software installati leggendo le chiavi di disinstallazione del
    registro (32 e 64 bit): nome, versione, editore, data. Serve come "foto" prima
    dell'upgrade a Windows 11, per verificare a valle che nulla sia sparito o vada
    reinstallato. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\InstalledApps-<computer>-<data>.csv
.EXAMPLE
    .\08-Get-InstalledAppsInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\InstalledApps-{0}-{1}.csv" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'

$keys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$apps = Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } |
    Select-Object @{n='Nome';e={$_.DisplayName}},
                  @{n='Versione';e={$_.DisplayVersion}},
                  @{n='Editore';e={$_.Publisher}},
                  @{n='DataInstall';e={$_.InstallDate}} |
    Sort-Object Nome -Unique

$apps | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$apps | Format-Table -AutoSize
Write-Host ("{0} applicazioni → {1}" -f $apps.Count, $OutputCsv) -ForegroundColor Green
