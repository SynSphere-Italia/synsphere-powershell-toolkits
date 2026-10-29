#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Trova le licenze potenzialmente sprecate: utenti licenziati ma inattivi.
.DESCRIPTION
    Incrocia le licenze assegnate con l'ultimo accesso (signInActivity). Elenca gli
    utenti licenziati che non accedono da più di N giorni (o mai): candidati a
    recupero licenza. Sola lettura.

    NB: signInActivity richiede Microsoft Entra ID P1/P2 e il permesso AuditLog.Read.All.
.PARAMETER InactiveDays
    Soglia di inattività in giorni. Default: 90.
.PARAMETER OutputCsv
    Percorso CSV di output. Default: .\M365-UnusedLicenses-<data>.csv
.EXAMPLE
    .\09-Get-M365UnusedLicenses.ps1 -InactiveDays 60
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, AuditLog.Read.All, Organization.Read.All
#>
[CmdletBinding()]
param(
    [int]$InactiveDays = 90,
    [string]$OutputCsv = (".\M365-UnusedLicenses-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All', 'AuditLog.Read.All', 'Organization.Read.All' -NoWelcome

$skuMap = @{}; Get-MgSubscribedSku -All | ForEach-Object { $skuMap[$_.SkuId] = $_.SkuPartNumber }
$cutoff = (Get-Date).AddDays(-$InactiveDays)

$report = foreach ($user in Get-MgUser -All -Property DisplayName, UserPrincipalName, AccountEnabled, AssignedLicenses, SignInActivity) {
    if (-not $user.AssignedLicenses) { continue }                     # solo utenti licenziati
    $last = $user.SignInActivity.LastSignInDateTime
    $inattivo = (-not $last) -or ([datetime]$last -lt $cutoff)
    if ($inattivo) {
        [pscustomobject]@{
            DisplayName       = $user.DisplayName
            UserPrincipalName = $user.UserPrincipalName
            AccountEnabled    = $user.AccountEnabled
            LastSignIn        = if ($last) { ([datetime]$last).ToString('yyyy-MM-dd') } else { 'Mai' }
            Licenses          = ($user.AssignedLicenses | ForEach-Object { $skuMap[$_.SkuId] }) -join '; '
        }
    }
}

$report | Sort-Object LastSignIn | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} utenti licenziati inattivi da oltre {1} giorni → {2} (licenze potenzialmente recuperabili)" -f $report.Count, $InactiveDays, $OutputCsv) -ForegroundColor Yellow
