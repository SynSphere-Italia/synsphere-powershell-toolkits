#Requires -Version 5.1
<#
.SYNOPSIS
    Migrazione email da Aruba a Microsoft 365 (Exchange Online) via migrazione IMAP.

.DESCRIPTION
    Script PARAMETRICO e commentato per automatizzare una migrazione IMAP delle
    caselle email da Aruba (imaps.aruba.it) a Microsoft 365 / Exchange Online.

    Lo script esegue, in sequenza:
      1. verifica dei prerequisiti (modulo ExchangeOnlineManagement, file CSV);
      2. connessione a Exchange Online;
      3. creazione (o riuso) dell'endpoint di migrazione IMAP verso Aruba;
      4. creazione del batch di migrazione a partire da un file CSV;
      5. avvio del batch e stampa delle istruzioni di monitoraggio.

    ATTENZIONE — la migrazione IMAP sposta SOLO la posta (cartelle e messaggi).
    NON migra contatti, calendari, attività e regole: vanno gestiti a parte
    (esportazione .pst / import, o ricreazione lato client). Vedi la sezione NOTE.

    Lo script è idempotente sui punti chiave: se l'endpoint esiste già viene
    riusato; supporta -WhatIf per simulare senza creare nulla.

.PARAMETER CsvPath
    Percorso del file CSV con le caselle da migrare. Intestazione richiesta da
    Microsoft per la migrazione IMAP (rispettare ESATTAMENTE i nomi colonna):

        EmailAddress,UserName,Password

      - EmailAddress : indirizzo della casella di DESTINAZIONE su Microsoft 365
                       (l'utente/mailbox deve già esistere ed essere licenziato);
      - UserName     : login della casella di ORIGINE su Aruba (di norma l'indirizzo completo);
      - Password     : password della casella di origine Aruba.

.PARAMETER TargetDeliveryDomain
    Dominio di recapito di destinazione, tipicamente il dominio onmicrosoft.com
    del tenant (es. "contoso.mail.onmicrosoft.com") oppure un dominio accettato.

.PARAMETER ArubaImapServer
    Host IMAP di origine. Default: "imaps.aruba.it". Verificare il server corretto
    nel pannello Aruba del dominio (alcune configurazioni usano host dedicati).

.PARAMETER ArubaImapPort
    Porta IMAP SSL di origine. Default: 993.

.PARAMETER BatchName
    Nome del batch di migrazione. Default: "Migrazione-Aruba-<data>".

.PARAMETER EndpointName
    Nome dell'endpoint di migrazione IMAP. Default: "Endpoint-Aruba-IMAP".

.PARAMETER NotificationEmails
    Uno o più indirizzi a cui inviare il report di fine migrazione.

.PARAMETER AutoStart
    Se presente, il batch parte subito dopo la creazione. Senza questo switch il
    batch viene creato in stato "Stopped" e va avviato manualmente (utile per i test).

.EXAMPLE
    .\migrazione-aruba-microsoft-365-synsphere.ps1 `
        -CsvPath .\caselle-aruba.csv `
        -TargetDeliveryDomain "contoso.mail.onmicrosoft.com" `
        -NotificationEmails "it@contoso.it" `
        -AutoStart

.EXAMPLE
    # Simulazione (non crea nulla): verifica prerequisiti e parametri
    .\migrazione-aruba-microsoft-365-synsphere.ps1 -CsvPath .\caselle-aruba.csv `
        -TargetDeliveryDomain "contoso.mail.onmicrosoft.com" -WhatIf

.NOTES
    Autore : SynSphere Italia — https://synsphere.it
    Licenza: uso interno aziendale gratuito (no redistribuzione commerciale).

    PREREQUISITI
      - Modulo PowerShell: ExchangeOnlineManagement (Install-Module ExchangeOnlineManagement).
      - Account amministratore Exchange/Global con MFA: usa l'autenticazione moderna
        (si apre il browser). NON inserire password admin nello script.
      - Le caselle di DESTINAZIONE devono già esistere su Microsoft 365 e avere una
        licenza con Exchange Online assegnata.
      - Dominio personalizzato già aggiunto e verificato nel tenant Microsoft 365.
      - Aruba: credenziali valide delle caselle di origine; attenzione al throttling
        IMAP di Aruba (può rallentare batch grandi → migrare a ondate da 20-50 caselle).

    DOPO LA MIGRAZIONE
      - Spostare il record MX del dominio verso Microsoft 365 (cutover) in finestra
        concordata, e aggiornare SPF/DKIM/DMARC.
      - Riconfigurare i client Outlook sugli account Microsoft 365.
      - Contatti e calendari: esportare da Aruba (.pst via Outlook) e importare, oppure
        ricreare. La migrazione IMAP NON li include.

    Questo script è fornito "as is". Testare sempre su poche caselle prima del rollout.
    Supporto alla migrazione: https://synsphere.it/contattaci
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [string]$TargetDeliveryDomain,

    [Parameter(Mandatory = $false)]
    [string]$ArubaImapServer = 'imaps.aruba.it',

    [Parameter(Mandatory = $false)]
    [int]$ArubaImapPort = 993,

    [Parameter(Mandatory = $false)]
    [string]$BatchName = ("Migrazione-Aruba-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmm')),

    [Parameter(Mandatory = $false)]
    [string]$EndpointName = 'Endpoint-Aruba-IMAP',

    [Parameter(Mandatory = $false)]
    [string[]]$NotificationEmails,

    [switch]$AutoStart
)

# Interrompe lo script al primo errore non gestito: in una migrazione vogliamo
# fermarci subito se qualcosa va storto, non proseguire alla cieca.
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

# ─────────────────────────────────────────────────────────────────────────────
# 1) PREREQUISITI — modulo ExchangeOnlineManagement
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Verifica del modulo ExchangeOnlineManagement"
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Warning "Modulo 'ExchangeOnlineManagement' non trovato."
    Write-Host   "Installalo (come amministratore) con:" -ForegroundColor Yellow
    Write-Host   "    Install-Module ExchangeOnlineManagement -Scope CurrentUser" -ForegroundColor Yellow
    throw "Modulo mancante: ExchangeOnlineManagement"
}
Import-Module ExchangeOnlineManagement -ErrorAction Stop

# ─────────────────────────────────────────────────────────────────────────────
# 2) VALIDAZIONE DEL CSV — intestazione attesa: EmailAddress,UserName,Password
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Validazione del file CSV: $CsvPath"
$righe = Import-Csv -Path $CsvPath
$colonneAttese = @('EmailAddress', 'UserName', 'Password')
$colonneTrovate = $righe[0].PSObject.Properties.Name
foreach ($c in $colonneAttese) {
    if ($colonneTrovate -notcontains $c) {
        throw "Colonna mancante nel CSV: '$c'. Intestazione richiesta: EmailAddress,UserName,Password"
    }
}
Write-Host ("CSV valido: {0} caselle da migrare." -f $righe.Count) -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# 3) CONNESSIONE A EXCHANGE ONLINE (autenticazione moderna / MFA)
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Connessione a Exchange Online"
# Se non c'è già una sessione attiva, apri il login (browser). Niente credenziali
# in chiaro nello script: si usa l'autenticazione moderna, compatibile con MFA.
$giaConnesso = $false
try { if (Get-ConnectionInformation -ErrorAction SilentlyContinue) { $giaConnesso = $true } } catch { $giaConnesso = $false }
if (-not $giaConnesso) {
    Connect-ExchangeOnline -ShowBanner:$false
}
Write-Host "Connesso a Exchange Online." -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# 4) ENDPOINT DI MIGRAZIONE IMAP (creato una volta, poi riusato)
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Endpoint di migrazione IMAP ($EndpointName)"
$endpoint = Get-MigrationEndpoint -Identity $EndpointName -ErrorAction SilentlyContinue
if ($null -eq $endpoint) {
    if ($PSCmdlet.ShouldProcess($EndpointName, "Crea endpoint IMAP verso $ArubaImapServer`:$ArubaImapPort")) {
        $endpoint = New-MigrationEndpoint -IMAP -Name $EndpointName `
            -RemoteServer $ArubaImapServer -Port $ArubaImapPort -Security Ssl
        Write-Host "Endpoint IMAP creato." -ForegroundColor Green
    }
} else {
    Write-Host "Endpoint IMAP già esistente: lo riuso." -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────────────────────
# 5) CREAZIONE DEL BATCH DI MIGRAZIONE
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Creazione del batch '$BatchName'"
# Il CSV va passato come array di byte (parametro -CSVData).
$csvData = [System.IO.File]::ReadAllBytes((Resolve-Path $CsvPath))

# Parametri comuni del batch, costruiti in modo condizionale.
$batchParams = @{
    Name                 = $BatchName
    SourceEndpoint       = $endpoint.Identity
    CSVData              = $csvData
    TargetDeliveryDomain = $TargetDeliveryDomain
}
if ($NotificationEmails) { $batchParams['NotificationEmails'] = $NotificationEmails }
if ($AutoStart)          { $batchParams['AutoStart'] = $true }

if ($PSCmdlet.ShouldProcess($BatchName, "Crea batch di migrazione IMAP")) {
    New-MigrationBatch @batchParams | Out-Null
    Write-Host "Batch '$BatchName' creato." -ForegroundColor Green
    if (-not $AutoStart) {
        Write-Host "Il batch NON è stato avviato (manca -AutoStart). Avvialo con:" -ForegroundColor Yellow
        Write-Host ("    Start-MigrationBatch -Identity '{0}'" -f $BatchName) -ForegroundColor Yellow
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 6) MONITORAGGIO — comandi utili per seguire l'avanzamento
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Monitoraggio della migrazione"
Write-Host @"
Comandi utili:
  # Stato del batch
  Get-MigrationBatch -Identity '$BatchName' | Format-List Status,*Count*

  # Dettaglio per singola casella (utile per individuare le caselle in errore)
  Get-MigrationUser -BatchId '$BatchName' |
      Get-MigrationUserStatistics | Format-Table Identity,Status,SyncedItemCount,SkippedItemCount

  # Al termine (dopo il cutover MX) — completa e rimuovi il batch:
  #   Complete-MigrationBatch -Identity '$BatchName'
  #   Remove-MigrationBatch   -Identity '$BatchName'

Ricorda: la migrazione IMAP copia SOLO la posta. Contatti e calendari vanno
gestiti separatamente (esportazione .pst da Outlook e import, oppure ricreazione).
"@ -ForegroundColor Gray

Write-Step "Operazione completata."
