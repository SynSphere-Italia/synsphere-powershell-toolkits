#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Deleghe delle cassette: FullAccess, SendAs e SendOnBehalf.
.DESCRIPTION
    Le deleghe non si spostano insieme alla cassetta: vanno ricostruite sul tenant di
    destinazione. Questo report e' l'elenco di cosa ricostruire.

    Il filtro che quasi tutti sbagliano: NT AUTHORITY\SELF ha FullAccess e ReadPermission
    ASSEGNATI DIRETTAMENTE, non ereditati. Il classico Where-Object { -not $_.IsInherited }
    quindi NON lo esclude, e il report esce con una delega fantasma su OGNI cassetta del tenant:
    l'elenco delle deleghe da ricostruire risulta gonfiato del doppio. Qui SELF viene escluso
    per nome, e vengono scartate anche le voci con Deny (FullAccess e' negato per eredita' ad
    Administrator, Domain Admins, Enterprise Admins e Organization Management: sono permessi
    apparenti, sovrascritti dal Deny).

    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\T2T-Delegations-<data>.csv
.EXAMPLE
    .\03-Get-T2TMailboxDelegations.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Ruolo minimo: View-Only Organization Management
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\T2T-Delegations-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
    Connect-ExchangeOnline -ShowBanner:$false
}

$daIgnorare = @('NT AUTHORITY\SELF', 'NT AUTHORITY\SYSTEM', 'S-1-5-10')

$mailboxes = Get-EXOMailbox -ResultSize Unlimited `
    -RecipientTypeDetails UserMailbox, SharedMailbox, RoomMailbox, EquipmentMailbox `
    -Properties DisplayName, UserPrincipalName, PrimarySmtpAddress, GrantSendOnBehalfTo

$totale = @($mailboxes).Count
$i = 0

$report = foreach ($mb in $mailboxes) {
    $i++
    if ($totale -gt 50 -and ($i % 25) -eq 0) {
        Write-Progress -Activity "Deleghe" -Status ("{0} di {1}" -f $i, $totale) -PercentComplete (100 * $i / $totale)
    }

    # --- FullAccess -------------------------------------------------------------------
    try {
        Get-EXOMailboxPermission -Identity $mb.PrimarySmtpAddress -ErrorAction Stop |
            Where-Object {
                $_.User -notin $daIgnorare -and
                $_.Deny -ne $true -and
                $_.AccessRights -contains 'FullAccess'
            } |
            ForEach-Object {
                [pscustomobject]@{
                    Cassetta          = $mb.PrimarySmtpAddress
                    DisplayName       = $mb.DisplayName
                    TipoDelega        = 'FullAccess'
                    Delegato          = $_.User
                    Ereditata         = $_.IsInherited
                    AutoMapping       = '(non esposto dai cmdlet di permessi)'
                }
            }
    } catch {
        Write-Warning ("FullAccess non leggibile per {0}" -f $mb.PrimarySmtpAddress)
    }

    # --- SendAs -----------------------------------------------------------------------
    try {
        Get-EXORecipientPermission -Identity $mb.PrimarySmtpAddress -ErrorAction Stop |
            Where-Object {
                $_.Trustee -notin $daIgnorare -and
                $_.AccessControlType -eq 'Allow' -and
                $_.AccessRights -contains 'SendAs'
            } |
            ForEach-Object {
                [pscustomobject]@{
                    Cassetta          = $mb.PrimarySmtpAddress
                    DisplayName       = $mb.DisplayName
                    TipoDelega        = 'SendAs'
                    Delegato          = $_.Trustee
                    Ereditata         = $_.IsInherited
                    AutoMapping       = ''
                }
            }
    } catch {
        Write-Warning ("SendAs non leggibile per {0}" -f $mb.PrimarySmtpAddress)
    }

    # --- SendOnBehalf: e' una proprieta' della cassetta, non un ACL -------------------
    foreach ($d in @($mb.GrantSendOnBehalfTo)) {
        if ($d) {
            [pscustomobject]@{
                Cassetta          = $mb.PrimarySmtpAddress
                DisplayName       = $mb.DisplayName
                TipoDelega        = 'SendOnBehalf'
                Delegato          = $d
                Ereditata         = $false
                AutoMapping       = ''
            }
        }
    }
}

Write-Progress -Activity "Deleghe" -Completed
$report | Sort-Object Cassetta, TipoDelega, Delegato | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ("Cassette esaminate: {0} | deleghe da ricostruire: {1}" -f $totale, @($report).Count)
$report | Group-Object TipoDelega | ForEach-Object { Write-Host ("  {0,-14} {1}" -f $_.Name, $_.Count) }
Write-Host ("Esportato in {0}" -f $OutputCsv)
