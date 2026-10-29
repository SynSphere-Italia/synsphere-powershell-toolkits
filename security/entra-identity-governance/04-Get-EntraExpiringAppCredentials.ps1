#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Segreti e certificati delle app registration in scadenza.
.DESCRIPTION
    Analizza tutte le app registration e segnala i segreti (client secret) e i certificati
    che scadono entro N giorni — inclusi quelli già scaduti (giorni negativi). È il controllo
    che evita il classico blocco: "l'integrazione ha smesso di funzionare" per una credenziale
    scaduta. Sola lettura.
    NOTA: copre le app registration. Per i service principal (enterprise app) vedi lo script 05.
.PARAMETER Days
    Finestra di scadenza in giorni. Default: 30.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-ExpiringAppCredentials-<data>.csv
.EXAMPLE
    .\04-Get-EntraExpiringAppCredentials.ps1 -Days 60
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Application.Read.All
#>
[CmdletBinding()]
param(
    [int]$Days = 30,
    [string]$OutputCsv = (".\Entra-ExpiringAppCredentials-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Application.Read.All' -NoWelcome

$cutoff = (Get-Date).AddDays($Days)
$report = foreach ($a in Get-MgApplication -All -Property Id, AppId, DisplayName, PasswordCredentials, KeyCredentials) {
    foreach ($c in $a.PasswordCredentials) {
        if ($c.EndDateTime -le $cutoff) {
            [pscustomobject]@{
                App               = $a.DisplayName
                AppId             = $a.AppId
                Tipo              = 'Client secret'
                Nome              = $c.DisplayName
                Scadenza          = $c.EndDateTime
                GiorniAllaScadenza = [int](($c.EndDateTime) - (Get-Date)).TotalDays
            }
        }
    }
    foreach ($k in $a.KeyCredentials) {
        if ($k.EndDateTime -le $cutoff) {
            [pscustomobject]@{
                App               = $a.DisplayName
                AppId             = $a.AppId
                Tipo              = ('Certificato ' + $k.Type)
                Nome              = $k.DisplayName
                Scadenza          = $k.EndDateTime
                GiorniAllaScadenza = [int](($k.EndDateTime) - (Get-Date)).TotalDays
            }
        }
    }
}

$report = $report | Sort-Object Scadenza
$report | Select-Object -First 20 | Format-Table App, Tipo, Scadenza, GiorniAllaScadenza -AutoSize
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovate {0} credenziali in scadenza entro {1} giorni (o già scadute) -> {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
