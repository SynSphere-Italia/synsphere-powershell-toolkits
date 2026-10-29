#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Audit degli invii dalle SHARED MAILBOX: chi ha inviato a nome di una casella condivisa.
.DESCRIPTION
    Le shared mailbox (info@, vendite@) sono usate da più persone: questo audit mostra
    CHI ha realmente inviato dalla casella condivisa (SendAs / SendOnBehalf), per
    responsabilità e tracciabilità. Sola lettura.
.PARAMETER Days
    Finestra in giorni. Default: 7 (max 90).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-SharedMailboxSending-<data>.csv
.EXAMPLE
    .\05-Get-M365SharedMailboxSendingAudit.ps1 -Days 30
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online + ruolo "View-Only Audit Logs".
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\M365-SharedMailboxSending-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

# Insieme degli indirizzi shared mailbox (per filtrare gli invii)
$shared = (Get-EXOMailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited).PrimarySmtpAddress.ToLower()

$events = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date) `
    -Operations 'SendAs', 'SendOnBehalf' -ResultSize 5000

$report = foreach ($e in $events) {
    $d = $e.AuditData | ConvertFrom-Json
    $box = if ($d.SendAsUserSMTP) { $d.SendAsUserSMTP } else { $d.SendOnBehalfOfUserSmtp }
    if ($box -and ($shared -contains $box.ToLower())) {
        [pscustomobject]@{
            Date          = $e.CreationDate
            SharedMailbox = $box
            ActualSender  = $d.UserId
            Operation     = $d.Operation
            Subject       = $d.Item.Subject
        }
    }
}
$report | Sort-Object Date -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} invii da shared mailbox ({1} giorni) → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
