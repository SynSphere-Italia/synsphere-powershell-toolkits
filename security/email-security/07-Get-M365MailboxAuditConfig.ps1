#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Verifica la configurazione del mailbox auditing su tutte le caselle.
.DESCRIPTION
    Gli audit (eliminazioni, Send As, accessi non-owner) funzionano solo se il mailbox
    auditing è attivo. Questo script elenca le caselle e lo stato dell'auditing,
    evidenziando quelle con auditing DISABILITATO (gap di sicurezza). Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-MailboxAuditConfig-<data>.csv
.EXAMPLE
    .\07-Get-M365MailboxAuditConfig.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients).
    NB: dal 2019 l'auditing è on-by-default a livello di organizzazione, ma può essere
    stato disabilitato su singole caselle: questo report lo verifica.
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-MailboxAuditConfig-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited -Properties AuditEnabled, AuditLogAgeLimit) {
    [pscustomobject]@{
        PrimarySmtpAddress = $mbx.PrimarySmtpAddress
        Type               = $mbx.RecipientTypeDetails
        AuditEnabled       = $mbx.AuditEnabled
        AuditLogAgeLimit   = $mbx.AuditLogAgeLimit
    }
}
$report | Sort-Object AuditEnabled | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$off = ($report | Where-Object { -not $_.AuditEnabled }).Count
Write-Host ("{0} caselle totali, {1} con auditing DISABILITATO → {2}" -f $report.Count, $off, $OutputCsv) -ForegroundColor Yellow
