#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    CONTENIMENTO: disabilita gli account e revoca le sessioni attive. Operazione distruttiva.
.DESCRIPTION
    Questo script ferma l'azienda. E' il suo scopo: durante una compromissione attiva, ogni
    minuto in cui l'attaccante mantiene una sessione valida e' altro danno. Va lanciato quando
    la decisione di contenere e' gia' stata presa, non per capire se contenere.

    DUE AZIONI, ed e' la seconda quella che conta davvero:
      1. AccountEnabled = false sugli account in ambito;
      2. revoca delle sessioni (refreshTokensValidFromDateTime). Senza questa, un token di
         aggiornamento gia' emesso resta valido e l'attaccante continua a leggere la posta
         per ore nonostante l'account risulti "bloccato" nel portale.

    IN SIMULAZIONE PER DEFAULT. Senza -Esegui non tocca nulla e produce solo l'elenco di cio'
    che farebbe. Usare la simulazione per rileggere l'ambito PRIMA, sempre.

    TRE ESCLUSIONI:
      - l'account che sta eseguendo lo script: non aggirabile, e la vostra via di rientro;
      - gli account con ruolo Global Administrator: esclusi salvo -IncludiAdmin, perche'
        bloccarli tutti significa perdere il controllo del tenant;
      - gli account elencati in -Escludi: le utenze di emergenza (break-glass) vanno qui.

    ACCOUNT SINCRONIZZATI DA ACTIVE DIRECTORY: il blocco lato cloud viene sovrascritto al
    successivo ciclo di sincronizzazione. Lo script li segnala e li conta a parte: vanno
    disabilitati in AD locale. Bloccarli solo qui da' una falsa sensazione di contenimento.
.PARAMETER SnapshotCsv
    OBBLIGATORIO. Il CSV prodotto da 02-Backup-StatoUtenti.ps1. Senza, lo script si rifiuta
    di partire: un blocco senza fotografia dello stato precedente non e' reversibile.
.PARAMETER Esegui
    Esegue davvero. Senza questo switch lo script simula soltanto.
.PARAMETER Escludi
    UPN da non toccare (break-glass, utenze di servizio critiche). Accetta piu' valori.
.PARAMETER IncludiAdmin
    Include anche gli account con ruolo Global Administrator. Da usare quando l'attaccante
    ha compromesso un'utenza amministrativa, dopo aver verificato di avere un break-glass.
.PARAMETER SoloGuest
    Limita il blocco ai soli account guest.
.PARAMETER NonRevocareSessioni
    Disabilita gli account senza revocare le sessioni. Sconsigliato: vedi sopra.
.PARAMETER OutputCsv
    Registro delle azioni. Default: .\IR-03-Blocco-<data-ora>.csv
.EXAMPLE
    .\03-Invoke-BloccoEmergenza.ps1 -SnapshotCsv .\IR-02-StatoUtenti-20260828-1030.csv
    Simulazione: mostra chi verrebbe bloccato, non tocca nulla.
.EXAMPLE
    .\03-Invoke-BloccoEmergenza.ps1 -SnapshotCsv .\IR-02-StatoUtenti-20260828-1030.csv -Escludi 'breakglass@contoso.com' -Esegui
    Esecuzione reale.
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    OPERAZIONE DI SCRITTURA. Permessi Graph: User.ReadWrite.All, Directory.ReadWrite.All
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)][string]$SnapshotCsv,
    [switch]$Esegui,
    [string[]]$Escludi = @(),
    [switch]$IncludiAdmin,
    [switch]$SoloGuest,
    [switch]$NonRevocareSessioni,
    [string]$OutputCsv = (".\IR-03-Blocco-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
)

$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------------------------
# Guardia 1: lo snapshot deve esistere ed essere leggibile
# ----------------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $SnapshotCsv)) {
    throw ("Snapshot non trovato: {0}. Eseguire prima 02-Backup-StatoUtenti.ps1." -f $SnapshotCsv)
}
$snapshot = @(Import-Csv -LiteralPath $SnapshotCsv)
if ($snapshot.Count -eq 0) { throw "Lo snapshot e vuoto: non e utilizzabile per il ripristino." }
if (-not ($snapshot[0].PSObject.Properties.Name -contains 'AccountEnabled')) {
    throw "Lo snapshot non contiene la colonna AccountEnabled: non e il file prodotto dallo script 02."
}
Write-Host ("Snapshot caricato: {0} account." -f $snapshot.Count) -ForegroundColor Green

