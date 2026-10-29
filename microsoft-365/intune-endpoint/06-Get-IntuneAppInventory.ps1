#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Inventario delle applicazioni gestite da Intune.
.DESCRIPTION
    Esporta le app pubblicate in Intune (Win32, Microsoft Store, LOB, web link, ecc.) con
    editore, tipo e numero di assegnazioni. Serve a verificare cosa viene distribuito al
    parco e a individuare app orfane (pubblicate ma non assegnate). Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Intune-AppInventory-<data>.csv
.EXAMPLE
    .\06-Get-IntuneAppInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: DeviceManagementApps.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Intune-AppInventory-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'DeviceManagementApps.Read.All' -NoWelcome

$report = foreach ($a in Get-MgDeviceAppManagementMobileApp -ExpandProperty Assignments -All) {
    [pscustomobject]@{
        Nome         = $a.DisplayName
        Editore      = $a.Publisher
        Tipo         = ($a.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.', '')
        Assegnazioni = @($a.Assignments).Count
        Creata       = $a.CreatedDateTime
    }
}

$report | Sort-Object Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} applicazioni in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
