#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Elenca gli inviti guest in sospeso (non ancora accettati).
.DESCRIPTION
    I guest con stato PendingAcceptance hanno ricevuto un invito ma non l'hanno mai
    riscattato: spesso restano lì per sempre. Lo script li elenca per la pulizia.
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-PendingGuests-<data>.csv
.EXAMPLE
    .\04-Get-M365PendingGuestInvitations.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-PendingGuests-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All' -NoWelcome

$pending = Get-MgUser -Filter "userType eq 'Guest' and externalUserState eq 'PendingAcceptance'" -All `
    -Property DisplayName, Mail, CreatedDateTime, ExternalUserStateChangeDateTime
$report = foreach ($g in $pending) {
    [pscustomobject]@{
        Guest        = $g.DisplayName
        Email        = $g.Mail
        Invited      = if ($g.CreatedDateTime) { ([datetime]$g.CreatedDateTime).ToString('yyyy-MM-dd') } else { '' }
        LastStateChg = if ($g.ExternalUserStateChangeDateTime) { ([datetime]$g.ExternalUserStateChangeDateTime).ToString('yyyy-MM-dd') } else { '' }
    }
}
$report | Sort-Object Invited | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} inviti guest in sospeso (mai accettati) → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
