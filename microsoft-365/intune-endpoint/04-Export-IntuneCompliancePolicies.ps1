#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Esporta le policy di conformità Intune e le relative assegnazioni.
.DESCRIPTION
    Elenca ogni criterio di conformità (device compliance policy) con la piattaforma di
    riferimento, la data di ultima modifica e il numero di gruppi a cui è assegnato.
    Utile per documentare la postura di sicurezza degli endpoint e verificare che ogni
    piattaforma abbia una policy attiva e assegnata. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Intune-CompliancePolicies-<data>.csv
.EXAMPLE
    .\04-Export-IntuneCompliancePolicies.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: DeviceManagementConfiguration.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Intune-CompliancePolicies-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'DeviceManagementConfiguration.Read.All' -NoWelcome

$report = foreach ($p in Get-MgDeviceManagementDeviceCompliancePolicy -ExpandProperty Assignments -All) {
    [pscustomobject]@{
        Nome           = $p.DisplayName
        Piattaforma    = ($p.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.', '' -replace 'CompliancePolicy$', '')
        UltimaModifica = $p.LastModifiedDateTime
        Assegnazioni   = @($p.Assignments).Count
    }
}

$report | Sort-Object Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} policy di conformità in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
