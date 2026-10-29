#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report dei messaggi in quarantena (spam, phishing, malware) degli ultimi N giorni.
.DESCRIPTION
    Elenca i messaggi messi in quarantena da Exchange Online Protection / Defender,
    con mittente, destinatario, tipo e motivo. Utile per monitorare le minacce email
    e individuare falsi positivi. Sola lettura.
.PARAMETER Days
    Finestra in giorni. Default: 7 (max ~30, retention quarantena).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-Quarantine-<data>.csv
.EXAMPLE
    .\10-Get-M365QuarantineReport.ps1 -Days 14
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (Security Reader / Quarantine).
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\M365-Quarantine-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$page = 1; $all = @()
do {
    $batch = Get-QuarantineMessage -StartReceivedDate (Get-Date).AddDays(-$Days) -EndReceivedDate (Get-Date) -PageSize 1000 -Page $page
    $all += $batch; $page++
} while ($batch.Count -eq 1000)

$report = foreach ($m in $all) {
    [pscustomobject]@{
        Received  = $m.ReceivedTime
        Sender    = $m.SenderAddress
        Recipient = ($m.RecipientAddress -join '; ')
        Type      = $m.Type            # Spam / Phish / Malware / HighConfPhish / Bulk
        Subject   = $m.Subject
        Released  = $m.Released
    }
}
$report | Sort-Object Received -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} messaggi in quarantena ({1} giorni) → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
