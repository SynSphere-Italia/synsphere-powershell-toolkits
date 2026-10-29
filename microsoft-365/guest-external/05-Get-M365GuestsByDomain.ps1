#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Raggruppa gli ospiti per dominio di provenienza.
.DESCRIPTION
    Mostra da quali domini esterni provengono i guest e quanti per ciascuno: utile per
    capire con quali aziende/partner collabori e per individuare domini sospetti o non
    più rilevanti. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-GuestsByDomain-<data>.csv
.EXAMPLE
    .\05-Get-M365GuestsByDomain.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-GuestsByDomain-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All' -NoWelcome

$guests = Get-MgUser -Filter "userType eq 'Guest'" -All -Property DisplayName, Mail
$report = $guests | Group-Object { if ($_.Mail) { ($_.Mail -split '@')[-1].ToLower() } else { '(sconosciuto)' } } | ForEach-Object {
    [pscustomobject]@{
        Domain     = $_.Name
        GuestCount = $_.Count
        Guests     = ($_.Group.DisplayName -join '; ')
    }
}
$report | Sort-Object GuestCount -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} domini esterni in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
