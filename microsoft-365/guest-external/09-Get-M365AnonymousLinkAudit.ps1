#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Audit dei link di condivisione ANONIMI ("chiunque abbia il link") in SharePoint/OneDrive.
.DESCRIPTION
    I link anonimi espongono i file a chiunque, senza autenticazione: sono il rischio di
    sharing più alto. Lo script estrae dall'Unified Audit Log la creazione e l'uso dei link
    anonimi negli ultimi N giorni. Sola lettura.
.PARAMETER Days
    Finestra in giorni. Default: 7 (max 90).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-AnonymousLinks-<data>.csv
.EXAMPLE
    .\09-Get-M365AnonymousLinkAudit.ps1 -Days 30
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online + ruolo audit.
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\M365-AnonymousLinks-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$events = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date) `
    -Operations 'AnonymousLinkCreated', 'AnonymousLinkUsed', 'AnonymousLinkUpdated' -ResultSize 5000

$report = foreach ($e in $events) {
    $d = $e.AuditData | ConvertFrom-Json
    [pscustomobject]@{
        Date      = $e.CreationDate
        Operation = $d.Operation
        User      = $d.UserId
        File      = $d.SourceFileName
        SiteUrl   = $d.SiteUrl
    }
}
$report | Sort-Object Date -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
if ($report.Count -gt 0) {
    Write-Host ("ATTENZIONE: {0} eventi di link anonimi (ultimi {1} giorni) → {2}. Valuta di disabilitare i link anonimi a livello di tenant." -f $report.Count, $Days, $OutputCsv) -ForegroundColor Red
} else {
    Write-Host "Nessun link anonimo nel periodo: buona postura di condivisione." -ForegroundColor Green
}
