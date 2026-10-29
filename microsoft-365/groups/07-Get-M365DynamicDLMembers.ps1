#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report dei gruppi di distribuzione DINAMICI e dei membri risolti dal filtro.
.DESCRIPTION
    I membri di una DDL non sono statici: derivano da un filtro. Lo script valuta il
    filtro di ogni dynamic distribution group e mostra i destinatari che vi rientrano
    in questo momento. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-DynamicDL-<data>.csv
.EXAMPLE
    .\07-Get-M365DynamicDLMembers.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-DynamicDL-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($ddl in Get-DynamicDistributionGroup -ResultSize Unlimited) {
    $members = Get-Recipient -RecipientPreviewFilter $ddl.RecipientFilter -ResultSize Unlimited -ErrorAction SilentlyContinue
    foreach ($m in $members) {
        [pscustomobject]@{ DynamicDL = $ddl.DisplayName; GroupEmail = $ddl.PrimarySmtpAddress; Member = $m.DisplayName; MemberEmail = $m.PrimarySmtpAddress }
    }
}
$report | Sort-Object DynamicDL, Member | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} righe (DDL + membri risolti) in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
