#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Ultimo accesso "reale": considera sia gli accessi interattivi sia quelli non interattivi.
.DESCRIPTION
    Alcuni account (es. service/condivisi) hanno solo accessi NON interattivi: usando
    solo LastSignInDateTime sembrerebbero inattivi. Questo script calcola la data più
    recente fra interattivo e non interattivo, per una valutazione di inattività più
    accurata. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-RealLastLogon-<data>.csv
.EXAMPLE
    .\03-Get-M365RealLastLogonReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, AuditLog.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-RealLastLogon-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All', 'AuditLog.Read.All' -NoWelcome

$now = Get-Date
$report = foreach ($u in Get-MgUser -All -Property DisplayName, UserPrincipalName, AccountEnabled, SignInActivity) {
    $i = $u.SignInActivity.LastSignInDateTime
    $n = $u.SignInActivity.LastNonInteractiveSignInDateTime
    $dates = @($i, $n) | Where-Object { $_ } | ForEach-Object { [datetime]$_ }
    $real = if ($dates) { ($dates | Measure-Object -Maximum).Maximum } else { $null }
    [pscustomobject]@{
        DisplayName        = $u.DisplayName
        UserPrincipalName  = $u.UserPrincipalName
        AccountEnabled     = $u.AccountEnabled
        LastInteractive    = if ($i) { ([datetime]$i).ToString('yyyy-MM-dd') } else { 'Mai' }
        LastNonInteractive = if ($n) { ([datetime]$n).ToString('yyyy-MM-dd') } else { 'Mai' }
        RealLastSignIn     = if ($real) { $real.ToString('yyyy-MM-dd') } else { 'Mai' }
        InactiveDays       = if ($real) { [int]($now - $real).TotalDays } else { 'N/D' }
    }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} utenti in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
