#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Cassette soft-deleted recuperabili in Exchange Online.
.DESCRIPTION
    Elenca le cassette eliminate ma ancora recuperabili (soft-deleted), con la data di
    eliminazione. Di norma restano ripristinabili per 30 giorni: questo report ti dice cosa
    puoi ancora recuperare e quanto tempo resta. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-SoftDeletedMailboxes-<data>.csv
.EXAMPLE
    .\04-Get-SoftDeletedMailboxes.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement (Connect-ExchangeOnline). Nessuno scope Graph.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-SoftDeletedMailboxes-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-ConnectionInformation | Where-Object { $_.ConnectionUri -like '*outlook.office365.com*' })) {
    Connect-ExchangeOnline -ShowBanner:$false
}

$report = foreach ($mbx in Get-EXOMailbox -SoftDeletedMailbox -ResultSize Unlimited -Properties WhenSoftDeleted) {
    $giorni = if ($mbx.WhenSoftDeleted) { [int](30 - ((Get-Date) - $mbx.WhenSoftDeleted).TotalDays) } else { $null }
    [pscustomobject]@{
        Mailbox        = $mbx.DisplayName
        Email          = $mbx.PrimarySmtpAddress
        Eliminata      = $mbx.WhenSoftDeleted
        GiorniResidui  = $giorni    # stima sulla finestra standard di 30 giorni
    }
}

$report | Sort-Object Eliminata | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovate {0} cassette soft-deleted recuperabili -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
