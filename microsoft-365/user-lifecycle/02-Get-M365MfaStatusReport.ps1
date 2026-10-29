#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report stato MFA degli utenti Microsoft 365 (autenticazione moderna).
.DESCRIPTION
    Usa il report ufficiale "authentication method registration details" di Microsoft
    Entra: per ogni utente indica se è registrato/capace MFA e i metodi configurati.
    Sostituisce il vecchio approccio MSOnline (StrongAuthenticationMethods), deprecato.
    Sola lettura. Evidenzia gli utenti SENZA MFA (rischio di sicurezza).
.PARAMETER OnlyWithoutMfa
    Se presente, esporta solo gli utenti NON registrati a MFA.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-MfaStatus-<data>.csv
.EXAMPLE
    .\02-Get-M365MfaStatusReport.ps1 -OnlyWithoutMfa
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: AuditLog.Read.All (e UserAuthenticationMethod.Read.All)
#>
[CmdletBinding()]
param(
    [switch]$OnlyWithoutMfa,
    [string]$OutputCsv = (".\M365-MfaStatus-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'AuditLog.Read.All', 'UserAuthenticationMethod.Read.All' -NoWelcome

$details = Get-MgReportAuthenticationMethodUserRegistrationDetail -All
if ($OnlyWithoutMfa) { $details = $details | Where-Object { -not $_.IsMfaRegistered } }

$report = foreach ($d in $details) {
    [pscustomobject]@{
        UserPrincipalName = $d.UserPrincipalName
        DisplayName       = $d.UserDisplayName
        IsAdmin           = $d.IsAdmin
        MfaRegistered     = $d.IsMfaRegistered
        MfaCapable        = $d.IsMfaCapable
        MethodsRegistered = ($d.MethodsRegistered -join '; ')
    }
}
$report | Sort-Object MfaRegistered, DisplayName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$senza = ($report | Where-Object { -not $_.MfaRegistered }).Count
Write-Host ("Esportati {0} utenti. SENZA MFA: {1} (priorità di sicurezza) → {2}" -f $report.Count, $senza, $OutputCsv) -ForegroundColor Yellow
