#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Cassette con blocchi (hold) attivi: litigation, in-place e retention hold.
.DESCRIPTION
    Elenca le cassette (utente e condivise) e il loro stato di conservazione: Litigation Hold,
    Retention Hold e In-Place Holds (retention policy / eDiscovery). Gli hold sono cio che, in
    Microsoft 365, conserva i dati oltre la cancellazione: sapere quali cassette sono protette
    e quali no e il primo passo della continuita. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-MailboxHoldStatus-<data>.csv
.EXAMPLE
    .\01-Get-MailboxHoldStatus.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement (Connect-ExchangeOnline). Nessuno scope Graph.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-MailboxHoldStatus-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-ConnectionInformation | Where-Object { $_.ConnectionUri -like '*outlook.office365.com*' })) {
    Connect-ExchangeOnline -ShowBanner:$false
}

$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox -PropertySets Hold, Retention) {
    [pscustomobject]@{
        Mailbox           = $mbx.DisplayName
        Email             = $mbx.PrimarySmtpAddress
        LitigationHold    = $mbx.LitigationHoldEnabled
        LitigationDurata  = $mbx.LitigationHoldDuration
        RetentionHold     = $mbx.RetentionHoldEnabled
        ComplianceTagHold = $mbx.ComplianceTagHoldApplied
        InPlaceHolds      = (@($mbx.InPlaceHolds) -join '; ')
    }
}

$report | Sort-Object Mailbox | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Analizzate {0} cassette (stato hold) -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
