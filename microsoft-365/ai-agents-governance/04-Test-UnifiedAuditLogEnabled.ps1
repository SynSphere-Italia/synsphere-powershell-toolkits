<#
.SYNOPSIS
    Verifica che l'audit log unificato sia attivo, dalla connessione GIUSTA.
.DESCRIPTION
    Va eseguito prima dello script 05: senza audit attivo la ricerca delle
    interazioni Copilot restituisce zero risultati, che e' indistinguibile da
    "nessun agente ha fatto niente".

    IL GOTCHA CHE RENDE UTILE QUESTO SCRIPT. Get-AdminAuditLogConfig esiste in
    due moduli. Eseguito in Security & Compliance PowerShell (Connect-IPPSSession)
    ritorna UnifiedAuditLogIngestionEnabled = False ANCHE QUANDO L'AUDIT E'
    ATTIVO. Uno script che apre la connessione sbagliata conclude che l'audit e'
    spento e produce un report falsamente rassicurante - il tipo di errore che
    non genera nessun messaggio e che nessuno scopre. Questo script si connette
    esplicitamente a Exchange Online e lo dichiara nell'output.

    Sola lettura: non abilita nulla. L'abilitazione e' un'azione con effetti sul
    tenant e va decisa da chi lo amministra.
.PARAMETER Upn
    UPN con cui connettersi a Exchange Online, se non c'e' gia' una sessione.
.EXAMPLE
    .\04-Test-UnifiedAuditLogEnabled.ps1 -Upn admin@contoso.onmicrosoft.com
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Cmdlet verificati su learn.microsoft.com il 19 agosto 2026.
    Le superfici di governance degli agenti AI cambiano ogni mese: prima di un
    uso in produzione esegui 00-Test-Prerequisiti.ps1, che controlla che i
    cmdlet esistano davvero nella versione di modulo installata.
#>
#Requires -Modules ExchangeOnlineManagement
[CmdletBinding()]
param(
    [string]$Upn
)
$ErrorActionPreference = 'Stop'

# Verifica di essere nella connessione giusta. Get-AcceptedDomain esiste solo in
# Exchange Online: se risponde, siamo nel modulo corretto.
$exoAttiva = $null -ne (Get-Command Get-AcceptedDomain -ErrorAction SilentlyContinue)
if (-not $exoAttiva) {
    if (-not $Upn) { throw 'Serve -Upn per connettersi a Exchange Online, oppure apri prima la sessione con Connect-ExchangeOnline.' }
    Write-Host 'Connessione a Exchange Online...' -ForegroundColor Cyan
    Connect-ExchangeOnline -UserPrincipalName $Upn -ShowBanner:$false
}

try {
    $cfg = Get-AdminAuditLogConfig -ErrorAction Stop
}
catch {
    throw ("Get-AdminAuditLogConfig non eseguibile: {0}" -f $_.Exception.Message)
}

$attivo = $cfg.UnifiedAuditLogIngestionEnabled

Write-Host ''
Write-Host ('=' * 74)
Write-Host ' AUDIT LOG UNIFICATO'
Write-Host ('=' * 74)
Write-Host ("  UnifiedAuditLogIngestionEnabled : {0}" -f $attivo) `
    -ForegroundColor $(if ($attivo) { 'Green' } else { 'Red' })
Write-Host ("  Letto da                        : Exchange Online PowerShell")
Write-Host ''

if ($attivo) {
    Write-Host 'Audit attivo: lo script 05 puo cercare le interazioni.' -ForegroundColor Green
}
else {
    Write-Host 'Audit NON attivo.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Prima di concludere, due verifiche:' -ForegroundColor Yellow
    Write-Host '  1. Sei sicuro di essere in Exchange Online e non in Security &'
    Write-Host '     Compliance? Nel secondo modulo questo valore e False anche'
    Write-Host '     quando l audit e attivo. Questo script si connette al primo,'
    Write-Host '     ma se avevi gia una sessione aperta potrebbe essere l altra.'
    Write-Host '  2. Se e davvero spento, l abilitazione si fa con:'
    Write-Host '       Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true'
    Write-Host '     Gli eventi iniziano a comparire dopo un intervallo, non subito:'
    Write-Host '     un audit appena abilitato non recupera il passato.'
}
Write-Host ''
