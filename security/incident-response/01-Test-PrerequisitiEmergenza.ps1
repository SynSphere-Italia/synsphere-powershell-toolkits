#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Go / no-go prima di un contenimento: cosa si riesce davvero a raccogliere su questo tenant.
.DESCRIPTION
    Da eseguire PER PRIMO, prima di toccare qualsiasi cosa. Non modifica nulla.

    Risponde alle tre domande che decidono l'intera raccolta di prove, e a cui il portale
    non risponde in modo diretto:

      1. I sign-in log di Entra sono interrogabili? Richiedono Entra ID P1 o P2. Su un
         tenant Business Basic o Standard NON esistono via API: l'assenza di licenza si
         presenta come un errore di autorizzazione, non come "log vuoti".
      2. Il log di controllo unificato sta registrando? Va letto da Exchange Online, non
         da Security & Compliance: nel contesto sbagliato la proprieta' risponde SEMPRE
         False, senza errore, e si conclude "audit spento" su un tenant dove e' acceso.
      3. Il modulo Exchange Online e' abbastanza recente per Get-MessageTraceV2? Serve la
         3.7.0 o superiore: Get-MessageTrace, il cmdlet storico, e' deprecato.

    Stampa anche la finestra temporale REALE di ciascuna fonte: e' il vincolo che decide
    quanto indietro si puo' guardare, e non e' negoziabile.
.PARAMETER OutputCsv
    Percorso del CSV di esito. Default: .\IR-01-Prerequisiti-<data>.csv
.EXAMPLE
    .\01-Test-PrerequisitiEmergenza.ps1
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Sola lettura. Permessi Graph: AuditLog.Read.All, Directory.Read.All, User.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\IR-01-Prerequisiti-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
)

$ErrorActionPreference = 'Continue'
$esiti = New-Object System.Collections.Generic.List[object]

function Add-Esito {
    param([string]$Area, [string]$Controllo, [string]$Stato, [string]$Dettaglio, [string]$Impatto)
    $esiti.Add([pscustomobject]@{
        Area      = $Area
        Controllo = $Controllo
        Stato     = $Stato
        Dettaglio = $Dettaglio
        Impatto   = $Impatto
    })
}

Write-Host ''
Write-Host '=== Prerequisiti per la raccolta di prove ===' -ForegroundColor Cyan
Write-Host ''

# ----------------------------------------------------------------------------------
# 1. Moduli
# ----------------------------------------------------------------------------------
$mgAuth = Get-Module -ListAvailable -Name Microsoft.Graph.Authentication |
    Sort-Object Version -Descending | Select-Object -First 1
if ($mgAuth) {
    Add-Esito 'Moduli' 'Microsoft.Graph' 'OK' ("versione {0}" -f $mgAuth.Version) ''
} else {
    Add-Esito 'Moduli' 'Microsoft.Graph' 'MANCANTE' 'non installato' `
        'Install-Module Microsoft.Graph -Scope CurrentUser'
}

$exo = Get-Module -ListAvailable -Name ExchangeOnlineManagement |
    Sort-Object Version -Descending | Select-Object -First 1
if (-not $exo) {
    Add-Esito 'Moduli' 'ExchangeOnlineManagement' 'MANCANTE' 'non installato' `
        'Install-Module ExchangeOnlineManagement -Scope CurrentUser'
} elseif ($exo.Version -lt [version]'3.7.0') {
    Add-Esito 'Moduli' 'ExchangeOnlineManagement' 'DA AGGIORNARE' `
        ("versione {0}, serve 3.7.0+" -f $exo.Version) `
        'Get-MessageTraceV2 non esiste sotto la 3.7.0 e Get-MessageTrace e deprecato'
} else {
    Add-Esito 'Moduli' 'ExchangeOnlineManagement' 'OK' ("versione {0}" -f $exo.Version) ''
}

# ----------------------------------------------------------------------------------
# 2. Contesto Graph e identita' dell'operatore
# ----------------------------------------------------------------------------------
$ctx = $null
try {
    $ctx = Get-MgContext -ErrorAction Stop
} catch { }

if (-not $ctx) {
    Connect-MgGraph -Scopes 'AuditLog.Read.All', 'Directory.Read.All', 'User.Read.All' -NoWelcome
    $ctx = Get-MgContext
}

if ($ctx) {
    Add-Esito 'Connessione' 'Microsoft Graph' 'OK' `
        ("account {0} - tenant {1}" -f $ctx.Account, $ctx.TenantId) `
        'Questo account va ESCLUSO dal blocco: e la vostra via di rientro'
    Write-Host ("Operatore corrente: {0}" -f $ctx.Account) -ForegroundColor Yellow
    Write-Host '  -> annotatelo: lo script 03 lo esclude automaticamente dal blocco.' -ForegroundColor Yellow
} else {
    Add-Esito 'Connessione' 'Microsoft Graph' 'FALLITA' 'nessun contesto' 'Raccolta impossibile'
}

