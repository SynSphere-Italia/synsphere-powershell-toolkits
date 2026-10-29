#Requires -Modules ExchangeOnlineManagement, Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Trova le caselle condivise (shared mailbox) che hanno una licenza assegnata.
.DESCRIPTION
    Le shared mailbox di norma NON richiedono licenza (fino a 50 GB). Una shared
    mailbox licenziata è quasi sempre spesa sprecata. Lo script le individua
    incrociando Exchange Online e Microsoft Graph. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV di output. Default: .\M365-LicensedSharedMailboxes-<data>.csv
.EXAMPLE
    .\04-Get-M365LicensedSharedMailboxes.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (Connect-ExchangeOnline) + Graph User.Read.All, Organization.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-LicensedSharedMailboxes-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-ExchangeOnline -ShowBanner:$false
Connect-MgGraph -Scopes 'User.Read.All', 'Organization.Read.All' -NoWelcome

$skuMap = @{}; Get-MgSubscribedSku -All | ForEach-Object { $skuMap[$_.SkuId] = $_.SkuPartNumber }

$report = foreach ($mbx in Get-EXOMailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited) {
    $user = Get-MgUser -UserId $mbx.ExternalDirectoryObjectId -Property DisplayName, UserPrincipalName, AssignedLicenses -ErrorAction SilentlyContinue
    if ($user -and $user.AssignedLicenses.Count -gt 0) {
        [pscustomobject]@{
            SharedMailbox     = $mbx.DisplayName
            UserPrincipalName = $mbx.PrimarySmtpAddress
            Licenses          = ($user.AssignedLicenses | ForEach-Object { $skuMap[$_.SkuId] }) -join '; '
        }
    }
}

if ($report) {
    $report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host ("Trovate {0} shared mailbox CON licenza (potenziale spesa da recuperare) → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
} else {
    Write-Host "Nessuna shared mailbox licenziata: ottimo, nessuna licenza sprecata qui." -ForegroundColor Green
}
