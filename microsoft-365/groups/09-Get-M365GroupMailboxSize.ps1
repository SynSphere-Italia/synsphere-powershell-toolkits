#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report dimensione della casella dei gruppi Microsoft 365.
.DESCRIPTION
    Ogni gruppo Microsoft 365 ha una casella condivisa (conversazioni). Lo script ne
    riporta la dimensione e il numero di elementi. Sola lettura.
    NB: lo storage del SITO SharePoint collegato è separato; per quello vedi il toolkit Teams/SharePoint.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-GroupMailboxSize-<data>.csv
.EXAMPLE
    .\09-Get-M365GroupMailboxSize.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-GroupMailboxSize-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($mbx in Get-EXOMailbox -RecipientTypeDetails GroupMailbox -ResultSize Unlimited) {
    $st = Get-EXOMailboxStatistics -Identity $mbx.PrimarySmtpAddress -Properties TotalItemSize, ItemCount -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Group              = $mbx.DisplayName
        PrimarySmtpAddress = $mbx.PrimarySmtpAddress
        MailboxSize        = $st.TotalItemSize
        ItemCount          = $st.ItemCount
    }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} caselle di gruppo M365 in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
