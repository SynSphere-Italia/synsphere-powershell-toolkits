#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Rilevamenti di rischio recenti di Microsoft Entra ID Protection.
.DESCRIPTION
    Estrae i risk detection (viaggio impossibile, IP anonimo, credenziali trapelate, ecc.)
    con tipo, livello, stato, utente, indirizzo IP e posizione. Complementa il report degli
    utenti a rischio con il dettaglio dei singoli eventi. Sola lettura.
.PARAMETER Top
    Numero massimo di rilevamenti da recuperare (più recenti). Default: 200.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-RiskDetections-<data>.csv
.EXAMPLE
    .\07-Get-RiskDetections.ps1 -Top 500
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: IdentityRiskEvent.Read.All
#>
[CmdletBinding()]
param(
    [int]$Top = 200,
    [string]$OutputCsv = (".\Entra-RiskDetections-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'IdentityRiskEvent.Read.All' -NoWelcome

$report = foreach ($r in Get-MgRiskDetection -Top $Top) {
    [pscustomobject]@{
        Utente        = $r.UserPrincipalName
        Tipo          = $r.RiskEventType
        Livello       = $r.RiskLevel
        Stato         = $r.RiskState
        IP            = $r.IPAddress
        Citta         = $r.Location.City
        Paese         = $r.Location.CountryOrRegion
        Rilevato      = $r.DetectedDateTime
    }
}

$report | Sort-Object Rilevato -Descending | Select-Object -First 20 | Format-Table Utente, Tipo, Livello, Paese -AutoSize
$report | Sort-Object Rilevato -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} rilevamenti di rischio -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
