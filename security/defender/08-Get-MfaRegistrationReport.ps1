#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Stato di registrazione MFA e SSPR per utente.
.DESCRIPTION
    Usa il report ufficiale dei metodi di autenticazione per elencare, utente per utente, se
    è capace/registrato per MFA e SSPR, i metodi registrati e se è un amministratore.
    Evidenzia gli account (specie admin) SENZA MFA: la lacuna di sicurezza più comune e più
    grave. Sola lettura.
.PARAMETER OnlyGaps
    Se presente, esporta solo gli utenti NON capaci di MFA (le lacune da chiudere).
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\MFA-Registration-<data>.csv
.EXAMPLE
    .\08-Get-MfaRegistrationReport.ps1 -OnlyGaps
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: AuditLog.Read.All
#>
[CmdletBinding()]
param(
    [switch]$OnlyGaps,
    [string]$OutputCsv = (".\MFA-Registration-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'AuditLog.Read.All' -NoWelcome

$details = Get-MgReportAuthenticationMethodUserRegistrationDetail -All
if ($OnlyGaps) { $details = $details | Where-Object { -not $_.IsMfaCapable } }

$report = foreach ($u in $details) {
    [pscustomobject]@{
        UserPrincipalName = $u.UserPrincipalName
        DisplayName       = $u.UserDisplayName
        Admin             = $u.IsAdmin
        MfaCapable        = $u.IsMfaCapable
        MfaRegistered     = $u.IsMfaRegistered
        SsprCapable       = $u.IsSsprCapable
        Metodi            = ($u.MethodsRegistered -join '; ')
    }
}

$totale   = @($report).Count
$capaci   = @($report | Where-Object MfaCapable).Count
Write-Host ("Utenti nel report: {0} · MFA-capaci: {1}" -f $totale, $capaci) -ForegroundColor Green
$report | Where-Object { $_.Admin -and -not $_.MfaCapable } | Format-Table UserPrincipalName, Admin, MfaCapable -AutoSize
$report | Sort-Object MfaCapable, UserPrincipalName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Report esportato in {0}" -f $OutputCsv) -ForegroundColor Green
