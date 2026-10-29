#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report inoltro automatico a livello di casella (forwarding).
.DESCRIPTION
    Elenca le caselle con inoltro configurato (ForwardingAddress interno o
    ForwardingSmtpAddress esterno) e se viene mantenuta una copia. L'inoltro verso
    domini esterni è un classico segnale di compromissione/esfiltrazione. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-EmailForwarding-<data>.csv
.EXAMPLE
    .\06-Get-M365EmailForwardingReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-EmailForwarding-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited -Properties ForwardingAddress, ForwardingSmtpAddress, DeliverToMailboxAndForward) {
    if ($mbx.ForwardingAddress -or $mbx.ForwardingSmtpAddress) {
        [pscustomobject]@{
            PrimarySmtpAddress    = $mbx.PrimarySmtpAddress
            ForwardingAddress     = $mbx.ForwardingAddress       # destinatario interno
            ForwardingSmtpAddress = $mbx.ForwardingSmtpAddress    # SMTP (spesso esterno)
            KeepCopy              = $mbx.DeliverToMailboxAndForward
        }
    }
}
if ($report) {
    $report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host ("Trovate {0} caselle con inoltro configurato → {1}. Verifica i ForwardingSmtpAddress verso domini esterni." -f $report.Count, $OutputCsv) -ForegroundColor Yellow
} else {
    Write-Host "Nessuna casella con inoltro a livello di casella." -ForegroundColor Green
}
