#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report dei connettori di posta in entrata e in uscita (inbound/outbound connector).
.DESCRIPTION
    I connettori instradano la posta da/verso sistemi esterni. Un connettore in uscita
    non autorizzato è una tecnica nota di Business Email Compromise (esfiltrazione/relay).
    Lo script elenca tutti i connettori con stato e destinazione. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-MailConnectors-<data>.csv
.EXAMPLE
    .\09-Get-M365MailConnectorsReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Configuration).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-MailConnectors-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = @()
$report += Get-InboundConnector | ForEach-Object {
    [pscustomobject]@{ Direction = 'Inbound'; Name = $_.Name; Enabled = $_.Enabled; Type = $_.ConnectorType; SenderDomains = ($_.SenderDomains -join '; '); SmartHosts = '' }
}
$report += Get-OutboundConnector | ForEach-Object {
    [pscustomobject]@{ Direction = 'Outbound'; Name = $_.Name; Enabled = $_.Enabled; Type = $_.ConnectorType; SenderDomains = ($_.RecipientDomains -join '; '); SmartHosts = ($_.SmartHosts -join '; ') }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} connettori → {1}. Verifica gli OUTBOUND non riconosciuti (rischio BEC)." -f $report.Count, $OutputCsv) -ForegroundColor Yellow
