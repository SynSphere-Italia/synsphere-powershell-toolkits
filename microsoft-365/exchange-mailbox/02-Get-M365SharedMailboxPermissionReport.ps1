#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report deleghe sulle SHARED MAILBOX (Full Access, Send As, Send on Behalf).
.DESCRIPTION
    Come il report deleghe generale ma limitato alle caselle condivise: chi ha accesso
    a info@, amministrazione@, vendite@, ecc. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-SharedMailboxPermissions-<data>.csv
.EXAMPLE
    .\02-Get-M365SharedMailboxPermissionReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-SharedMailboxPermissions-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($mbx in Get-EXOMailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited -Properties GrantSendOnBehalfTo) {
    $id = $mbx.PrimarySmtpAddress
    foreach ($p in Get-EXOMailboxPermission -Identity $id | Where-Object {
            $_.AccessRights -contains 'FullAccess' -and -not $_.IsInherited -and $_.User -notlike 'NT AUTHORITY\*' }) {
        [pscustomobject]@{ SharedMailbox = $id; Delegate = $p.User; Permission = 'FullAccess' }
    }
    foreach ($p in Get-EXORecipientPermission -Identity $id | Where-Object {
            $_.AccessRights -contains 'SendAs' -and $_.Trustee -notlike 'NT AUTHORITY\*' }) {
        [pscustomobject]@{ SharedMailbox = $id; Delegate = $p.Trustee; Permission = 'SendAs' }
    }
    foreach ($d in $mbx.GrantSendOnBehalfTo) {
        [pscustomobject]@{ SharedMailbox = $id; Delegate = $d; Permission = 'SendOnBehalf' }
    }
}
$report | Sort-Object SharedMailbox, Permission | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} deleghe su shared mailbox in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