# ----------------------------------------------------------------------------------
# 3. Sign-in log: esistono su questo tenant?
#    Il fallimento tipico su Business Basic/Standard e un errore di autorizzazione,
#    NON un elenco vuoto: va distinto, o si conclude "nessun accesso sospetto".
# ----------------------------------------------------------------------------------
$signInOk = $false
try {
    $prova = Get-MgAuditLogSignIn -Top 1 -ErrorAction Stop
    $signInOk = $true
    if ($prova) {
        Add-Esito 'Sign-in log' 'Disponibilita (Entra ID P1/P2)' 'OK' `
            ("ultimo evento leggibile: {0}" -f $prova[0].CreatedDateTime) `
            'Finestra reale: 30 giorni. Oltre non esistono.'
    } else {
        Add-Esito 'Sign-in log' 'Disponibilita (Entra ID P1/P2)' 'VUOTO' `
            'query riuscita ma nessun record' `
            'Tenant nuovo o senza attivita: NON e la stessa cosa di "non disponibile"'
    }
} catch {
    $msg = $_.Exception.Message
    $licenza = ($msg -match 'Premium|license|licens|B2C')
    if ($licenza) {
        Add-Esito 'Sign-in log' 'Disponibilita (Entra ID P1/P2)' 'NON DISPONIBILE' `
            'il tenant non ha Entra ID P1/P2' `
            'I sign-in log via API NON esistono: usare i log del Unified Audit Log (script 07)'
    } else {
        Add-Esito 'Sign-in log' 'Disponibilita (Entra ID P1/P2)' 'ERRORE' `
            $msg 'Verificare il ruolo: serve Security Reader o Reports Reader'
    }
}

# ----------------------------------------------------------------------------------
# 4. Log di controllo unificato: acceso o spento?
#    ATTENZIONE: UnifiedAuditLogIngestionEnabled va letto da Connect-ExchangeOnline.
#    Da Connect-IPPSSession risponde SEMPRE False, senza errore.
# ----------------------------------------------------------------------------------
$exoConnesso = $false
try {
    $null = Get-OrganizationConfig -ErrorAction Stop
    $exoConnesso = $true
} catch { }

if (-not $exoConnesso) {
    Write-Host 'Connessione a Exchange Online...' -ForegroundColor Cyan
    try {
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        $exoConnesso = $true
    } catch {
        Add-Esito 'Exchange Online' 'Connessione' 'FALLITA' $_.Exception.Message `
            'Senza Exchange non si raccolgono ne audit log ne message trace'
    }
}

if ($exoConnesso) {
    try {
        $cfg = Get-AdminAuditLogConfig -ErrorAction Stop
        if ($cfg.UnifiedAuditLogIngestionEnabled) {
            Add-Esito 'Log di controllo' 'Registrazione attiva' 'OK' `
                'UnifiedAuditLogIngestionEnabled = True' `
                'Finestra: 180 giorni (Audit Standard). 1 anno solo con Audit Premium / E5.'
        } else {
            Add-Esito 'Log di controllo' 'Registrazione attiva' 'SPENTO' `
                'UnifiedAuditLogIngestionEnabled = False' `
                'Non ci sono prove da raccogliere per il periodo passato. Accenderlo subito.'
        }
        Add-Esito 'Log di controllo' 'Contesto di lettura' 'NOTA' `
            'letto da Connect-ExchangeOnline' `
            'Da Connect-IPPSSession questa proprieta risponde sempre False: sarebbe un falso allarme'
    } catch {
        Add-Esito 'Log di controllo' 'Registrazione attiva' 'ERRORE' $_.Exception.Message `
            'Serve il ruolo View-Only Organization Management o superiore'
    }
}

# ----------------------------------------------------------------------------------
# 5. Dimensione del tenant: decide i tempi della raccolta
# ----------------------------------------------------------------------------------
if ($ctx) {
    try {
        $utenti = @(Get-MgUser -All -Property Id, AccountEnabled, UserType -ErrorAction Stop)
        $attivi = @($utenti | Where-Object { $_.AccountEnabled }).Count
        $guest  = @($utenti | Where-Object { $_.UserType -eq 'Guest' }).Count
        Add-Esito 'Tenant' 'Utenti' 'OK' `
            ("{0} totali, {1} abilitati, {2} guest" -f $utenti.Count, $attivi, $guest) `
            'Il blocco di massa agisce su questi numeri: rileggeteli prima di lanciarlo'
        Write-Host ''
        Write-Host ("Utenti: {0} totali - {1} abilitati - {2} guest" -f $utenti.Count, $attivi, $guest) -ForegroundColor Yellow
    } catch {
        Add-Esito 'Tenant' 'Utenti' 'ERRORE' $_.Exception.Message ''
    }
}

# ----------------------------------------------------------------------------------
# Esito
# ----------------------------------------------------------------------------------
$esiti | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ''
$esiti | Format-Table Area, Controllo, Stato, Dettaglio -AutoSize -Wrap

$bloccanti = @($esiti | Where-Object { $_.Stato -in @('MANCANTE', 'FALLITA', 'SPENTO') })
Write-Host ''
if ($bloccanti.Count -gt 0) {
    Write-Host ("{0} problemi bloccanti: leggeteli prima di procedere." -f $bloccanti.Count) -ForegroundColor Red
} else {
    Write-Host 'Nessun problema bloccante.' -ForegroundColor Green
}
Write-Host ("Esito -> {0}" -f $OutputCsv) -ForegroundColor Cyan
Write-Host ''
Write-Host 'PROSSIMO PASSO OBBLIGATORIO: 02-Backup-StatoUtenti.ps1' -ForegroundColor Yellow
Write-Host 'Senza quella fotografia il blocco non e reversibile.' -ForegroundColor Yellow
