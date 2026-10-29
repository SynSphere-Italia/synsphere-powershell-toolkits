#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Audit delle email inviate con permesso "Send As" (invio a nome di un altro).
.DESCRIPTION
    Interroga l'Unified Audit Log per le operazioni SendAs: chi ha inviato a nome di chi.
    Utile per verificare l'uso (lecito o meno) delle deleghe Send As. Sola lettura.
.PARAMETER Days
    Finestra in giorni. Default: 7 (max 90).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-SendAsAudit-<data>.csv
.EXAMPLE
    .\04-Get-M365SendAsAudit.ps1 -Days 30
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online + ruolo "View-Only Audit Logs". Richiede mailbox auditing attivo.
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\M365-SendAsAudit-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$events = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date) `
    -Operations 'SendAs' -ResultSize 5000

$report = foreach ($e in $events) {
    $d = $e.AuditData | ConvertFrom-Json
    [pscustomobject]@{
        Date       = $e.CreationDate
        SentBy     = $d.UserId
        SentAs     = $d.SendAsUserSMTP
        Subject    = $d.Item.Subject
    }
}
$report | Sort-Object Date -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} invii Send As ({1} giorni) → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
