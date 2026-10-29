<#
.SYNOPSIS
    Configura (o revoca) la delega di una cassetta Microsoft 365 / Exchange Online
    verso un altro utente — scenario tipico "assistente che gestisce la posta del responsabile".

.DESCRIPTION
    Script per amministratore di sistema. Assegna in modo idempotente i quattro
    permessi di delega su una cassetta:
      - FullAccess    : l'assistente apre, legge e gestisce la casella (NON invia da solo)
      - SendAs        : l'assistente invia COME il responsabile (il destinatario vede solo il responsabile)
      - SendOnBehalf  : l'assistente invia PER CONTO del responsabile (resta tracciabile chi ha scritto)
      - InboxEditor   : permesso di sola cartella (es. Posta in arrivo) senza accesso completo

    Combinazioni rapide tramite -Preset:
      - Assistente      = FullAccess + SendOnBehalf  (gestione trasparente/tracciabile)
      - AssistenteComeMe = FullAccess + SendAs        (invio "trasparente" a nome del responsabile)

    Si connette automaticamente a Exchange Online (modulo ExchangeOnlineManagement),
    valida che casella e delegato esistano, applica solo ciò che manca, e al termine
    verifica e stampa lo stato. Con -Remove revoca i permessi (procedura di offboarding).
    Supporta -WhatIf / -Confirm e scrive un log con timestamp.

.PARAMETER Mailbox
    UPN/indirizzo della cassetta del responsabile (es. mario.rossi@dominio.it).

.PARAMETER Delegate
    UPN/indirizzo dell'assistente a cui dare la delega.

.PARAMETER Permission
    Uno o più tra: FullAccess, SendAs, SendOnBehalf, InboxEditor.
    Ignorato se si usa -Preset.

.PARAMETER Preset
    Scorciatoia: 'Assistente' (FullAccess+SendOnBehalf) oppure 'AssistenteComeMe' (FullAccess+SendAs).

.PARAMETER AutoMapping
    $true (default) = la casella compare automaticamente in Outlook dell'assistente.
    $false = niente automapping (consigliato se l'assistente gestisce molte caselle).

.PARAMETER Folder
    Cartella per il permesso InboxEditor (default 'Posta in arrivo'; su tenant EN: 'Inbox').

.PARAMETER Remove
    Revoca i permessi indicati invece di assegnarli (offboarding).

.PARAMETER AdminUpn
    UPN dell'amministratore per la connexione a Exchange Online (se non già connesso).

.PARAMETER LogPath
    Percorso del file di log (default: .\Set-MailboxDelegation.log).

.EXAMPLE
    .\Set-MailboxDelegation.ps1 -Mailbox direttore@contoso.it -Delegate segreteria@contoso.it -Preset Assistente
    # Accesso completo + Invia per conto (scenario assistente classico).

.EXAMPLE
    .\Set-MailboxDelegation.ps1 -Mailbox ceo@contoso.it -Delegate ufficio@contoso.it -Preset AssistenteComeMe -AutoMapping $false
    # Accesso completo + Invia come, senza automapping.

.EXAMPLE
    .\Set-MailboxDelegation.ps1 -Mailbox direttore@contoso.it -Delegate segreteria@contoso.it -Permission SendAs,FullAccess -Remove
    # Revoca i permessi (offboarding).

.EXAMPLE
    .\Set-MailboxDelegation.ps1 -Mailbox direttore@contoso.it -Delegate stage@contoso.it -Permission InboxEditor -WhatIf
    # Simula l'assegnazione del solo permesso sulla Posta in arrivo.

.NOTES
    Autore : SynSphere Italia — https://synsphere.it
    Guida  : https://synsphere.it/notizie/delegare-cassetta-mail-microsoft-365-assistente-pmi
    Requisiti: PowerShell 5.1+ o 7+, modulo ExchangeOnlineManagement, ruolo di amministrazione Exchange.
    Fornito "as is": testare in un tenant di prova prima dell'uso in produzione.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][string]$Mailbox,
    [Parameter(Mandatory)][string]$Delegate,

    [ValidateSet('FullAccess', 'SendAs', 'SendOnBehalf', 'InboxEditor')]
    [string[]]$Permission = @('FullAccess', 'SendOnBehalf'),

    [ValidateSet('Assistente', 'AssistenteComeMe')]
    [string]$Preset,

    [bool]$AutoMapping = $true,
    [string]$Folder = 'Posta in arrivo',
    [switch]$Remove,
    [string]$AdminUpn,
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath 'Set-MailboxDelegation.log')
)

