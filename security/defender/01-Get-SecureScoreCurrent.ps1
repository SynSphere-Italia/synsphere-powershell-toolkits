#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Microsoft Secure Score attuale del tenant.
.DESCRIPTION
    Recupera l'ultimo Microsoft Secure Score con punteggio corrente, punteggio massimo e
    percentuale: è l'indicatore sintetico della postura di sicurezza Microsoft 365 e
    Defender. Stampa il valore a video e lo esporta in CSV. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\SecureScore-Current-<data>.csv
.EXAMPLE
    .\01-Get-SecureScoreCurrent.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: SecurityEvents.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\SecureScore-Current-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'SecurityEvents.Read.All' -NoWelcome

$s = Get-MgSecuritySecureScore -Top 1
if (-not $s) { Write-Host 'Nessun Secure Score disponibile.' -ForegroundColor Yellow; return }

$pct = if ($s.MaxScore) { [math]::Round(($s.CurrentScore / $s.MaxScore) * 100, 1) } else { 0 }
$row = [pscustomobject]@{
    Data         = $s.CreatedDateTime
    Punteggio    = [math]::Round($s.CurrentScore, 1)
    Massimo      = [math]::Round($s.MaxScore, 1)
    Percentuale  = $pct
    UtentiAttivi = $s.ActiveUserCount
    Licenziati   = $s.LicensedUserCount
}
$row | Format-List
$row | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Secure Score: {0}/{1} ({2}%) — esportato in {3}" -f $row.Punteggio, $row.Massimo, $pct, $OutputCsv) -ForegroundColor Green
