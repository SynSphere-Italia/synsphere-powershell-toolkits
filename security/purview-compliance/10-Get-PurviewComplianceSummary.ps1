#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Cruscotto di conformita Purview: i buchi delle quattro aree in una schermata.
.DESCRIPTION
    Mette in fila lo stato delle quattro aree coperte dal toolkit: conservazione (quante
    policy agiscono davvero), classificazione (quante etichette sono pubblicate), prevenzione
    perdita dati (quante policy sono in produzione contro quante in simulazione) e
    tracciabilita (se il log di controllo e attivo). Ogni sezione e indipendente: se una non
    e leggibile — permessi mancanti, licenza assente, contesto non connesso — lo dichiara e
    le altre proseguono. Sola lettura.
    NOTA SUI CONTESTI: le prime tre aree richiedono Connect-IPPSSession, il log di controllo
    richiede Connect-ExchangeOnline. Lo script NON apre connessioni da solo per evitare di
    forzare accessi non richiesti: se una sezione risulta non disponibile, connetti il
    contesto indicato e rilancia.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-PurviewSummary-<data>.csv
.EXAMPLE
    Connect-IPPSSession
    Connect-ExchangeOnline
    .\10-Get-PurviewComplianceSummary.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement v3.2.0+.
    Il valore del log di controllo e attendibile solo se letto da Exchange Online: in
    Security & Compliance PowerShell la documentazione Microsoft dichiara che restituisce
    sempre False.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-PurviewSummary-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Continue'

function Get-Prop {
    param($Oggetto, [string]$Nome)
    if ($null -ne $Oggetto -and ($Oggetto.PSObject.Properties.Name -contains $Nome)) {
        return $Oggetto.$Nome
    }
    return ''
}

$righe = @()
function Add-Riga {
    param([string]$Area, [string]$Indicatore, $Valore, [string]$Nota = '')
    $script:righe += [pscustomobject]@{
        Area       = $Area
        Indicatore = $Indicatore
        Valore     = $Valore
        Nota       = $Nota
    }
}

Write-Host ""
Write-Host "=== Cruscotto conformita Microsoft Purview ===" -ForegroundColor Cyan
Write-Host ""

# --- 1. Conservazione -------------------------------------------------------
Write-Host "Conservazione" -ForegroundColor Cyan
try {
    $rp = @(Get-RetentionCompliancePolicy -DistributionDetail -ErrorAction Stop)
    $attive = @($rp | Where-Object { (Get-Prop $_ 'Mode') -eq 'Enforce' -and (Get-Prop $_ 'Enabled') -eq $true })
    Add-Riga 'Conservazione' 'Policy totali' $rp.Count
    Add-Riga 'Conservazione' 'Policy in Enforce e abilitate' $attive.Count 'Le altre non stanno conservando'
    Write-Host ("  policy totali: {0} — in Enforce e abilitate: {1}" -f $rp.Count, $attive.Count)
    if ($rp.Count -gt 0 -and $attive.Count -eq 0) {
        Write-Host "  ATTENZIONE: nessuna policy sta conservando." -ForegroundColor Red
    }
}
catch {
    Add-Riga 'Conservazione' 'Stato lettura' 'non disponibile' 'Serve Connect-IPPSSession e permessi Purview'
    Write-Host "  non disponibile (serve Connect-IPPSSession)" -ForegroundColor Yellow
}

