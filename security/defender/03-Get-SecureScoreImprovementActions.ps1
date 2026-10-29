#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Azioni di miglioramento Secure Score con il gap di punteggio più alto.
.DESCRIPTION
    Incrocia i punteggi per controllo dell'ultimo Secure Score con il punteggio massimo di
    ogni control profile e calcola il "gap" (punti ancora ottenibili). Ordina i controlli
    dal gap maggiore al minore: è la lista di priorità concreta per alzare la postura di
    sicurezza. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\SecureScore-Actions-<data>.csv
.EXAMPLE
    .\03-Get-SecureScoreImprovementActions.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: SecurityEvents.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\SecureScore-Actions-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'SecurityEvents.Read.All' -NoWelcome

$score = Get-MgSecuritySecureScore -Top 1
if (-not $score) { Write-Host 'Nessun Secure Score disponibile.' -ForegroundColor Yellow; return }

# Mappa: Id del control profile -> punteggio massimo
$maxById = @{}
Get-MgSecuritySecureScoreControlProfile -All | ForEach-Object { $maxById[$_.Id] = $_.MaxScore }

$report = foreach ($c in $score.ControlScores) {
    $max = $maxById[$c.ControlName]
    [pscustomobject]@{
        Controllo = $c.ControlName
        Categoria = $c.ControlCategory
        Punteggio = [math]::Round(($c.Score), 1)
        Massimo   = if ($null -ne $max) { [math]::Round($max, 1) } else { $null }
        Gap       = if ($null -ne $max) { [math]::Round(($max - $c.Score), 1) } else { $null }
    }
}

$report = $report | Where-Object { $_.Gap -gt 0 } | Sort-Object Gap -Descending
$report | Select-Object -First 15 | Format-Table -AutoSize
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovate {0} azioni con margine di miglioramento -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
