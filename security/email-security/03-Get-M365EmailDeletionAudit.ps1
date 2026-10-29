#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Audit delle eliminazioni di email: chi ha cancellato cosa e quando.
.DESCRIPTION
    Interroga l'Unified Audit Log per le operazioni di eliminazione (SoftDelete,
    HardDelete, MoveToDeletedItems). Utile in caso di contestazioni o sospetta
    cancellazione dolosa. Sola lettura. Richiede mailbox auditing attivo.
.PARAMETER Days
    Finestra in giorni. Default: 7 (max 90).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-EmailDeletionAudit-<data>.csv
.EXAMPLE
    .\03-Get-M365EmailDeletionAudit.ps1 -Days 30
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online + ruolo "View-Only Audit Logs".
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\M365-EmailDeletionAudit-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$events = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date) `
    -Operations 'SoftDelete', 'HardDelete', 'MoveToDeletedItems' -ResultSize 5000

$report = foreach ($e in $events) {
    $d = $e.AuditData | ConvertFrom-Json
    [pscustomobject]@{
        Date      = $e.CreationDate
        Actor     = $d.UserId
        Mailbox   = $d.MailboxOwnerUPN
        Operation = $d.Operation
        Items     = ($d.AffectedItems.Subject -join ' | ')
    }
}
$report | Sort-Object Date -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} eventi di eliminazione email ({1} giorni) → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
