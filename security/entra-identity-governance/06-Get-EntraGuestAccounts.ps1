#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Utenti guest del tenant con data di creazione e ultimo accesso.
.DESCRIPTION
    Elenca gli account guest (collaborazione esterna B2B) con email, data di creazione e
    ultimo accesso. Serve a rivedere periodicamente chi ha ancora accesso dall'esterno e a
    individuare guest inattivi da rimuovere. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-GuestAccounts-<data>.csv
.EXAMPLE
    .\06-Get-EntraGuestAccounts.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, AuditLog.Read.All
    La colonna "ultimo accesso" (signInActivity) richiede Microsoft Entra ID P1/P2:
    senza licenza lo script prosegue senza quel dato.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Entra-GuestAccounts-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'User.Read.All', 'AuditLog.Read.All' -NoWelcome

$hasSignIn = $true
try {
    $guests = Get-MgUser -All -Filter "userType eq 'Guest'" -Property 'Id', 'DisplayName', 'Mail', 'UserType', 'CreatedDateTime', 'SignInActivity'
}
catch {
    Write-Host "signInActivity non disponibile (richiede Entra ID P1) — proseguo senza l'ultimo accesso." -ForegroundColor Yellow
    $hasSignIn = $false
    $guests = Get-MgUser -All -Filter "userType eq 'Guest'" -Property 'Id', 'DisplayName', 'Mail', 'UserType', 'CreatedDateTime'
}

$report = foreach ($g in $guests) {
    [pscustomobject]@{
        DisplayName   = $g.DisplayName
        Mail          = $g.Mail
        Creato        = $g.CreatedDateTime
        UltimoAccesso = if ($hasSignIn) { $g.SignInActivity.LastSignInDateTime } else { 'n/d (Entra ID P1)' }
    }
}

$report | Sort-Object DisplayName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovati {0} account guest -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
