#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Cassette "a rischio": nessun hold e Single Item Recovery disattivato.
.DESCRIPTION
    Individua le cassette utente che NON hanno alcun blocco (Litigation/In-Place Hold) E hanno
    Single Item Recovery disattivato: sono quelle con la minore capacità di recupero dei dati.
    È la lista di priorità per rafforzare la continuità (abilitare SIR e/o un hold). Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-MailboxesAtRisk-<data>.csv
.EXAMPLE
    .\03-Get-MailboxesAtRisk.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement (Connect-ExchangeOnline). Nessuno scope Graph.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-MailboxesAtRisk-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-ConnectionInformation | Where-Object { $_.ConnectionUri -like '*outlook.office365.com*' })) {
    Connect-ExchangeOnline -ShowBanner:$false
}

$mbxs = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox -PropertySets Hold -Properties SingleItemRecoveryEnabled
$report = foreach ($m in $mbxs) {
    $hasHold = $m.LitigationHoldEnabled -or (@($m.InPlaceHolds).Count -gt 0)
    if (-not $hasHold -and -not $m.SingleItemRecoveryEnabled) {
        [pscustomobject]@{
            Mailbox            = $m.DisplayName
            Email              = $m.PrimarySmtpAddress
            LitigationHold     = $m.LitigationHoldEnabled
            SingleItemRecovery = $m.SingleItemRecoveryEnabled
            InPlaceHolds       = (@($m.InPlaceHolds) -join '; ')
        }
    }
}

$report | Sort-Object Mailbox | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovate {0} cassette a rischio (nessun hold + SIR off) -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
