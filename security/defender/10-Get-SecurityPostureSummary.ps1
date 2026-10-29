#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Cruscotto sintetico della postura di sicurezza (per report NIS2).
.DESCRIPTION
    Riunisce in un'unica vista gli indicatori chiave: Microsoft Secure Score (valore e %),
    avvisi e incidenti aperti per severità e copertura MFA (percentuale di utenti MFA-capaci).
    Stampa un riepilogo leggibile ed esporta una riga di sintesi in CSV, comoda da allegare ai
    report di sicurezza periodici. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Security-PostureSummary-<data>.csv
.EXAMPLE
    .\10-Get-SecurityPostureSummary.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: SecurityEvents.Read.All, SecurityAlert.Read.All, SecurityIncident.Read.All, AuditLog.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Security-PostureSummary-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'SecurityEvents.Read.All', 'SecurityAlert.Read.All', 'SecurityIncident.Read.All', 'AuditLog.Read.All' -NoWelcome

# --- Secure Score ---
$score = Get-MgSecuritySecureScore -Top 1
$scorePct = if ($score -and $score.MaxScore) { [math]::Round(($score.CurrentScore / $score.MaxScore) * 100, 1) } else { $null }

# --- Avvisi aperti per severità ---
$openAlerts = Get-MgSecurityAlertV2 -All | Where-Object Status -NE 'resolved'
$alertHigh = @($openAlerts | Where-Object Severity -EQ 'high').Count
$alertMed  = @($openAlerts | Where-Object Severity -EQ 'medium').Count

# --- Incidenti aperti ---
$openIncidents = @(Get-MgSecurityIncident -All | Where-Object Status -NE 'resolved').Count

# --- Copertura MFA ---
$mfa = Get-MgReportAuthenticationMethodUserRegistrationDetail -All
$mfaTot = @($mfa).Count
$mfaCap = @($mfa | Where-Object IsMfaCapable).Count
$mfaPct = if ($mfaTot) { [math]::Round(($mfaCap / $mfaTot) * 100, 1) } else { $null }

Write-Host ''
Write-Host '=== Postura di sicurezza — sintesi ===' -ForegroundColor Cyan
Write-Host ("Secure Score        : {0}% ({1}/{2})" -f $scorePct, [math]::Round($score.CurrentScore, 1), [math]::Round($score.MaxScore, 1))
Write-Host ("Avvisi aperti       : {0} (high) · {1} (medium)" -f $alertHigh, $alertMed)
Write-Host ("Incidenti aperti    : {0}" -f $openIncidents)
Write-Host ("Copertura MFA       : {0}% ({1}/{2} utenti MFA-capaci)" -f $mfaPct, $mfaCap, $mfaTot)
Write-Host ''

$row = [pscustomobject]@{
    Data              = (Get-Date -Format 'yyyy-MM-dd')
    SecureScorePct    = $scorePct
    SecureScore       = if ($score) { [math]::Round($score.CurrentScore, 1) } else { $null }
    SecureScoreMax    = if ($score) { [math]::Round($score.MaxScore, 1) } else { $null }
    AvvisiHigh        = $alertHigh
    AvvisiMedium      = $alertMed
    IncidentiAperti   = $openIncidents
    MfaCoperturaPct   = $mfaPct
    UtentiMfaCapaci   = $mfaCap
    UtentiTotali      = $mfaTot
}
$row | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Sintesi esportata in {0}" -f $OutputCsv) -ForegroundColor Green
