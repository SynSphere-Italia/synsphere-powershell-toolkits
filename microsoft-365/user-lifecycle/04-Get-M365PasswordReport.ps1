#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report password Microsoft 365: ultima modifica, età e policy di scadenza.
.DESCRIPTION
    Per ogni utente esporta la data dell'ultima modifica password, l'età in giorni e
    se la password è impostata per non scadere mai (DisablePasswordExpiration).
    Utile per audit di sicurezza e igiene delle credenziali. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-PasswordReport-<data>.csv
.EXAMPLE
    .\04-Get-M365PasswordReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-PasswordReport-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All' -NoWelcome

$now = Get-Date
$report = foreach ($u in Get-MgUser -All -Property DisplayName, UserPrincipalName, AccountEnabled, LastPasswordChangeDateTime, PasswordPolicies) {
    $chg = $u.LastPasswordChangeDateTime
    [pscustomobject]@{
        DisplayName          = $u.DisplayName
        UserPrincipalName    = $u.UserPrincipalName
        AccountEnabled       = $u.AccountEnabled
        LastPasswordChange   = if ($chg) { ([datetime]$chg).ToString('yyyy-MM-dd') } else { 'N/D' }
        PasswordAgeDays      = if ($chg) { [int]($now - [datetime]$chg).TotalDays } else { 'N/D' }
        PasswordNeverExpires = ($u.PasswordPolicies -match 'DisablePasswordExpiration') -as [bool]
    }
}
$report | Sort-Object { if ($_.PasswordAgeDays -eq 'N/D') { -1 } else { [int]$_.PasswordAgeDays } } -Descending |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} utenti in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
