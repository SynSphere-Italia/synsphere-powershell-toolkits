#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report ultimo accesso (last logon) degli utenti Microsoft 365.
.DESCRIPTION
    Esporta in CSV ogni utente con la data dell'ultimo accesso interattivo e i giorni
    di inattività. Utile per individuare account dormienti. Sola lettura.
    NB: signInActivity richiede Microsoft Entra ID P1/P2 e il permesso AuditLog.Read.All.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-LastLogon-<data>.csv
.EXAMPLE
    .\01-Get-M365LastLogonReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, AuditLog.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-LastLogon-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All', 'AuditLog.Read.All' -NoWelcome

$now = Get-Date
$report = foreach ($u in Get-MgUser -All -Property DisplayName, UserPrincipalName, AccountEnabled, SignInActivity) {
    $last = $u.SignInActivity.LastSignInDateTime
    [pscustomobject]@{
        DisplayName       = $u.DisplayName
        UserPrincipalName = $u.UserPrincipalName
        AccountEnabled    = $u.AccountEnabled
        LastSignIn        = if ($last) { ([datetime]$last).ToString('yyyy-MM-dd') } else { 'Mai' }
        InactiveDays      = if ($last) { [int]($now - [datetime]$last).TotalDays } else { 'N/D' }
    }
}
$report | Sort-Object { if ($_.InactiveDays -eq 'N/D') { [int]::MaxValue } else { [int]$_.InactiveDays } } -Descending |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} utenti in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
