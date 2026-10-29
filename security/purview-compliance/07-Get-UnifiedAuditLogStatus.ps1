#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Stato del log di controllo unificato: attivo o no, e con quale conservazione.
.DESCRIPTION
    Verifica se l'inserimento nel log di controllo unificato e abilitato sul tenant. E' il
    controllo che viene prima di tutti gli altri: senza quel log non esiste alcuna evidenza
    di chi ha fatto cosa, e nessuna indagine successiva e possibile — nemmeno a posteriori,
    perche gli eventi non registrati non si recuperano. Sola lettura.
    ATTENZIONE AL CONTESTO — questo e il punto critico dello script: la documentazione
    Microsoft dichiara che la proprieta UnifiedAuditLogIngestionEnabled, se letta in
    Security & Compliance PowerShell (Connect-IPPSSession), restituisce SEMPRE False. Non
    da errore: risponde un valore sbagliato. Uno script che la legge nel contesto compliance
    riferirebbe "log disattivato" su un tenant dove il log e regolarmente attivo. Per questo
    lo script si connette a Exchange Online.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-AuditLogStatus-<data>.csv
.EXAMPLE
    .\07-Get-UnifiedAuditLogStatus.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement v3.2.0+, via Connect-ExchangeOnline
    (NON Connect-IPPSSession — vedi l'avvertenza sopra).
    In caso di dubbio sul risultato, esegui lo script in una sessione PowerShell nuova con
    la sola connessione a Exchange Online attiva.
    Le eventuali policy di conservazione del log di controllo dipendono dalla licenza
    (Audit Premium) e vivono nel contesto compliance: lo script le tenta e, se il cmdlet non
    e disponibile nella sessione, lo dichiara invece di dedurne l'assenza.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-AuditLogStatus-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Oggetto, [string]$Nome)
    if ($null -ne $Oggetto -and ($Oggetto.PSObject.Properties.Name -contains $Nome)) {
        return $Oggetto.$Nome
    }
    return ''
}

Write-Host "Questo controllo richiede la connessione a Exchange Online: nel contesto Security & Compliance il valore sarebbe sempre False." -ForegroundColor Cyan

# Connette a Exchange Online solo se non gia connesso
try {
    $cfg = Get-AdminAuditLogConfig -ErrorAction Stop
}
catch {
    Connect-ExchangeOnline
    $cfg = Get-AdminAuditLogConfig
}

$attivo = Get-Prop $cfg 'UnifiedAuditLogIngestionEnabled'

# Le policy di conservazione del log vivono nel contesto compliance e richiedono licenza
# adeguata: le tento senza aprire una nuova connessione, e distinguo "nessuna policy" da
# "cmdlet non disponibile in questa sessione".
$policyRetention = @()
$statoRetention = 'non verificato'
try {
    $policyRetention = @(Get-UnifiedAuditLogRetentionPolicy -ErrorAction Stop)
    $statoRetention = ("{0} policy di conservazione del log trovate" -f $policyRetention.Count)
}
catch {
    $statoRetention = 'cmdlet non disponibile in questa sessione (serve Connect-IPPSSession e licenza Audit Premium)'
}

$report = @(
    [pscustomobject]@{
        Tenant                     = Get-Prop $cfg 'Identity'
        LogControlloUnificatoAttivo = $attivo
        ContestoDiLettura          = 'Exchange Online'
        LogAmministrativoAbilitato = Get-Prop $cfg 'AdminAuditLogEnabled'
        ConservazioneLogAmministrativo = Get-Prop $cfg 'AdminAuditLogAgeLimit'
        PolicyConservazioneLog     = $statoRetention
    }
)

$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

# Dettaglio delle eventuali policy di conservazione, in un file affiancato
if ($policyRetention.Count -gt 0) {
    $dettaglio = foreach ($p in $policyRetention) {
        [pscustomobject]@{
            Nome           = Get-Prop $p 'Name'
            Abilitata      = Get-Prop $p 'Enabled'
            GiorniConservazione = Get-Prop $p 'RetentionDuration'
            Priorita       = Get-Prop $p 'Priority'
            TipiRecord     = ((@(Get-Prop $p 'RecordTypes')) -join '; ')
            Operazioni     = ((@(Get-Prop $p 'Operations')) -join '; ')
        }
    }
    $fileDettaglio = ($OutputCsv -replace '\.csv$', '') + '-RetentionPolicies.csv'
    $dettaglio | Export-Csv -Path $fileDettaglio -NoTypeInformation -Encoding UTF8
    Write-Host ("Dettaglio policy conservazione log -> {0}" -f $fileDettaglio) -ForegroundColor Green
}

Write-Host ""
if ($attivo -eq $true) {
    Write-Host "Log di controllo unificato: ATTIVO" -ForegroundColor Green
}
elseif ($attivo -eq $false) {
    Write-Host "Log di controllo unificato: NON ATTIVO" -ForegroundColor Red
    Write-Host "Gli eventi non registrati non sono recuperabili a posteriori: questa e la prima cosa da correggere." -ForegroundColor Red
}
else {
    Write-Host "Log di controllo unificato: valore non leggibile in questa sessione." -ForegroundColor Yellow
}
Write-Host ("Conservazione log: {0}" -f $statoRetention) -ForegroundColor Cyan
Write-Host ("-> {0}" -f $OutputCsv) -ForegroundColor Green
