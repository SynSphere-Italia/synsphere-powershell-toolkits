#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Inventario completo dei dispositivi gestiti da Microsoft Intune.
.DESCRIPTION
    Esporta in CSV ogni dispositivo iscritto a Intune con sistema operativo e versione,
    stato di conformità, proprietà (aziendale/personale), produttore, modello, numero di
    serie, utente assegnato e data dell'ultimo check-in. È la fotografia di base del parco
    endpoint gestito. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Intune-DeviceInventory-<data>.csv
.EXAMPLE
    .\01-Get-IntuneDeviceInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: DeviceManagementManagedDevices.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Intune-DeviceInventory-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' -NoWelcome

$report = foreach ($d in Get-MgDeviceManagementManagedDevice -All) {
    [pscustomobject]@{
        DeviceName        = $d.DeviceName
        OperatingSystem   = $d.OperatingSystem
        OSVersion         = $d.OSVersion
        ComplianceState   = $d.ComplianceState
        Ownership         = $d.ManagedDeviceOwnerType
        Manufacturer      = $d.Manufacturer
        Model             = $d.Model
        SerialNumber      = $d.SerialNumber
        UserPrincipalName = $d.UserPrincipalName
        LastSync          = $d.LastSyncDateTime
        Enrolled          = $d.EnrolledDateTime
    }
}

$report | Sort-Object DeviceName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} dispositivi gestiti in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
