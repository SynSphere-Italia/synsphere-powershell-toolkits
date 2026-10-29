#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report delle regole di flusso della posta (transport rules / mail flow rules).
.DESCRIPTION
    Esporta le regole di trasporto del tenant con stato, priorità e descrizione. Le
    transport rules sono potenti e a volte usate in modo malevolo (redirect/BCC nascosti,
    bypass del filtro): vanno riviste periodicamente. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-TransportRules-<data>.csv
.EXAMPLE
    .\08-Get-M365TransportRulesReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Configuration).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-TransportRules-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($r in Get-TransportRule) {
    [pscustomobject]@{
        Name        = $r.Name
        State       = $r.State          # Enabled / Disabled
        Priority    = $r.Priority
        Mode        = $r.Mode           # Enforce / Audit
        Description = ($r.Description -replace "`r?`n", ' ')
    }
}
$report | Sort-Object Priority | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} transport rule → {1}. Rivedi quelle con redirect/BCC verso esterni." -f $report.Count, $OutputCsv) -ForegroundColor Green
