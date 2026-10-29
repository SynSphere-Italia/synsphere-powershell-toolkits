#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, ExchangeOnlineManagement
<#
.SYNOPSIS
    Offboarding di un utente Microsoft 365 secondo le best practice (in un solo script).
.DESCRIPTION
    Esegue in sequenza i passi tipici di offboarding di un dipendente:
      1. Blocco accesso (account disabilitato)
      2. Revoca delle sessioni attive (token)
      3. Reset password a un valore casuale
      4. Rimozione da tutti i gruppi (salta gruppi dinamici/ruoli)
      5. Rimozione di tutte le licenze
      6. Conversione della casella in Shared Mailbox (mantiene i dati senza licenza)
      7. Nascondi dalla rubrica (GAL)
      8. Attivazione risposta automatica (out-of-office)

    Supporta -WhatIf per simulare ogni operazione senza applicarla.
    Salta singoli passi con i relativi switch -Skip*.
.PARAMETER UserPrincipalName
    UPN dell'utente da disattivare (obbligatorio).
.PARAMETER AutoReplyMessage
    Testo della risposta automatica. Default: messaggio generico "non più in azienda".
.EXAMPLE
    .\10-Invoke-M365UserOffboarding.ps1 -UserPrincipalName mario.rossi@azienda.it -WhatIf
.EXAMPLE
    .\10-Invoke-M365UserOffboarding.ps1 -UserPrincipalName mario.rossi@azienda.it
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". ESEGUIRE PRIMA con -WhatIf.
    Permessi Graph: User.ReadWrite.All, Group.ReadWrite.All, Directory.ReadWrite.All, Organization.Read.All
    + Exchange Online (Connect-ExchangeOnline) per i passi su casella/GAL/auto-reply.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][string]$UserPrincipalName,
    [switch]$SkipMailbox,
    [string]$AutoReplyMessage = "Questa persona non fa più parte dell'organizzazione. Per assistenza contatta il nostro centralino o scrivi a info@azienda.it."
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.ReadWrite.All', 'Group.ReadWrite.All', 'Directory.ReadWrite.All', 'Organization.Read.All' -NoWelcome

$user = Get-MgUser -UserId $UserPrincipalName -Property Id, DisplayName, AssignedLicenses
Write-Host ("Offboarding di {0} ({1})" -f $user.DisplayName, $UserPrincipalName) -ForegroundColor Cyan

# 1) Blocco accesso
if ($PSCmdlet.ShouldProcess($UserPrincipalName, '1) Blocca accesso')) {
    Update-MgUser -UserId $user.Id -AccountEnabled:$false; Write-Host '  [1] Accesso bloccato' -ForegroundColor Green
}
# 2) Revoca sessioni
if ($PSCmdlet.ShouldProcess($UserPrincipalName, '2) Revoca sessioni')) {
    Revoke-MgUserSignInSession -UserId $user.Id | Out-Null; Write-Host '  [2] Sessioni revocate' -ForegroundColor Green
}
# 3) Reset password a valore casuale
if ($PSCmdlet.ShouldProcess($UserPrincipalName, '3) Reset password casuale')) {
    $rnd = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
    Update-MgUser -UserId $user.Id -PasswordProfile @{ Password = "$rnd!Aa9"; ForceChangePasswordNextSignIn = $true }
    Write-Host '  [3] Password resettata' -ForegroundColor Green
}
# 4) Rimozione da tutti i gruppi (salta dinamici e ruoli)
if ($PSCmdlet.ShouldProcess($UserPrincipalName, '4) Rimuovi da tutti i gruppi')) {
    foreach ($g in Get-MgUserMemberOf -UserId $user.Id -All) {
        if ($g.AdditionalProperties.'@odata.type' -ne '#microsoft.graph.group') { continue }
        try { Remove-MgGroupMemberByRef -GroupId $g.Id -DirectoryObjectId $user.Id -ErrorAction Stop }
        catch { Write-Warning ("    gruppo non rimovibile (dinamico/ruolo?): {0}" -f $g.AdditionalProperties.displayName) }
    }
    Write-Host '  [4] Rimosso dai gruppi' -ForegroundColor Green
}
# 5) Rimozione licenze (dopo il degroup: restano solo le dirette)
if ($PSCmdlet.ShouldProcess($UserPrincipalName, '5) Rimuovi licenze')) {
    $skuIds = (Get-MgUser -UserId $user.Id -Property AssignedLicenses).AssignedLicenses.SkuId
    if ($skuIds) { try { Set-MgUserLicense -UserId $user.Id -AddLicenses @() -RemoveLicenses $skuIds | Out-Null } catch { Write-Warning $_.Exception.Message } }
    Write-Host '  [5] Licenze rimosse' -ForegroundColor Green
}

# 6-8) Operazioni su Exchange Online (casella, GAL, auto-reply)
if (-not $SkipMailbox) {
    Connect-ExchangeOnline -ShowBanner:$false
    if ($PSCmdlet.ShouldProcess($UserPrincipalName, '6) Converti casella in Shared')) {
        Set-Mailbox -Identity $UserPrincipalName -Type Shared; Write-Host '  [6] Casella convertita in Shared' -ForegroundColor Green
    }
    if ($PSCmdlet.ShouldProcess($UserPrincipalName, '7) Nascondi dalla rubrica (GAL)')) {
        Set-Mailbox -Identity $UserPrincipalName -HiddenFromAddressListsEnabled $true; Write-Host '  [7] Nascosta dalla GAL' -ForegroundColor Green
    }
    if ($PSCmdlet.ShouldProcess($UserPrincipalName, '8) Attiva risposta automatica')) {
        Set-MailboxAutoReplyConfiguration -Identity $UserPrincipalName -AutoReplyState Enabled -InternalMessage $AutoReplyMessage -ExternalMessage $AutoReplyMessage
        Write-Host '  [8] Risposta automatica attivata' -ForegroundColor Green
    }
}

Write-Host "Offboarding completato. Ricorda: imposta eventuali deleghe (manager) sulla shared mailbox." -ForegroundColor Cyan
