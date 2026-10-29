#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report versioni Windows sui dispositivi gestiti (Windows 10 vs Windows 11).
.DESCRIPTION
    Analizza i dispositivi Windows gestiti da Intune, deduce dalla build se sono Windows 10
    o Windows 11 (build >= 22000 = Windows 11) e produce sia un riepilogo a video sia un
    CSV per dispositivo. Serve a dimensionare la migrazione a Windows 11 su tutta la flotta
    senza toccare i singoli PC. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Intune-WindowsVersions-<data>.csv
.EXAMPLE
    .\09-Get-IntuneWindowsVersionReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: DeviceManagementManagedDevices.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Intune-WindowsVersions-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' -NoWelcome

$win = Get-MgDeviceManagementManagedDevice -All | Where-Object OperatingSystem -EQ 'Windows'
$report = foreach ($d in $win) {
    # OSVersion tipico: "10.0.19045.3803" -> il terzo segmento è la build (19045, 22631, ...)
    $build = 0
    [void][int]::TryParse((($d.OSVersion -split '\.')[2]), [ref]$build)
    $release = if ($build -ge 22000) { 'Windows 11' }
    elseif ($build -gt 0) { 'Windows 10' }
    else { 'Windows (n/d)' }

    [pscustomobject]@{
        DeviceName        = $d.DeviceName
        Release           = $release
        OSVersion         = $d.OSVersion
        Build             = $build
        UserPrincipalName = $d.UserPrincipalName
        LastSync          = $d.LastSyncDateTime
    }
}

# Riepilogo a video: quanti PC per release
$report | Group-Object Release | Sort-Object Count -Descending |
    Select-Object @{N = 'Release'; E = { $_.Name } }, Count | Format-Table -AutoSize

$report | Sort-Object Release, DeviceName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Analizzati {0} PC Windows -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
