#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Audit degli accessi a file da parte di utenti ESTERNI (guest) in SharePoint/OneDrive.
.DESCRIPTION
    Interroga l'Unified Audit Log per gli eventi FileAccessed/FileDownloaded compiuti da
    identità esterne (UPN contenente #EXT#). Utile per verificare cosa stanno effettivamente
    consultando gli ospiti. Sola lettura.
.PARAMETER Days
    Finestra in giorni. Default: 7 (max 90).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-ExternalFileAccess-<data>.csv
.EXAMPLE
    .\08-Get-M365ExternalFileAccessAudit.ps1 -Days 14
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online + ruolo audit.
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\M365-ExternalFileAccess-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$events = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date) `
    -Operations 'FileAccessed', 'FileDownloaded' -ResultSize 5000

$report = foreach ($e in $events) {
    $d = $e.AuditData | ConvertFrom-Json
    if ($d.UserId -notmatch '#EXT#|urn:spo:guest') { continue }   # solo attori esterni/guest
    [pscustomobject]@{
        Date      = $e.CreationDate
        ExternalUser = $d.UserId
        Operation = $d.Operation
        File      = $d.SourceFileName
        SiteUrl   = $d.SiteUrl
    }
}
$report | Sort-Object Date -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} accessi a file da utenti esterni (ultimi {1} giorni) → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
