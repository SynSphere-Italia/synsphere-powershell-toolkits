#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report deleghe sulle caselle Exchange Online: Full Access, Send As, Send on Behalf.
.DESCRIPTION
    Per ogni casella elenca i delegati con permessi espliciti (esclude i permessi di
    sistema ed ereditati). Una riga per coppia casella/delegato. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-MailboxPermissions-<data>.csv
.EXAMPLE
    .\01-Get-M365MailboxPermissionReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients). Su tenant grandi può richiedere tempo.
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-MailboxPermissions-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited -Properties GrantSendOnBehalfTo) {
    $id = $mbx.PrimarySmtpAddress
    # Full Access (esclude SELF, ereditati)
    foreach ($p in Get-EXOMailboxPermission -Identity $id | Where-Object {
            $_.AccessRights -contains 'FullAccess' -and -not $_.IsInherited -and $_.User -notlike 'NT AUTHORITY\*' }) {
        [pscustomobject]@{ Mailbox = $id; Delegate = $p.User; Permission = 'FullAccess' }
    }
    # Send As
    foreach ($p in Get-EXORecipientPermission -Identity $id | Where-Object {
            $_.AccessRights -contains 'SendAs' -and $_.Trustee -notlike 'NT AUTHORITY\*' }) {
        [pscustomobject]@{ Mailbox = $id; Delegate = $p.Trustee; Permission = 'SendAs' }
    }
    # Send on Behalf
    foreach ($d in $mbx.GrantSendOnBehalfTo) {
        [pscustomobject]@{ Mailbox = $id; Delegate = $d; Permission = 'SendOnBehalf' }
    }
}
$report | Sort-Object Mailbox, Permission | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} deleghe in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
