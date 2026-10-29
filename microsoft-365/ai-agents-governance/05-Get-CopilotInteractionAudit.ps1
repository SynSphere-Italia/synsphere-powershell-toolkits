<#
.SYNOPSIS
    Estrae dall'audit log le interazioni con Copilot e con gli agenti AI.
.DESCRIPTION
    Cerca nell'audit log unificato gli eventi delle interazioni Copilot e delle
    invocazioni di agenti, e li esporta per l'analisi offline. E' la sola via
    PowerShell per sapere che gli agenti hanno effettivamente fatto qualcosa.

    TRE LIMITI CHE VANNO DETTI AL CLIENTE, non scoperti dopo:
    1. Search-UnifiedAuditLog restituisce 100 record di default, 5.000 con
       -ResultSize, fino a 50.000 con ReturnLargeSet - e in ordine CASUALE. Oltre
       serve segmentare la finestra temporale. Mischiare i due SessionCommand
       sullo stesso SessionId taglia a 10.000.
    2. Non si puo' filtrare lato server per identita' dell'app: si esporta e si
       filtra offline. Questo script lo fa nel post-processing.
    3. Latenza tipica 60-90 minuti, senza garanzia: un'interazione di dieci
       minuti fa non c'e' ancora, e la sua assenza non significa nulla.
    E un limite di merito: Microsoft avverte che l'audit log NON e' inteso come
    base per il reporting di adozione, e le aggregate possono non coincidere con
    i report ufficiali. Un KPI di adozione costruito su questi dati non e'
    difendibile - va usato per la sicurezza e la tracciabilita', non per le
    percentuali da presentare.

    Sola lettura.
.PARAMETER GiorniIndietro
    Finestra da interrogare. Default 7. La retention e' 180 giorni.
.PARAMETER FiltraApp
    Filtra offline sull'identita' dell'app o dell'agente (match parziale).
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\AI-CopilotInteractions-<data>.csv
.EXAMPLE
    .\05-Get-CopilotInteractionAudit.ps1 -GiorniIndietro 30
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
    [int]$GiorniIndietro = 7,
    [string]$FiltraApp,
    [string]$OutputCsv = (".\AI-CopilotInteractions-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-Command Search-UnifiedAuditLog -ErrorAction SilentlyContinue)) {
    throw 'Search-UnifiedAuditLog non disponibile: apri una sessione con Connect-ExchangeOnline.'
}

$da = (Get-Date).AddDays(-$GiorniIndietro)
$a  = Get-Date

# Record type verificati sulla pagina Microsoft delle attivita di audit.
# AIAppInteraction riguarda app AI NON Microsoft e richiede l'abilitazione
# pay-as-you-go: se il tenant non l'ha, quella ricerca torna vuota e non e' un
# errore.
$RecordTypes = @('CopilotInteraction', 'ConnectedAIAppInteraction',
                 'AIAppInteraction', 'TeamCopilotInteraction')
# Operazioni tipiche degli agenti.
$Operazioni  = @('AIInvokeAgent', 'AIExecuteTool', 'AIInferenceCall', 'AIGuardrail')

$tutti = @()

foreach ($rt in $RecordTypes) {
    Write-Host ("RecordType {0}..." -f $rt) -ForegroundColor Cyan
    $sessione = "SynSphere-$rt-" + (Get-Date -Format 'HHmmss')
    $pagina = 0
    do {
        $pagina++
        try {
            $res = Search-UnifiedAuditLog -StartDate $da -EndDate $a -RecordType $rt `
                       -SessionId $sessione -SessionCommand ReturnLargeSet `
                       -ResultSize 5000 -ErrorAction Stop
        }
        catch {
            Write-Warning ("  {0}: {1}" -f $rt, $_.Exception.Message)
            break
        }
        if ($res) {
            $tutti += $res
            Write-Host ("  pagina {0}: {1} record (totale {2})" -f $pagina, $res.Count, $tutti.Count)
        }
    } while ($res -and $res.Count -gt 0 -and $pagina -lt 20)
}

Write-Host 'Operazioni specifiche degli agenti...' -ForegroundColor Cyan
foreach ($op in $Operazioni) {
    try {
        $res = Search-UnifiedAuditLog -StartDate $da -EndDate $a -Operations $op `
                   -ResultSize 5000 -ErrorAction Stop
        if ($res) {
            $tutti += $res
            Write-Host ("  {0,-18} {1} record" -f $op, $res.Count) -ForegroundColor Green
        }
        else {
            Write-Host ("  {0,-18} nessun record" -f $op)
        }
    }
    catch { Write-Warning ("  {0}: {1}" -f $op, $_.Exception.Message) }
}

# Post-processing: appiattisce AuditData (JSON) nelle colonne che servono, e
# applica il filtro sull'app - che lato server non e' possibile.
$righe = @()
foreach ($r in $tutti) {
    $d = $null
    try { $d = $r.AuditData | ConvertFrom-Json } catch { }
    $app = ''
    foreach ($k in @('AppIdentity', 'CopilotEventData', 'ApplicationId')) {
        if ($d -and ($d.PSObject.Properties.Name -contains $k)) {
            $app = [string]$d.$k
            if ($app) { break }
        }
    }
    if ($FiltraApp -and $app -notlike "*$FiltraApp*") { continue }

    $righe += [pscustomobject]@{
        Quando      = $r.CreationDate
        RecordType  = $r.RecordType
        Operazione  = $r.Operations
        Utente      = $r.UserIds
        AppIdentity = $app
        Workload    = if ($d) { $d.Workload } else { '' }
        ThreadId    = if ($d -and ($d.PSObject.Properties.Name -contains 'CopilotEventData')) { $d.CopilotEventData.ThreadId } else { '' }
        Dettaglio   = if ($r.AuditData.Length -gt 1500) { $r.AuditData.Substring(0, 1500) + '...' } else { $r.AuditData }
    }
}

$righe | Sort-Object Quando -Descending |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host ("Esportato: {0}  ({1} eventi su {2} record grezzi)" -f $OutputCsv, $righe.Count, $tutti.Count) -ForegroundColor Green
Write-Host ("Finestra: {0:yyyy-MM-dd HH:mm} - {1:yyyy-MM-dd HH:mm}   Rilevato il {1:yyyy-MM-dd HH:mm}" -f $da, $a) -ForegroundColor Cyan
Write-Host ''
Write-Host 'DA RICORDARE quando presenti questi numeri:' -ForegroundColor Yellow
Write-Host '  - latenza 60-90 minuti: le ultime ore sono incomplete per costruzione'
Write-Host '  - il contenuto di prompt e risposte NON e qui: l audit porta solo'
Write-Host '    il thread id. Il testo vive negli strumenti di data security.'
Write-Host '  - non usare queste aggregate come KPI di adozione: Microsoft'
Write-Host '    dichiara che l audit non e inteso per quello.'