# --- 2. Classificazione ----------------------------------------------------
Write-Host "Classificazione" -ForegroundColor Cyan
try {
    $lab = @(Get-Label -ErrorAction Stop)
    $pol = @()
    try { $pol = @(Get-LabelPolicy) } catch { $pol = @() }

    $pubblicate = @{}
    foreach ($p in $pol) {
        foreach ($l in @(Get-Prop $p 'Labels')) {
            $c = [string]$l
            if (-not [string]::IsNullOrWhiteSpace($c)) { $pubblicate[$c] = $true }
        }
    }
    $nonPub = 0
    foreach ($e in $lab) {
        $n = [string](Get-Prop $e 'Name')
        $g = [string](Get-Prop $e 'Guid')
        if (-not ($pubblicate.ContainsKey($n) -or ($g -and $pubblicate.ContainsKey($g)))) { $nonPub++ }
    }
    Add-Riga 'Classificazione' 'Etichette di riservatezza' $lab.Count
    Add-Riga 'Classificazione' 'Policy di pubblicazione' $pol.Count
    Add-Riga 'Classificazione' 'Etichette NON pubblicate' $nonPub 'Non arrivano agli utenti e non proteggono'
    Write-Host ("  etichette: {0} — policy di pubblicazione: {1} — non pubblicate: {2}" -f $lab.Count, $pol.Count, $nonPub)
    if ($nonPub -gt 0) { Write-Host ("  {0} etichette non sono pubblicate." -f $nonPub) -ForegroundColor Yellow }
}
catch {
    Add-Riga 'Classificazione' 'Stato lettura' 'non disponibile' 'Serve Connect-IPPSSession e permessi Purview'
    Write-Host "  non disponibile (serve Connect-IPPSSession)" -ForegroundColor Yellow
}

# --- 3. Prevenzione perdita dati -------------------------------------------
Write-Host "Prevenzione perdita dati (DLP)" -ForegroundColor Cyan
try {
    $dlp = @(Get-DlpCompliancePolicy -ErrorAction Stop)
    $inTest = @($dlp | Where-Object { [string](Get-Prop $_ 'Mode') -like 'Test*' })
    $spente = @($dlp | Where-Object { (Get-Prop $_ 'Enabled') -eq $false })
    $inProd = @($dlp | Where-Object {
        ([string](Get-Prop $_ 'Mode') -notlike 'Test*') -and
        ([string](Get-Prop $_ 'Mode') -notlike 'Disable*') -and
        ((Get-Prop $_ 'Enabled') -ne $false)
    })
    Add-Riga 'DLP' 'Policy totali' $dlp.Count
    Add-Riga 'DLP' 'Policy in produzione' $inProd.Count
    Add-Riga 'DLP' 'Policy in simulazione' $inTest.Count 'Registrano ma non bloccano'
    Add-Riga 'DLP' 'Policy disabilitate' $spente.Count
    Write-Host ("  totali: {0} — in produzione: {1} — in simulazione: {2} — disabilitate: {3}" -f $dlp.Count, $inProd.Count, $inTest.Count, $spente.Count)
    if ($dlp.Count -gt 0 -and $inProd.Count -eq 0) {
        Write-Host "  ATTENZIONE: nessuna policy DLP blocca contenuti." -ForegroundColor Red
    }
}
catch {
    Add-Riga 'DLP' 'Stato lettura' 'non disponibile' 'Serve Connect-IPPSSession e permessi Purview'
    Write-Host "  non disponibile (serve Connect-IPPSSession)" -ForegroundColor Yellow
}

# --- 4. Tracciabilita ------------------------------------------------------
Write-Host "Tracciabilita" -ForegroundColor Cyan
try {
    $cfg = Get-AdminAuditLogConfig -ErrorAction Stop
    $attivo = Get-Prop $cfg 'UnifiedAuditLogIngestionEnabled'
    Add-Riga 'Tracciabilita' 'Log di controllo unificato attivo' $attivo 'Attendibile solo da Exchange Online'
    if ($attivo -eq $true) {
        Write-Host "  log di controllo unificato: ATTIVO" -ForegroundColor Green
    }
    else {
        Write-Host "  log di controllo unificato: NON ATTIVO (o letto dal contesto sbagliato)" -ForegroundColor Red
        Write-Host "  verifica con 07-Get-UnifiedAuditLogStatus.ps1 da una sessione Exchange Online." -ForegroundColor Yellow
    }
}
catch {
    Add-Riga 'Tracciabilita' 'Stato lettura' 'non disponibile' 'Serve Connect-ExchangeOnline'
    Write-Host "  non disponibile (serve Connect-ExchangeOnline)" -ForegroundColor Yellow
}

$righe | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ""
Write-Host ("-> {0}" -f $OutputCsv) -ForegroundColor Green