# ─────────────────────────────────────────────────────────────────────────────
# Helper di logging
# ─────────────────────────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Message, [ValidateSet('INFO', 'OK', 'WARN', 'ERR')][string]$Level = 'INFO')
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$stamp] [$Level] $Message"
    $color = @{ INFO = 'Gray'; OK = 'Green'; WARN = 'Yellow'; ERR = 'Red' }[$Level]
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Modulo + connessione a Exchange Online
# ─────────────────────────────────────────────────────────────────────────────
function Connect-EXOIfNeeded {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Log "Modulo ExchangeOnlineManagement non trovato: installazione (CurrentUser)..." 'WARN'
        Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module ExchangeOnlineManagement -ErrorAction Stop

    $connected = $false
    try { $connected = [bool](Get-ConnectionInformation -ErrorAction Stop) } catch { $connected = $false }

    if (-not $connected) {
        Write-Log "Connessione a Exchange Online..." 'INFO'
        if ($AdminUpn) { Connect-ExchangeOnline -UserPrincipalName $AdminUpn -ShowBanner:$false }
        else { Connect-ExchangeOnline -ShowBanner:$false }
    }
    Write-Log "Connesso a Exchange Online." 'OK'
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Validazione destinatari
# ─────────────────────────────────────────────────────────────────────────────
function Test-RecipientExists {
    param([string]$Identity, [string]$Ruolo)
    try {
        $null = Get-Mailbox -Identity $Identity -ErrorAction Stop
        Write-Log "$Ruolo valido: $Identity" 'OK'
        return $true
    } catch {
        Write-Log "$Ruolo NON trovato: $Identity — interrompo." 'ERR'
        return $false
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Applicazione / revoca dei singoli permessi (idempotenti)
# ─────────────────────────────────────────────────────────────────────────────
function Set-FullAccess {
    $has = Get-MailboxPermission -Identity $Mailbox -User $Delegate -ErrorAction SilentlyContinue |
        Where-Object { $_.AccessRights -contains 'FullAccess' }
    if ($Remove) {
        if (-not $has) { Write-Log "FullAccess: non presente, niente da rimuovere." 'INFO'; return }
        if ($PSCmdlet.ShouldProcess($Mailbox, "Rimuovi FullAccess a $Delegate")) {
            Remove-MailboxPermission -Identity $Mailbox -User $Delegate -AccessRights FullAccess -Confirm:$false -ErrorAction Stop
            Write-Log "FullAccess rimosso per $Delegate." 'OK'
        }
    } else {
        if ($has) { Write-Log "FullAccess: già presente, salto." 'INFO'; return }
        if ($PSCmdlet.ShouldProcess($Mailbox, "Concedi FullAccess a $Delegate (AutoMapping=$AutoMapping)")) {
            Add-MailboxPermission -Identity $Mailbox -User $Delegate -AccessRights FullAccess `
                -InheritanceType All -AutoMapping $AutoMapping -ErrorAction Stop | Out-Null
            Write-Log "FullAccess concesso a $Delegate (AutoMapping=$AutoMapping)." 'OK'
        }
    }
}

function Set-SendAs {
    $has = Get-RecipientPermission -Identity $Mailbox -Trustee $Delegate -ErrorAction SilentlyContinue |
        Where-Object { $_.AccessRights -contains 'SendAs' }
    if ($Remove) {
        if (-not $has) { Write-Log "SendAs: non presente, niente da rimuovere." 'INFO'; return }
        if ($PSCmdlet.ShouldProcess($Mailbox, "Rimuovi SendAs a $Delegate")) {
            Remove-RecipientPermission -Identity $Mailbox -Trustee $Delegate -AccessRights SendAs -Confirm:$false -ErrorAction Stop
            Write-Log "SendAs rimosso per $Delegate." 'OK'
        }
    } else {
        if ($has) { Write-Log "SendAs: già presente, salto." 'INFO'; return }
        if ($PSCmdlet.ShouldProcess($Mailbox, "Concedi SendAs a $Delegate")) {
            Add-RecipientPermission -Identity $Mailbox -Trustee $Delegate -AccessRights SendAs -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Log "SendAs concesso a $Delegate." 'OK'
        }
    }
}

function Set-SendOnBehalf {
    $current = (Get-Mailbox -Identity $Mailbox).GrantSendOnBehalfTo
    $has = $current -and ($current | Where-Object { $_ -match [regex]::Escape($Delegate.Split('@')[0]) })
    if ($Remove) {
        if (-not $has) { Write-Log "SendOnBehalf: non presente, niente da rimuovere." 'INFO'; return }
        if ($PSCmdlet.ShouldProcess($Mailbox, "Rimuovi SendOnBehalf a $Delegate")) {
            Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo @{Remove = $Delegate } -ErrorAction Stop
            Write-Log "SendOnBehalf rimosso per $Delegate." 'OK'
        }
    } else {
        if ($has) { Write-Log "SendOnBehalf: già presente, salto." 'INFO'; return }
        if ($PSCmdlet.ShouldProcess($Mailbox, "Concedi SendOnBehalf a $Delegate")) {
            Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo @{Add = $Delegate } -ErrorAction Stop
            Write-Log "SendOnBehalf concesso a $Delegate." 'OK'
        }
    }
}

function Set-InboxEditor {
    $target = "${Mailbox}:\$Folder"
    if ($Remove) {
        if ($PSCmdlet.ShouldProcess($target, "Rimuovi permesso cartella a $Delegate")) {
            Remove-MailboxFolderPermission -Identity $target -User $Delegate -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "Permesso cartella rimosso su '$Folder' per $Delegate." 'OK'
        }
    } else {
        if ($PSCmdlet.ShouldProcess($target, "Concedi Editor sulla cartella '$Folder' a $Delegate")) {
            try {
                Add-MailboxFolderPermission -Identity $target -User $Delegate -AccessRights Editor -ErrorAction Stop | Out-Null
            } catch {
                # se esiste già, aggiorna invece di fallire
                Set-MailboxFolderPermission -Identity $target -User $Delegate -AccessRights Editor -ErrorAction Stop | Out-Null
            }
            Write-Log "Editor concesso sulla cartella '$Folder' a $Delegate." 'OK'
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
Write-Log "=== Set-MailboxDelegation — SynSphere Italia ===" 'INFO'

# Preset → espande la lista permessi
if ($Preset -eq 'Assistente') { $Permission = @('FullAccess', 'SendOnBehalf') }
elseif ($Preset -eq 'AssistenteComeMe') { $Permission = @('FullAccess', 'SendAs') }

$azione = if ($Remove) { 'REVOCA' } else { 'ASSEGNAZIONE' }
Write-Log "$azione delega — Casella: $Mailbox | Delegato: $Delegate | Permessi: $($Permission -join ', ')" 'INFO'

Connect-EXOIfNeeded

if (-not (Test-RecipientExists -Identity $Mailbox -Ruolo 'Casella (responsabile)')) { return }
if (-not (Test-RecipientExists -Identity $Delegate -Ruolo 'Delegato (assistente)')) { return }

foreach ($p in $Permission) {
    switch ($p) {
        'FullAccess' { Set-FullAccess }
        'SendAs' { Set-SendAs }
        'SendOnBehalf' { Set-SendOnBehalf }
        'InboxEditor' { Set-InboxEditor }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Verifica finale
# ─────────────────────────────────────────────────────────────────────────────
Write-Log "--- Stato finale dei permessi ---" 'INFO'
Write-Log ("FullAccess  : " + ((Get-MailboxPermission -Identity $Mailbox -User $Delegate -EA SilentlyContinue).AccessRights -join ',')) 'INFO'
Write-Log ("SendAs      : " + ((Get-RecipientPermission -Identity $Mailbox -Trustee $Delegate -EA SilentlyContinue).AccessRights -join ',')) 'INFO'
Write-Log ("SendOnBehalf: " + (((Get-Mailbox -Identity $Mailbox).GrantSendOnBehalfTo) -join ',')) 'INFO'

Write-Log "Operazione completata. La propagazione può richiedere fino a ~60 minuti." 'OK'
Write-Log "Log salvato in: $LogPath" 'INFO'
