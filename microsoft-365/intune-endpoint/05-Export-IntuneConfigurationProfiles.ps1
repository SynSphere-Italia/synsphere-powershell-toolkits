#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Esporta i profili di configurazione Intune e le relative assegnazioni.
.DESCRIPTION
    Elenca i device configuration profile (impostazioni dispositivo, restrizioni, VPN,
    Wi-Fi, certificati, ecc.) con tipo, data di ultima modifica e numero di gruppi
    assegnati. Fotografa la configurazione applicata al parco per audit e change control.
    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Intune-ConfigProfiles-<data>.csv
.EXAMPLE
    .\05-Export-IntuneConfigurationProfiles.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: DeviceManagementConfiguration.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Intune-ConfigProfiles-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'DeviceManagementConfiguration.Read.All' -NoWelcome

$report = foreach ($p in Get-MgDeviceManagementDeviceConfiguration -ExpandProperty Assignments -All) {
    [pscustomobject]@{
        Nome           = $p.DisplayName
        Tipo           = ($p.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.', '')
        UltimaModifica = $p.LastModifiedDateTime
        Assegnazioni   = @($p.Assignments).Count
    }
}

$report | Sort-Object Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} profili di configurazione in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
