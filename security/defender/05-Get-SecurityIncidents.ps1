#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Incidenti di sicurezza Microsoft 365 Defender.
.DESCRIPTION
    Estrae gli incidenti (raggruppamenti correlati di avvisi) filtrando di default quelli
    non ancora risolti, con severità, stato, classificazione, numero di avvisi correlati e
    data. È la vista di alto livello per il monitoraggio della sicurezza. Sola lettura.
.PARAMETER IncludeResolved
    Se presente, include anche gli incidenti già risolti.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Defender-Incidents-<data>.csv
.EXAMPLE
    .\05-Get-SecurityIncidents.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: SecurityIncident.Read.All
#>
[CmdletBinding()]
param(
    [switch]$IncludeResolved,
    [string]$OutputCsv = (".\Defender-Incidents-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'SecurityIncident.Read.All' -NoWelcome

$incidents = Get-MgSecurityIncident -All
if (-not $IncludeResolved) { $incidents = $incidents | Where-Object Status -NE 'resolved' }

$report = foreach ($i in $incidents) {
    [pscustomobject]@{
        Severita       = $i.Severity
        Stato          = $i.Status
        Titolo         = $i.DisplayName
        Classificazione = $i.Classification
        Determinazione = $i.Determination
        Assegnato      = $i.AssignedTo
        Creato         = $i.CreatedDateTime
        Id             = $i.Id
    }
}

$report | Sort-Object Creato -Descending | Select-Object -First 20 | Format-Table Severita, Stato, Titolo, Assegnato -AutoSize
$report | Sort-Object Creato -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} incidenti -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
