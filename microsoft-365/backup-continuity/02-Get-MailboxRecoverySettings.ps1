#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Impostazioni di recuperabilità delle cassette (finestra elementi eliminati + single-item recovery).
.DESCRIPTION
    Per ogni cassetta riporta la finestra di conservazione degli elementi eliminati
    (RetainDeletedItemsFor), lo stato di Single Item Recovery (recupero anche degli elementi
    "purgati" entro la finestra) e gli hold. Sono i parametri che determinano CHE COSA e per
    QUANTO puoi recuperare in Exchange Online. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-MailboxRecoverySettings-<data>.csv
.EXAMPLE
    .\02-Get-MailboxRecoverySettings.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement (Connect-ExchangeOnline). Nessuno scope Graph.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-MailboxRecoverySettings-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-ConnectionInformation | Where-Object { $_.ConnectionUri -like '*outlook.office365.com*' })) {
    Connect-ExchangeOnline -ShowBanner:$false
}

$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox -Properties RetainDeletedItemsFor, SingleItemRecoveryEnabled, RetentionHoldEnabled, LitigationHoldEnabled) {
    [pscustomobject]@{
        Mailbox              = $mbx.DisplayName
        Email                = $mbx.PrimarySmtpAddress
        RetainDeletedItemsFor = $mbx.RetainDeletedItemsFor
        SingleItemRecovery   = $mbx.SingleItemRecoveryEnabled
        RetentionHold        = $mbx.RetentionHoldEnabled
        LitigationHold       = $mbx.LitigationHoldEnabled
    }
}

$report | Sort-Object Mailbox | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Analizzate {0} cassette (impostazioni di recupero) -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
