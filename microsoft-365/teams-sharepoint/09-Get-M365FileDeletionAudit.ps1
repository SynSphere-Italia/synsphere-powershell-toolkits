#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Audit delle eliminazioni di file in SharePoint e OneDrive (chi e quando).
.DESCRIPTION
    Interroga l'Unified Audit Log per le operazioni di eliminazione file (FileDeleted,
    FileRecycled e cestino primo/secondo livello). Utile in caso di file spariti o
    cancellazioni sospette. Sola lettura.
.PARAMETER Days
    Finestra in giorni. Default: 7 (max 90).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-FileDeletionAudit-<data>.csv
.EXAMPLE
    .\09-Get-M365FileDeletionAudit.ps1 -Days 30
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online + ruolo "View-Only Audit Logs".
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\M365-FileDeletionAudit-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$events = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date) `
    -Operations 'FileDeleted', 'FileRecycled', 'FileDeletedFirstStageRecycleBin', 'FileDeletedSecondStageRecycleBin' -ResultSize 5000

$report = foreach ($e in $events) {
    $d = $e.AuditData | ConvertFrom-Json
    [pscustomobject]@{
        Date      = $e.CreationDate
        User      = $d.UserId
        Operation = $d.Operation
        File      = $d.SourceFileName
        SiteUrl   = $d.SiteUrl
    }
}
$report | Sort-Object Date -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} eventi di eliminazione file ({1} giorni) → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
