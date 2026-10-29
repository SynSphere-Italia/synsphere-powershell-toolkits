#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Trova gli ospiti "stantii": guest che non accedono da oltre N giorni (o mai).
.DESCRIPTION
    Gli account guest inattivi sono superficie d'attacco inutile e vanno ripuliti
    periodicamente. Lo script elenca i guest con ultimo accesso oltre la soglia.
    Sola lettura (per rimuoverli vedi 06-Remove-M365StaleGuests.ps1).
    NB: signInActivity richiede Microsoft Entra ID P1/P2 e AuditLog.Read.All.
.PARAMETER InactiveDays
    Soglia di inattività. Default: 90.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-StaleGuests-<data>.csv
.EXAMPLE
    .\03-Get-M365StaleGuestUsers.ps1 -InactiveDays 180
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, AuditLog.Read.All
#>
[CmdletBinding()]
param(
    [int]$InactiveDays = 90,
    [string]$OutputCsv = (".\M365-StaleGuests-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All', 'AuditLog.Read.All' -NoWelcome

$cutoff = (Get-Date).AddDays(-$InactiveDays)
$guests = Get-MgUser -Filter "userType eq 'Guest'" -All -Property DisplayName, Mail, CreatedDateTime, SignInActivity
$report = foreach ($g in $guests) {
    $last = $g.SignInActivity.LastSignInDateTime
    if ((-not $last) -or ([datetime]$last -lt $cutoff)) {
        [pscustomobject]@{
            Guest      = $g.DisplayName
            Email      = $g.Mail
            LastSignIn = if ($last) { ([datetime]$last).ToString('yyyy-MM-dd') } else { 'Mai' }
            Created    = if ($g.CreatedDateTime) { ([datetime]$g.CreatedDateTime).ToString('yyyy-MM-dd') } else { '' }
        }
    }
}
$report | Sort-Object LastSignIn | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} guest inattivi da oltre {1} giorni → {2}" -f $report.Count, $InactiveDays, $OutputCsv) -ForegroundColor Yellow
