#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Riepilogo dello stato di conformità dei dispositivi Intune.
.DESCRIPTION
    Conta i dispositivi gestiti per stato di conformità e per sistema operativo e calcola
    la percentuale di dispositivi conformi. È un indicatore rapido della postura endpoint,
    utile come evidenza per audit e per i report NIS2. Stampa i totali a video ed esporta
    il dettaglio per OS in CSV. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output (dettaglio per OS). Default: .\Intune-ComplianceOverview-<data>.csv
.EXAMPLE
    .\02-Get-IntuneComplianceOverview.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: DeviceManagementManagedDevices.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Intune-ComplianceOverview-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' -NoWelcome

$devices   = Get-MgDeviceManagementManagedDevice -All
$total     = $devices.Count
$compliant = ($devices | Where-Object ComplianceState -EQ 'compliant').Count
$pct       = if ($total) { [math]::Round(($compliant / $total) * 100, 1) } else { 0 }

Write-Host ("Dispositivi totali: {0} · Conformi: {1} ({2}%)" -f $total, $compliant, $pct) -ForegroundColor Green

# Conteggio per stato di conformità (a video)
$devices | Group-Object ComplianceState | Sort-Object Count -Descending |
    Select-Object @{N = 'ComplianceState'; E = { $_.Name } }, Count | Format-Table -AutoSize

# Dettaglio per sistema operativo -> CSV
$byOs = $devices | Group-Object OperatingSystem | ForEach-Object {
    [pscustomobject]@{
        OperatingSystem = $_.Name
        Totale          = $_.Count
        Conformi        = ($_.Group | Where-Object ComplianceState -EQ 'compliant').Count
        NonConformi     = ($_.Group | Where-Object ComplianceState -EQ 'noncompliant').Count
    }
}
$byOs | Sort-Object Totale -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Dettaglio per OS esportato in {0}" -f $OutputCsv) -ForegroundColor Green
