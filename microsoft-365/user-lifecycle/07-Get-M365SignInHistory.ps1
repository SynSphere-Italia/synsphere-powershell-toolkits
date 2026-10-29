#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Storico accessi (sign-in logs) Microsoft 365 degli ultimi N giorni.
.DESCRIPTION
    Esporta gli eventi di accesso da Microsoft Entra: utente, data, app, IP, esito e
    località. Utile per rilevare accessi sospetti e analisi di sicurezza. Sola lettura.
    NB: richiede Microsoft Entra ID P1/P2 (i sign-in logs non sono disponibili nel piano Free).
.PARAMETER Days
    Finestra in giorni. Default: 7. I log di Entra conservano max 30 giorni.
.PARAMETER UserPrincipalName
    Opzionale: filtra gli accessi di un singolo utente.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-SignInHistory-<data>.csv
.EXAMPLE
    .\07-Get-M365SignInHistory.ps1 -Days 14
.EXAMPLE
    .\07-Get-M365SignInHistory.ps1 -UserPrincipalName mario.rossi@azienda.it -Days 30
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: AuditLog.Read.All
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$UserPrincipalName,
    [string]$OutputCsv = (".\M365-SignInHistory-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'AuditLog.Read.All' -NoWelcome

$since = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
$filter = "createdDateTime ge $since"
if ($UserPrincipalName) { $filter += " and userPrincipalName eq '$UserPrincipalName'" }

$report = foreach ($s in Get-MgAuditLogSignIn -Filter $filter -All) {
    [pscustomobject]@{
        CreatedDateTime   = $s.CreatedDateTime
        UserPrincipalName = $s.UserPrincipalName
        App               = $s.AppDisplayName
        IpAddress         = $s.IpAddress
        City              = $s.Location.City
        Country           = $s.Location.CountryOrRegion
        ClientApp         = $s.ClientAppUsed
        Status            = if ($s.Status.ErrorCode -eq 0) { 'Success' } else { "Failure ($($s.Status.ErrorCode))" }
    }
}
$report | Sort-Object CreatedDateTime -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} eventi di accesso (ultimi {1} giorni) → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
