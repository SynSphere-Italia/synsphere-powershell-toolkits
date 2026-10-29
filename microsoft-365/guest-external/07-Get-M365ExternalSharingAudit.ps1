#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Audit della condivisione esterna in SharePoint/OneDrive (ultimi N giorni).
.DESCRIPTION
    Interroga l'Unified Audit Log per gli eventi di condivisione verso utenti esterni
    (inviti di sharing, secure link). Mostra chi ha condiviso cosa e con chi. Sola lettura.
    NB: richiede che l'audit (Purview) sia attivo e il ruolo "View-Only Audit Logs".
.PARAMETER Days
    Finestra in giorni. Default: 7 (max 90, in base alla retention del piano).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-ExternalSharingAudit-<data>.csv
.EXAMPLE
    .\07-Get-M365ExternalSharingAudit.ps1 -Days 30
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online + ruolo audit. -ResultSize 5000: per volumi maggiori usare la paginazione.
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\M365-ExternalSharingAudit-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$events = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date) `
    -Operations 'SharingInvitationCreated', 'SharingSet', 'AddedToSecureLink', 'SecureLinkCreated' -ResultSize 5000

$report = foreach ($e in $events) {
    $d = $e.AuditData | ConvertFrom-Json
    [pscustomobject]@{
        Date       = $e.CreationDate
        SharedBy   = $d.UserId
        Operation  = $d.Operation
        SharedWith = $d.TargetUserOrGroupName
        TargetType = $d.TargetUserOrGroupType        # Guest / SecureLink / ...
        Resource   = $d.ObjectId
        SiteUrl    = $d.SiteUrl
    }
}
$report | Sort-Object Date -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} eventi di condivisione esterna (ultimi {1} giorni) → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