Connect-MgGraph -Scopes 'User.ReadWrite.All', 'Directory.ReadWrite.All' -NoWelcome
$ctx = Get-MgContext
$operatore = $ctx.Account

# ----------------------------------------------------------------------------------
# Guardia 2: l'operatore non si blocca mai da solo
# ----------------------------------------------------------------------------------
$esclusiSet = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
foreach ($e in $Escludi) { if ($e) { $null = $esclusiSet.Add($e.Trim()) } }
if ($operatore) { $null = $esclusiSet.Add($operatore) }

# ----------------------------------------------------------------------------------
# Ambito
# ----------------------------------------------------------------------------------
$candidati = $snapshot | Where-Object { $_.AccountEnabled -eq 'True' }
if ($SoloGuest) { $candidati = $candidati | Where-Object { $_.UserType -eq 'Guest' } }

$inAmbito = New-Object System.Collections.Generic.List[object]
$saltati  = New-Object System.Collections.Generic.List[object]

foreach ($u in $candidati) {
    $motivo = $null
    if ($esclusiSet.Contains($u.UserPrincipalName)) {
        $motivo = 'escluso esplicitamente'
        if ($u.UserPrincipalName -eq $operatore) { $motivo = 'account operatore (non aggirabile)' }
    } elseif ((-not $IncludiAdmin) -and $u.RuoliAdmin -and ($u.RuoliAdmin -match 'Global Administrator|Amministratore globale')) {
        $motivo = 'Global Administrator (usare -IncludiAdmin per includerlo)'
    }
    if ($motivo) {
        $saltati.Add([pscustomobject]@{ UserPrincipalName = $u.UserPrincipalName; Motivo = $motivo })
    } else {
        $inAmbito.Add($u)
    }
}

$sincronizzati = @($inAmbito | Where-Object { $_.Sincronizzato -eq 'Si' })

# ----------------------------------------------------------------------------------
# Riepilogo prima di agire
# ----------------------------------------------------------------------------------
Write-Host ''
Write-Host '================= AMBITO DEL BLOCCO =================' -ForegroundColor Yellow
Write-Host ("  Account che verranno BLOCCATI : {0}" -f $inAmbito.Count) -ForegroundColor Red
Write-Host ("  Account esclusi               : {0}" -f $saltati.Count)
Write-Host ("  Revoca sessioni               : {0}" -f $(if ($NonRevocareSessioni) { 'NO' } else { 'SI' }))
Write-Host ("  Operatore protetto            : {0}" -f $operatore) -ForegroundColor Green
Write-Host '====================================================' -ForegroundColor Yellow
if ($saltati.Count -gt 0) {
    Write-Host ''
    Write-Host 'Esclusi:' -ForegroundColor Cyan
    $saltati | Format-Table UserPrincipalName, Motivo -AutoSize
}
if ($sincronizzati.Count -gt 0) {
    Write-Host ''
    Write-Host ("ATTENZIONE: {0} degli account in ambito sono SINCRONIZZATI da AD locale." -f $sincronizzati.Count) -ForegroundColor Red
    Write-Host '  Il blocco lato cloud verra sovrascritto al prossimo ciclo di sincronizzazione.' -ForegroundColor Red
    Write-Host '  Vanno disabilitati anche in Active Directory. Elenco nella colonna Sincronizzato del CSV.' -ForegroundColor Red
}

if (-not $Esegui) {
    Write-Host ''
    Write-Host 'SIMULAZIONE: nessuna modifica effettuata.' -ForegroundColor Green
    Write-Host 'Rilanciare con -Esegui per applicare il blocco.' -ForegroundColor Yellow
    $inAmbito |
        Select-Object UserPrincipalName, DisplayName, UserType, Sincronizzato, RuoliAdmin,
                      @{n = 'Azione'; e = { 'Simulato' } } |
        Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host ("Elenco -> {0}" -f $OutputCsv) -ForegroundColor Cyan
    return
}

