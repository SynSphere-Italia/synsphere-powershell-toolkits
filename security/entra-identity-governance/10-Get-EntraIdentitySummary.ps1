#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Cruscotto sintetico dell'identità (governance Entra ID).
.DESCRIPTION
    Riunisce in un'unica vista gli indicatori chiave di governance dell'identità: numero di
    Global Administrator, app registration totali, credenziali app in scadenza entro 30 giorni,
    service principal e account guest. Stampa un riepilogo leggibile ed esporta una riga di
    sintesi in CSV. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-IdentitySummary-<data>.csv
.EXAMPLE
    .\10-Get-EntraIdentitySummary.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Directory.Read.All, Application.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Entra-IdentitySummary-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Directory.Read.All', 'Application.Read.All' -NoWelcome

# Global Administrator (per roleTemplateId, indipendente dalla lingua)
$gaTemplate = '62e90394-69f5-4237-9190-012177145e10'
$gaRole = Get-MgDirectoryRole -Filter "roleTemplateId eq '$gaTemplate'" -ErrorAction SilentlyContinue
$gaCount = if ($gaRole) { @(Get-MgDirectoryRoleMember -DirectoryRoleId $gaRole.Id -All).Count } else { 0 }

# App registration + credenziali in scadenza a 30 giorni
$apps = Get-MgApplication -All -Property Id, DisplayName, PasswordCredentials, KeyCredentials
$cutoff = (Get-Date).AddDays(30)
$expiring = 0
foreach ($a in $apps) {
    $expiring += @($a.PasswordCredentials | Where-Object { $_.EndDateTime -le $cutoff }).Count
    $expiring += @($a.KeyCredentials | Where-Object { $_.EndDateTime -le $cutoff }).Count
}

$guestCount = @(Get-MgUser -All -Filter "userType eq 'Guest'" -Property Id).Count
$spCount = @(Get-MgServicePrincipal -All -Property Id).Count

Write-Host ''
Write-Host '=== Governance identità — sintesi ===' -ForegroundColor Cyan
Write-Host ("Global Administrator            : {0}" -f $gaCount)
Write-Host ("App registration                : {0}" -f $apps.Count)
Write-Host ("Credenziali scadute o in scad. 30gg: {0}" -f $expiring)
Write-Host ("Service principal (enterprise)  : {0}" -f $spCount)
Write-Host ("Account guest                   : {0}" -f $guestCount)
Write-Host ''

$row = [pscustomobject]@{
    Data                 = (Get-Date -Format 'yyyy-MM-dd')
    GlobalAdmin          = $gaCount
    AppRegistration      = $apps.Count
    CredScaduteOInScad30gg = $expiring
    ServicePrincipal     = $spCount
    Guest                = $guestCount
}
$row | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Sintesi esportata in {0}" -f $OutputCsv) -ForegroundColor Green
