#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Riepilogo sicurezza della posta: spam, malware, phishing, mail buona (per direzione).
.DESCRIPTION
    Usa Get-MailFlowStatusReport per riassumere i messaggi per tipo (GoodMail, Spam,
    Malware, Phish, EdgeBlockSpam) e direzione (Inbound/Outbound) nel periodo.
    Una crescita anomala di Outbound Spam/Malware indica account compromessi. Sola lettura.
.PARAMETER Days
    Finestra in giorni. Default: 7 (max ~90).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-MailFlowStatus-<data>.csv
.EXAMPLE
    .\02-Get-M365MailFlowStatusReport.ps1 -Days 30
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (reporting / Security Reader).
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\M365-MailFlowStatus-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$data = Get-MailFlowStatusReport -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date)
$report = $data | Group-Object Direction, EventType | ForEach-Object {
    $parts = $_.Name -split ', '
    [pscustomobject]@{
        Direction = $parts[0]
        EventType = $parts[1]                       # GoodMail / Spam / Malware / Phish / ...
        Count     = ($_.Group | Measure-Object MessageCount -Sum).Sum
    }
}
$report | Sort-Object Direction, Count -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$report | Format-Table -AutoSize
Write-Host ("Riepilogo mail flow ({0} giorni) → {1}. Controlla l'Outbound Spam/Malware (segnale di compromissione)." -f $Days, $OutputCsv) -ForegroundColor Green
