#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Cassette inattive (dati di ex-dipendenti conservati da un hold).
.DESCRIPTION
    Elenca le cassette inactive: cassette di utenti eliminati che restano conservate perché
    coperte da un Litigation Hold o da una retention policy al momento della cancellazione.
    Sono la memoria di lungo periodo dell'organizzazione (ex-dipendenti, obblighi legali).
    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-InactiveMailboxes-<data>.csv
.EXAMPLE
    .\05-Get-InactiveMailboxes.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement (Connect-ExchangeOnline). Nessuno scope Graph.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-InactiveMailboxes-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-ConnectionInformation | Where-Object { $_.ConnectionUri -like '*outlook.office365.com*' })) {
    Connect-ExchangeOnline -ShowBanner:$false
}

$report = foreach ($mbx in Get-EXOMailbox -InactiveMailboxOnly -ResultSize Unlimited -Properties WhenSoftDeleted, LitigationHoldEnabled, InPlaceHolds) {
    [pscustomobject]@{
        Mailbox        = $mbx.DisplayName
        Email          = $mbx.PrimarySmtpAddress
        Inattiva_dal   = $mbx.WhenSoftDeleted
        LitigationHold = $mbx.LitigationHoldEnabled
        InPlaceHolds   = (@($mbx.InPlaceHolds) -join '; ')
    }
}

$report | Sort-Object Mailbox | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovate {0} cassette inattive (conservate da hold) -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
