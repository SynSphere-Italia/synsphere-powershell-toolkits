#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users
<#
.SYNOPSIS
    Disabilita o elimina gli utenti guest inattivi da oltre N giorni.
.DESCRIPTION
    Pulizia della collaborazione esterna: individua i guest stantii e, su richiesta, li
    DISABILITA o li ELIMINA. Default = solo report. Supporta -WhatIf.
.PARAMETER InactiveDays
    Soglia di inattività. Default: 90.
.PARAMETER Action
    Report (default) | Disable | Delete.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-StaleGuestsCleanup-<data>.csv
.EXAMPLE
    .\06-Remove-M365StaleGuests.ps1 -InactiveDays 180 -Action Disable -WhatIf
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Testare con -WhatIf.
    Permessi Graph: User.ReadWrite.All, AuditLog.Read.All
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$InactiveDays = 90,
    [ValidateSet('Report', 'Disable', 'Delete')][string]$Action = 'Report',
    [string]$OutputCsv = (".\M365-StaleGuestsCleanup-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.ReadWrite.All', 'AuditLog.Read.All' -NoWelcome

$cutoff = (Get-Date).AddDays(-$InactiveDays)
$guests = Get-MgUser -Filter "userType eq 'Guest'" -All -Property DisplayName, Mail, Id, SignInActivity
$report = foreach ($g in $guests) {
    $last = $g.SignInActivity.LastSignInDateTime
    if ((-not $last) -or ([datetime]$last -lt $cutoff)) {
        $done = 'Report'
        if ($Action -eq 'Disable' -and $PSCmdlet.ShouldProcess($g.Mail, 'Disabilita guest')) {
            Update-MgUser -UserId $g.Id -AccountEnabled:$false; $done = 'Disabled'
        } elseif ($Action -eq 'Delete' -and $PSCmdlet.ShouldProcess($g.Mail, 'ELIMINA guest')) {
            Remove-MgUser -UserId $g.Id; $done = 'Deleted'
        }
        [pscustomobject]@{ Guest = $g.DisplayName; Email = $g.Mail; LastSignIn = if ($last) { ([datetime]$last).ToString('yyyy-MM-dd') } else { 'Mai' }; ActionTaken = $done }
    }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} guest inattivi (azione: {1}) → {2}" -f $report.Count, $Action, $OutputCsv) -ForegroundColor Yellow
if ($Action -eq 'Report') { Write-Host "Solo report. Rilancia con -Action Disable (e -WhatIf) per agire." -ForegroundColor Yellow }
