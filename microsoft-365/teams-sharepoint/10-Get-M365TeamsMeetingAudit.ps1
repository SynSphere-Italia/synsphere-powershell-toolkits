#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Audit delle riunioni Microsoft Teams: partecipanti per riunione.
.DESCRIPTION
    Estrae dall'Unified Audit Log i dettagli di partecipazione alle riunioni Teams
    (MeetingParticipantDetail): chi ha partecipato a quale riunione e quando. Utile per
    tracciabilità e compliance. Sola lettura.
.PARAMETER Days
    Finestra in giorni. Default: 7 (max 90).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-TeamsMeetingAudit-<data>.csv
.EXAMPLE
    .\10-Get-M365TeamsMeetingAudit.ps1 -Days 14
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online + ruolo "View-Only Audit Logs".
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\M365-TeamsMeetingAudit-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$events = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date) `
    -RecordType 'MicrosoftTeams' -Operations 'MeetingParticipantDetail' -ResultSize 5000

$report = foreach ($e in $events) {
    $d = $e.AuditData | ConvertFrom-Json
    foreach ($att in $d.Attendees) {
        [pscustomobject]@{
            MeetingId   = $d.MeetingDetailId
            Participant = $att.UPN
            Role        = $att.Role
            JoinTime    = $d.JoinTime
            LeaveTime   = $d.LeaveTime
        }
    }
}
$report | Sort-Object MeetingId | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} righe di partecipazione riunioni Teams ({1} giorni) → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
