#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report del traffico email per utente: messaggi inviati e ricevuti.
.DESCRIPTION
    Aggrega il message trace per conteggiare i messaggi inviati e ricevuti da ciascun
    indirizzo nel periodo. Utile per capire i volumi e individuare anomalie. Sola lettura.
    NB: Get-MessageTrace copre al massimo gli ultimi 10 giorni; per finestre più lunghe
    usare il report storico nel portale o Get-MessageTraceV2.
.PARAMETER Days
    Finestra in giorni (max 10). Default: 7.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-MailTraffic-<data>.csv
.EXAMPLE
    .\01-Get-M365MailTrafficReport.ps1 -Days 10
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients / reporting).
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 10)][int]$Days = 7,
    [string]$OutputCsv = (".\M365-MailTraffic-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$msgs = Get-MessageTrace -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date) -PageSize 5000
$sent = @{}; $recv = @{}
foreach ($m in $msgs) {
    if ($m.SenderAddress)    { $sent[$m.SenderAddress.ToLower()]    = 1 + ($sent[$m.SenderAddress.ToLower()]) }
    if ($m.RecipientAddress) { $recv[$m.RecipientAddress.ToLower()] = 1 + ($recv[$m.RecipientAddress.ToLower()]) }
}
$users = ($sent.Keys + $recv.Keys) | Sort-Object -Unique
$report = foreach ($u in $users) {
    [pscustomobject]@{ User = $u; Sent = [int]$sent[$u]; Received = [int]$recv[$u]; Total = [int]$sent[$u] + [int]$recv[$u] }
}
$report | Sort-Object Total -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Traffico di {0} indirizzi su {1} giorni → {2} (campione max 5000 messaggi)" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
