#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Elenca tutte le caselle a cui un determinato utente ha accesso (Full Access / Send As).
.DESCRIPTION
    Lookup "inverso": dato un utente, trova su quali caselle altrui ha permessi.
    Utile prima di un offboarding o per audit di sicurezza. Sola lettura.
.PARAMETER UserPrincipalName
    Utente di cui cercare gli accessi (obbligatorio).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-MailboxesAccessOf-<data>.csv
.EXAMPLE
    .\03-Get-M365MailboxesUserHasAccessTo.ps1 -UserPrincipalName mario.rossi@azienda.it
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients). Scansiona tutte le caselle: su tenant grandi è lento.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$UserPrincipalName,
    [string]$OutputCsv = (".\M365-MailboxesAccessOf-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited) {
    $id = $mbx.PrimarySmtpAddress
    if ($id -eq $UserPrincipalName) { continue }   # salta la propria casella
    $fa = Get-EXOMailboxPermission -Identity $id | Where-Object { $_.User -eq $UserPrincipalName -and $_.AccessRights -contains 'FullAccess' -and -not $_.IsInherited }
    if ($fa) { [pscustomobject]@{ Mailbox = $id; Permission = 'FullAccess' } }
    $sa = Get-EXORecipientPermission -Identity $id | Where-Object { $_.Trustee -eq $UserPrincipalName -and $_.AccessRights -contains 'SendAs' }
    if ($sa) { [pscustomobject]@{ Mailbox = $id; Permission = 'SendAs' } }
}
$report | Sort-Object Mailbox | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} ha accesso a {1} caselle → {2}" -f $UserPrincipalName, $report.Count, $OutputCsv) -ForegroundColor Green
