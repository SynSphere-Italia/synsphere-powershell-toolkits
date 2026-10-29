#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Audit degli accessi alle caselle da parte di NON proprietari (delegati/admin).
.DESCRIPTION
    Interroga l'Unified Audit Log per MailItemsAccessed e segnala gli accessi effettuati
    da un utente diverso dal proprietario della casella (LogonType delegato/admin). Utile
    per rilevare accessi non autorizzati o curiosità indebite. Sola lettura.
.PARAMETER Days
    Finestra in giorni. Default: 7 (max 90).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-NonOwnerAccess-<data>.csv
.EXAMPLE
    .\06-Get-M365NonOwnerMailboxAccess.ps1 -Days 14
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online + ruolo "View-Only Audit Logs". Richiede mailbox auditing attivo.
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\M365-NonOwnerAccess-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$events = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date) `
    -Operations 'MailItemsAccessed' -ResultSize 5000

$report = foreach ($e in $events) {
    $d = $e.AuditData | ConvertFrom-Json
    # LogonType: 0 = Owner, 1 = Admin, 2 = Delegate. Ci interessano i NON owner.
    if ($d.LogonType -ne 0 -and $d.UserId -ne $d.MailboxOwnerUPN) {
        [pscustomobject]@{
            Date      = $e.CreationDate
            Accessor  = $d.UserId
            Mailbox   = $d.MailboxOwnerUPN
            LogonType = switch ($d.LogonType) { 1 { 'Admin' } 2 { 'Delegate' } default { $d.LogonType } }
        }
    }
}
$report | Sort-Object Date -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} accessi non-owner alle caselle ({1} giorni) → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Yellow
