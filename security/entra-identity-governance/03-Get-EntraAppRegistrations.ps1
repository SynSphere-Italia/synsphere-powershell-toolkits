#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Inventario delle app registration del tenant con owner.
.DESCRIPTION
    Elenca tutte le applicazioni registrate (app registrations) con appId, data di
    creazione, tipo di audience e numero di owner. Serve a mappare le integrazioni e a
    individuare app senza owner (rischio di abbandono). Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-AppRegistrations-<data>.csv
.EXAMPLE
    .\03-Get-EntraAppRegistrations.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Application.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Entra-AppRegistrations-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Application.Read.All' -NoWelcome

$report = foreach ($a in Get-MgApplication -All) {
    $ownerCount = @(Get-MgApplicationOwner -ApplicationId $a.Id -All).Count
    [pscustomobject]@{
        Nome            = $a.DisplayName
        AppId           = $a.AppId
        Creata          = $a.CreatedDateTime
        SignInAudience  = $a.SignInAudience
        PublisherDomain = $a.PublisherDomain
        Owner           = $ownerCount
    }
}

$report | Sort-Object Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} app registration -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
