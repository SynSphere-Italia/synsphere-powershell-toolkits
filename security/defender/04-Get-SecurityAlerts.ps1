#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Avvisi di sicurezza Microsoft Defender (alerts v2).
.DESCRIPTION
    Estrae gli avvisi di sicurezza dell'API unificata (Microsoft 365 Defender) filtrando di
    default quelli non ancora risolti, con severità, stato, categoria, prodotto di origine e
    data. Ordina per severità per la triage. Sola lettura.
.PARAMETER IncludeResolved
    Se presente, include anche gli avvisi già risolti.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Defender-Alerts-<data>.csv
.EXAMPLE
    .\04-Get-SecurityAlerts.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: SecurityAlert.Read.All
#>
[CmdletBinding()]
param(
    [switch]$IncludeResolved,
    [string]$OutputCsv = (".\Defender-Alerts-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'SecurityAlert.Read.All' -NoWelcome

$alerts = Get-MgSecurityAlertV2 -All
if (-not $IncludeResolved) { $alerts = $alerts | Where-Object Status -NE 'resolved' }

# Ordine di severità per la triage
$sevOrder = @{ high = 0; medium = 1; low = 2; informational = 3 }
$report = foreach ($a in $alerts) {
    [pscustomobject]@{
        Severita   = $a.Severity
        Stato      = $a.Status
        Titolo     = $a.Title
        Categoria  = $a.Category
        Prodotto   = $a.ServiceSource
        Creato     = $a.CreatedDateTime
        Id         = $a.Id
    }
}

$report = $report | Sort-Object @{ E = { $sevOrder[[string]$_.Severita] } }, Creato -Descending
$report | Select-Object -First 20 | Format-Table Severita, Stato, Titolo, Prodotto -AutoSize
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} avvisi -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
