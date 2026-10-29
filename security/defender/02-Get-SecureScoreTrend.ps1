#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Andamento del Microsoft Secure Score negli ultimi giorni.
.DESCRIPTION
    Recupera gli ultimi N rilevamenti giornalieri del Secure Score e ne mostra il trend
    (punteggio, massimo e percentuale per data), per capire se la postura di sicurezza sta
    migliorando o peggiorando. Utile da allegare ai report periodici. Sola lettura.
.PARAMETER Days
    Numero di rilevamenti (giorni) da recuperare. Default: 30.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\SecureScore-Trend-<data>.csv
.EXAMPLE
    .\02-Get-SecureScoreTrend.ps1 -Days 90
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: SecurityEvents.Read.All
#>
[CmdletBinding()]
param(
    [int]$Days = 30,
    [string]$OutputCsv = (".\SecureScore-Trend-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'SecurityEvents.Read.All' -NoWelcome

$report = foreach ($s in Get-MgSecuritySecureScore -Top $Days) {
    [pscustomobject]@{
        Data        = $s.CreatedDateTime
        Punteggio   = [math]::Round($s.CurrentScore, 1)
        Massimo     = [math]::Round($s.MaxScore, 1)
        Percentuale = if ($s.MaxScore) { [math]::Round(($s.CurrentScore / $s.MaxScore) * 100, 1) } else { 0 }
    }
}

$report | Sort-Object Data | Format-Table -AutoSize
$report | Sort-Object Data | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} rilevamenti Secure Score in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
