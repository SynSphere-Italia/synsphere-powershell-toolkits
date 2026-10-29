#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Inventario dei service principal / enterprise app.
.DESCRIPTION
    Elenca i service principal (enterprise application) del tenant con tipo, stato,
    se richiedono l'assegnazione esplicita degli utenti e il numero di credenziali
    (segreti + certificati) associate. Utile per l'igiene delle app e per capire cosa ha
    accesso al tenant. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-EnterpriseApps-<data>.csv
.EXAMPLE
    .\05-Get-EntraEnterpriseApps.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Application.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Entra-EnterpriseApps-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Application.Read.All' -NoWelcome

$props = 'Id', 'DisplayName', 'AppId', 'ServicePrincipalType', 'AccountEnabled', 'AppRoleAssignmentRequired', 'KeyCredentials', 'PasswordCredentials'
$report = foreach ($sp in Get-MgServicePrincipal -All -Property $props) {
    [pscustomobject]@{
        Nome                  = $sp.DisplayName
        AppId                 = $sp.AppId
        Tipo                  = $sp.ServicePrincipalType
        Abilitato             = $sp.AccountEnabled
        AssegnazioneRichiesta = $sp.AppRoleAssignmentRequired
        Credenziali           = ($sp.KeyCredentials.Count + $sp.PasswordCredentials.Count)
    }
}

$report | Sort-Object Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} service principal -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
