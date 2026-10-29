#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report dimensione delle caselle Exchange Online.
.DESCRIPTION
    Per ogni casella esporta dimensione totale, numero di elementi e quota.
    Utile per capacity planning e per individuare le caselle vicine al limite. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-MailboxSize-<data>.csv
.EXAMPLE
    .\04-Get-M365MailboxSizeReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-MailboxSize-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited -Properties ProhibitSendReceiveQuota) {
    $st = Get-EXOMailboxStatistics -Identity $mbx.PrimarySmtpAddress -Properties TotalItemSize, ItemCount
    [pscustomobject]@{
        DisplayName       = $mbx.DisplayName
        PrimarySmtpAddress = $mbx.PrimarySmtpAddress
        Type              = $mbx.RecipientTypeDetails
        TotalSize         = $st.TotalItemSize
        ItemCount         = $st.ItemCount
        Quota             = $mbx.ProhibitSendReceiveQuota
    }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} caselle in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
