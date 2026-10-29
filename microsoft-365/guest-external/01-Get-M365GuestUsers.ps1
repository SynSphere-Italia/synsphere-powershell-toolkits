#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report di tutti gli utenti guest (ospiti esterni) del tenant Microsoft 365.
.DESCRIPTION
    Esporta gli account con userType = Guest: email, dominio di provenienza, data di
    creazione e stato dell'invito. Punto di partenza per qualsiasi audit della
    collaborazione esterna. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-GuestUsers-<data>.csv
.EXAMPLE
    .\01-Get-M365GuestUsers.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-GuestUsers-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All' -NoWelcome

$guests = Get-MgUser -Filter "userType eq 'Guest'" -All -Property DisplayName, UserPrincipalName, Mail, CreatedDateTime, ExternalUserState, ExternalUserStateChangeDateTime, CompanyName, AccountEnabled
$report = foreach ($g in $guests) {
    [pscustomobject]@{
        DisplayName    = $g.DisplayName
        Email          = $g.Mail
        Domain         = if ($g.Mail) { ($g.Mail -split '@')[-1] } else { '' }
        Company        = $g.CompanyName
        InviteState    = $g.ExternalUserState           # Accepted / PendingAcceptance
        Created        = if ($g.CreatedDateTime) { ([datetime]$g.CreatedDateTime).ToString('yyyy-MM-dd') } else { '' }
        AccountEnabled = $g.AccountEnabled
    }
}
$report | Sort-Object Domain, DisplayName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} utenti guest in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