if ($inAmbito.Count -eq 0) {
    Write-Host 'Nessun account in ambito: niente da fare.' -ForegroundColor Green
    return
}

# ----------------------------------------------------------------------------------
# Esecuzione
# ----------------------------------------------------------------------------------
Write-Host ''
Write-Host ("ESECUZIONE su {0} account..." -f $inAmbito.Count) -ForegroundColor Red

$log = New-Object System.Collections.Generic.List[object]
$i = 0
foreach ($u in $inAmbito) {
    $i++
    if ($i % 25 -eq 0) {
        Write-Progress -Activity 'Blocco di emergenza' -Status ("{0}/{1}" -f $i, $inAmbito.Count) `
            -PercentComplete (($i / $inAmbito.Count) * 100)
    }

    $statoBlocco = 'NonEseguito'
    $statoRevoca = 'NonEseguito'
    $errore = ''

    if ($PSCmdlet.ShouldProcess($u.UserPrincipalName, 'Disabilita account e revoca sessioni')) {
        try {
            Update-MgUser -UserId $u.Id -AccountEnabled:$false -ErrorAction Stop
            $statoBlocco = 'Bloccato'
        } catch {
            $statoBlocco = 'Errore'
            $errore = $_.Exception.Message
        }

        if (-not $NonRevocareSessioni) {
            try {
                $null = Revoke-MgUserSignInSession -UserId $u.Id -ErrorAction Stop
                $statoRevoca = 'Revocate'
            } catch {
                $statoRevoca = 'Errore'
                if (-not $errore) { $errore = $_.Exception.Message }
            }
        } else {
            $statoRevoca = 'Saltata'
        }
    }

    $log.Add([pscustomobject]@{
        UserPrincipalName = $u.UserPrincipalName
        DisplayName       = $u.DisplayName
        UserType          = $u.UserType
        Sincronizzato     = $u.Sincronizzato
        RuoliAdmin        = $u.RuoliAdmin
        Blocco            = $statoBlocco
        RevocaSessioni    = $statoRevoca
        Errore            = $errore
        OraUtc            = (Get-Date).ToUniversalTime().ToString('o')
    })
}
Write-Progress -Activity 'Blocco di emergenza' -Completed

foreach ($s in $saltati) {
    $log.Add([pscustomobject]@{
        UserPrincipalName = $s.UserPrincipalName
        DisplayName       = ''
        UserType          = ''
        Sincronizzato     = ''
        RuoliAdmin        = ''
        Blocco            = 'Escluso'
        RevocaSessioni    = 'Escluso'
        Errore            = $s.Motivo
        OraUtc            = (Get-Date).ToUniversalTime().ToString('o')
    })
}

$log | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$bloccati = @($log | Where-Object { $_.Blocco -eq 'Bloccato' }).Count
$errori   = @($log | Where-Object { $_.Blocco -eq 'Errore' }).Count
$revocate = @($log | Where-Object { $_.RevocaSessioni -eq 'Revocate' }).Count

Write-Host ''
Write-Host ("Bloccati        : {0}" -f $bloccati) -ForegroundColor Green
Write-Host ("Sessioni revocate: {0}" -f $revocate) -ForegroundColor Green
if ($errori -gt 0) { Write-Host ("Errori          : {0} (colonna Errore del CSV)" -f $errori) -ForegroundColor Red }
Write-Host ("Registro -> {0}" -f $OutputCsv) -ForegroundColor Cyan
Write-Host ''
Write-Host 'Il ripristino si fa con 04-Restore-StatoUtenti.ps1 passando lo SNAPSHOT dello script 02.' -ForegroundColor Yellow
if ($sincronizzati.Count -gt 0) {
    Write-Host ("Ricordate i {0} account sincronizzati: vanno disabilitati in AD locale." -f $sincronizzati.Count) -ForegroundColor Red
}
