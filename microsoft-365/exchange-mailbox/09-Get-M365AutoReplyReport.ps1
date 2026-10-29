#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report risposte automatiche (out-of-office) attive o programmate.
.DESCRIPTION
    Elenca le caselle con risposta automatica abilitata o pianificata, con date di
    inizio/fine. Utile per individuare OOF dimenticati o caselle di ex dipendenti.
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-AutoReply-<data>.csv
.EXAMPLE
    .\09-Get-M365AutoReplyReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-AutoReply-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited) {
    $cfg = Get-MailboxAutoReplyConfiguration -Identity $mbx.PrimarySmtpAddress
    if ($cfg.AutoReplyState -ne 'Disabled') {
        [pscustomobject]@{
            PrimarySmtpAddress = $mbx.PrimarySmtpAddress
            AutoReplyState     = $cfg.AutoReplyState     # Enabled / Scheduled
            StartTime          = $cfg.StartTime
            EndTime            = $cfg.EndTime
        }
    }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} caselle con risposta automatica attiva/programmata in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
