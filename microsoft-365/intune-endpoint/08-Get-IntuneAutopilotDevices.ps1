#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Dispositivi Windows Autopilot registrati nel tenant.
.DESCRIPTION
    Elenca i dispositivi registrati per Windows Autopilot con numero di serie, produttore,
    modello, group tag, stato di iscrizione e stato di assegnazione del profilo di
    deployment. Utile per verificare che ogni PC nuovo/riformattato sia pronto per lo
    zero-touch provisioning. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Intune-AutopilotDevices-<data>.csv
.EXAMPLE
    .\08-Get-IntuneAutopilotDevices.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: DeviceManagementServiceConfig.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Intune-AutopilotDevices-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'DeviceManagementServiceConfig.Read.All' -NoWelcome

$report = foreach ($a in Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -All) {
    [pscustomobject]@{
        SerialNumber  = $a.SerialNumber
        Manufacturer  = $a.Manufacturer
        Model         = $a.Model
        GroupTag      = $a.GroupTag
        Enrollment    = $a.EnrollmentState
        ProfileStatus = $a.DeploymentProfileAssignmentStatus
        LastContact   = $a.LastContactedDateTime
    }
}

$report | Sort-Object Model, SerialNumber | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} dispositivi Autopilot in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
