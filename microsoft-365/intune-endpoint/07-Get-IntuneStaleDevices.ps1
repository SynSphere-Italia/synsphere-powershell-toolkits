#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Dispositivi Intune inattivi (nessun check-in da N giorni).
.DESCRIPTION
    Individua i dispositivi che non sincronizzano con Intune da più giorni della soglia
    indicata: sono candidati alla pulizia (dismessi, riformattati o smarriti) e possono
    falsare i numeri di conformità. Sola lettura — non rimuove nulla.
.PARAMETER DaysInactive
    Soglia di inattività in giorni. Default: 30.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Intune-StaleDevices-<data>.csv
.EXAMPLE
    .\07-Get-IntuneStaleDevices.ps1 -DaysInactive 60
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: DeviceManagementManagedDevices.Read.All
#>
[CmdletBinding()]
param(
    [int]$DaysInactive = 30,
    [string]$OutputCsv = (".\Intune-StaleDevices-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' -NoWelcome

$cutoff = (Get-Date).AddDays(-$DaysInactive)
$report = foreach ($d in Get-MgDeviceManagementManagedDevice -All | Where-Object { $_.LastSyncDateTime -lt $cutoff }) {
    [pscustomobject]@{
        DeviceName        = $d.DeviceName
        OperatingSystem   = $d.OperatingSystem
        UserPrincipalName = $d.UserPrincipalName
        Ownership         = $d.ManagedDeviceOwnerType
        LastSync          = $d.LastSyncDateTime
        GiorniInattivo    = [int]((Get-Date) - $d.LastSyncDateTime).TotalDays
    }
}

$report | Sort-Object GiorniInattivo -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovati {0} dispositivi inattivi da oltre {1} giorni -> {2}" -f $report.Count, $DaysInactive, $OutputCsv) -ForegroundColor Green
