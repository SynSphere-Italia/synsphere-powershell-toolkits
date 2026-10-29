#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Riepilogo attività per utente: accessi totali, falliti, ultimo accesso, app distinte.
.DESCRIPTION
    Aggrega i sign-in logs degli ultimi N giorni per utente (rollup), invece del dettaglio
    evento per evento. Utile per individuare account molto attivi, molti accessi falliti
    (possibile attacco) o account fermi. Sola lettura.
.PARAMETER Days
    Finestra in giorni. Default: 30 (massimo di retention dei log Entra).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-UserActivitySummary-<data>.csv
.EXAMPLE
    .\08-Get-M365UserActivitySummary.ps1 -Days 14
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: AuditLog.Read.All (Entra ID P1/P2)
#>
[CmdletBinding()]
param(
    [int]$Days = 30,
    [string]$OutputCsv = (".\M365-UserActivitySummary-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'AuditLog.Read.All' -NoWelcome

$since = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
$signins = Get-MgAuditLogSignIn -Filter "createdDateTime ge $since" -All

$report = $signins | Group-Object UserPrincipalName | ForEach-Object {
    $evts = $_.Group
    [pscustomobject]@{
        UserPrincipalName = $_.Name
        TotalSignIns      = $evts.Count
        FailedSignIns     = ($evts | Where-Object { $_.Status.ErrorCode -ne 0 }).Count
        DistinctApps      = ($evts.AppDisplayName | Sort-Object -Unique).Count
        DistinctIPs       = ($evts.IpAddress | Sort-Object -Unique).Count
        LastSignIn        = ($evts.CreatedDateTime | Measure-Object -Maximum).Maximum
    }
}
$report | Sort-Object FailedSignIns -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Riepilogo per {0} utenti (ultimi {1} giorni) → {2}. Ordina per FailedSignIns per i sospetti." -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
