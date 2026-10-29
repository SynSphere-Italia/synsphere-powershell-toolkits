#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Stato dell'archivio online delle cassette (In-Place Archive).
.DESCRIPTION
    Per ogni cassetta riporta se l'archivio online è attivo, se è abilitato l'archivio a
    espansione automatica e il nome dell'archivio. L'archivio online sposta la posta storica
    fuori dalla cassetta primaria mantenendola ricercabile e conservata: è parte della
    strategia di conservazione dei dati. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-ArchiveMailboxStatus-<data>.csv
.EXAMPLE
    .\09-Get-ArchiveMailboxStatus.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement (Connect-ExchangeOnline). Nessuno scope Graph.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-ArchiveMailboxStatus-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-ConnectionInformation | Where-Object { $_.ConnectionUri -like '*outlook.office365.com*' })) {
    Connect-ExchangeOnline -ShowBanner:$false
}

$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox -Properties ArchiveStatus, ArchiveState, AutoExpandingArchiveEnabled, ArchiveName) {
    [pscustomobject]@{
        Mailbox               = $mbx.DisplayName
        Email                 = $mbx.PrimarySmtpAddress
        ArchivioStato         = $mbx.ArchiveState        # None / Local / HostedProvisioned / ...
        ArchivioAttivo        = $mbx.ArchiveStatus       # Active / None
        AutoEspansione        = $mbx.AutoExpandingArchiveEnabled
        NomeArchivio          = $mbx.ArchiveName
    }
}

$report | Sort-Object Mailbox | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Analizzate {0} cassette (stato archivio) -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
