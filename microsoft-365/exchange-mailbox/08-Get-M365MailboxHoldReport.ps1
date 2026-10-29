#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report dei blocchi (hold) sulle caselle: litigation, in-place, retention.
.DESCRIPTION
    Elenca le caselle soggette a un qualsiasi tipo di hold (litigation hold, in-place
    hold, retention hold, compliance tag, delay hold). Utile per compliance/eDiscovery
    e prima di eliminare una casella. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-MailboxHolds-<data>.csv
.EXAMPLE
    .\08-Get-M365MailboxHoldReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-MailboxHolds-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$props = 'LitigationHoldEnabled', 'LitigationHoldDuration', 'InPlaceHolds', 'RetentionHoldEnabled', 'ComplianceTagHoldApplied', 'DelayHoldApplied'
$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited -Properties $props) {
    $hasHold = $mbx.LitigationHoldEnabled -or $mbx.RetentionHoldEnabled -or $mbx.ComplianceTagHoldApplied -or $mbx.DelayHoldApplied -or ($mbx.InPlaceHolds.Count -gt 0)
    if ($hasHold) {
        [pscustomobject]@{
            PrimarySmtpAddress  = $mbx.PrimarySmtpAddress
            LitigationHold      = $mbx.LitigationHoldEnabled
            LitigationDuration  = $mbx.LitigationHoldDuration
            RetentionHold       = $mbx.RetentionHoldEnabled
            ComplianceTagHold   = $mbx.ComplianceTagHoldApplied
            DelayHold           = $mbx.DelayHoldApplied
            InPlaceHolds        = ($mbx.InPlaceHolds -join '; ')
        }
    }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} caselle con hold attivi in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
