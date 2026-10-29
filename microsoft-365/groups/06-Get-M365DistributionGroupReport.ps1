#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report delle liste di distribuzione (distribution group) e dei loro membri.
.DESCRIPTION
    Elenca le distribution list con una riga per ogni membro (nome, email, tipo).
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-DistributionGroups-<data>.csv
.EXAMPLE
    .\06-Get-M365DistributionGroupReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-DistributionGroups-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($dl in Get-DistributionGroup -ResultSize Unlimited) {
    $members = Get-DistributionGroupMember -Identity $dl.Identity -ResultSize Unlimited -ErrorAction SilentlyContinue
    if (-not $members) {
        [pscustomobject]@{ DistributionGroup = $dl.DisplayName; GroupEmail = $dl.PrimarySmtpAddress; Member = '(vuoto)'; MemberEmail = ''; MemberType = '' }
        continue
    }
    foreach ($m in $members) {
        [pscustomobject]@{ DistributionGroup = $dl.DisplayName; GroupEmail = $dl.PrimarySmtpAddress; Member = $m.DisplayName; MemberEmail = $m.PrimarySmtpAddress; MemberType = $m.RecipientType }
    }
}
$report | Sort-Object DistributionGroup, Member | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} righe (DL + membri) in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
