#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Elenco dei dispositivi Intune non conformi.
.DESCRIPTION
    Estrae i dispositivi il cui stato di conformità non è "compliant" (non conformi,
    in errore, in attesa di valutazione o in periodo di tolleranza) con OS, versione,
    utente, proprietà e ultimo check-in, per intervenire in modo mirato prima che scattino
    i blocchi degli accessi condizionali. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Intune-NonCompliant-<data>.csv
.EXAMPLE
    .\03-Get-IntuneNonCompliantDevices.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: DeviceManagementManagedDevices.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Intune-NonCompliant-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' -NoWelcome

$report = foreach ($d in Get-MgDeviceManagementManagedDevice -All | Where-Object ComplianceState -NE 'compliant') {
    [pscustomobject]@{
        DeviceName        = $d.DeviceName
        ComplianceState   = $d.ComplianceState
        OperatingSystem   = $d.OperatingSystem
        OSVersion         = $d.OSVersion
        UserPrincipalName = $d.UserPrincipalName
        Ownership         = $d.ManagedDeviceOwnerType
        LastSync          = $d.LastSyncDateTime
    }
}

$report | Sort-Object ComplianceState, DeviceName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovati {0} dispositivi non conformi -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
