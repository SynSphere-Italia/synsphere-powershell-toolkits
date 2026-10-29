#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report dimensione degli archivi online (In-Place Archive) delle caselle.
.DESCRIPTION
    Elenca le caselle con archivio attivo e la dimensione dell'archivio. Utile per
    gestire la crescita degli archivi e l'auto-expanding archive. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-ArchiveSize-<data>.csv
.EXAMPLE
    .\05-Get-M365ArchiveMailboxSizeReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-ArchiveSize-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited -Properties ArchiveStatus | Where-Object { $_.ArchiveStatus -eq 'Active' }) {
    $st = Get-EXOMailboxStatistics -Identity $mbx.PrimarySmtpAddress -Archive -Properties TotalItemSize, ItemCount -ErrorAction SilentlyContinue
    [pscustomobject]@{
        DisplayName        = $mbx.DisplayName
        PrimarySmtpAddress = $mbx.PrimarySmtpAddress
        ArchiveSize        = $st.TotalItemSize
        ArchiveItemCount   = $st.ItemCount
    }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} caselle con archivio attivo in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
