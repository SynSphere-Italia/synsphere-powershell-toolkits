#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Elenca tutte le liste di distribuzione di cui fa parte un determinato utente.
.DESCRIPTION
    Lookup inverso sulle distribution list: dato un utente, trova le DL che lo
    contengono. Utile prima di un offboarding (le DL non si vedono nel pannello utente).
    Sola lettura.
.PARAMETER UserPrincipalName
    UPN dell'utente (obbligatorio).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-UserDLs-<data>.csv
.EXAMPLE
    .\08-Get-M365UserDistributionGroups.ps1 -UserPrincipalName mario.rossi@azienda.it
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online. Scansiona tutte le DL: su tenant grandi è lento.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$UserPrincipalName,
    [string]$OutputCsv = (".\M365-UserDLs-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($dl in Get-DistributionGroup -ResultSize Unlimited) {
    $members = Get-DistributionGroupMember -Identity $dl.Identity -ResultSize Unlimited -ErrorAction SilentlyContinue
    if ($members.PrimarySmtpAddress -contains $UserPrincipalName) {
        [pscustomobject]@{ DistributionGroup = $dl.DisplayName; GroupEmail = $dl.PrimarySmtpAddress }
    }
}
$report | Sort-Object DistributionGroup | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} è in {1} liste di distribuzione → {2}" -f $UserPrincipalName, $report.Count, $OutputCsv) -ForegroundColor Green
