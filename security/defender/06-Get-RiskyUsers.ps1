#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Utenti a rischio rilevati da Microsoft Entra ID Protection.
.DESCRIPTION
    Elenca gli utenti con un livello di rischio segnalato da Identity Protection (login
    anomali, credenziali trapelate, ecc.) filtrando di default quelli non ancora bonificati,
    con livello e stato del rischio. Sono gli account da verificare per primi. Sola lettura.
.PARAMETER IncludeRemediated
    Se presente, include anche gli utenti con rischio già risolto/ignorato.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-RiskyUsers-<data>.csv
.EXAMPLE
    .\06-Get-RiskyUsers.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: IdentityRiskyUser.Read.All
    Richiede una licenza Microsoft Entra ID P2 per i dati completi di Identity Protection.
#>
[CmdletBinding()]
param(
    [switch]$IncludeRemediated,
    [string]$OutputCsv = (".\Entra-RiskyUsers-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'IdentityRiskyUser.Read.All' -NoWelcome

$users = Get-MgRiskyUser -All
if (-not $IncludeRemediated) { $users = $users | Where-Object { $_.RiskState -notin @('remediated', 'dismissed') } }

$report = foreach ($u in $users) {
    [pscustomobject]@{
        UserPrincipalName = $u.UserPrincipalName
        DisplayName       = $u.UserDisplayName
        LivelloRischio    = $u.RiskLevel
        StatoRischio      = $u.RiskState
        UltimoUpdate      = $u.RiskLastUpdatedDateTime
    }
}

$report | Sort-Object LivelloRischio | Format-Table -AutoSize
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovati {0} utenti a rischio -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
