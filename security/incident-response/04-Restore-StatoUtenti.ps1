#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Riporta gli account allo stato fotografato dallo script 02. E' l'uscita dal contenimento.
.DESCRIPTION
    Riabilita SOLO gli account che nello snapshot risultavano abilitati. E' la differenza che
    conta: un "riabilita tutti" rimetterebbe in servizio anche gli ex dipendenti, i contractor
    scaduti e le utenze disattivate apposta prima dell'incidente, creando un secondo problema
    di sicurezza mentre si chiude il primo.

    Come lo script 03, e' in SIMULAZIONE per default.

    Il ripristino non e' una operazione da fare in blocco appena finita l'emergenza: si
    riabilita a ondate, dopo aver forzato il cambio password e verificato che le regole di
    posta malevole siano state rimosse (script 09). Per questo esiste -Utenti, che limita il
    ripristino a un elenco preciso.
.PARAMETER SnapshotCsv
    OBBLIGATORIO. Il CSV prodotto da 02-Backup-StatoUtenti.ps1.
.PARAMETER Esegui
    Esegue davvero. Senza, simula soltanto.
.PARAMETER Utenti
    Limita il ripristino agli UPN indicati. Senza, riguarda tutti gli account che nello
    snapshot erano abilitati e che adesso risultano disabilitati.
.PARAMETER OutputCsv
    Registro. Default: .\IR-04-Ripristino-<data-ora>.csv
.EXAMPLE
    .\04-Restore-StatoUtenti.ps1 -SnapshotCsv .\IR-02-StatoUtenti-20260828-1030.csv
    Simulazione: mostra chi verrebbe riabilitato.
.EXAMPLE
    .\04-Restore-StatoUtenti.ps1 -SnapshotCsv .\IR-02-StatoUtenti-20260828-1030.csv -Utenti 'mario.rossi@contoso.com','anna.bianchi@contoso.com' -Esegui
    Prima ondata di rientro, due utenti.
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    OPERAZIONE DI SCRITTURA. Permessi Graph: User.ReadWrite.All
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)][string]$SnapshotCsv,
    [switch]$Esegui,
    [string[]]$Utenti = @(),
    [string]$OutputCsv = (".\IR-04-Ripristino-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SnapshotCsv)) {
    throw ("Snapshot non trovato: {0}" -f $SnapshotCsv)
}
$snapshot = @(Import-Csv -LiteralPath $SnapshotCsv)
if (-not ($snapshot[0].PSObject.Properties.Name -contains 'AccountEnabled')) {
    throw "Lo snapshot non contiene la colonna AccountEnabled: non e il file prodotto dallo script 02."
}

Connect-MgGraph -Scopes 'User.ReadWrite.All' -NoWelcome

# Solo chi era abilitato PRIMA. Gli altri restano disabilitati: erano gia' cosi'.
$daRipristinare = $snapshot | Where-Object { $_.AccountEnabled -eq 'True' }

if ($Utenti.Count -gt 0) {
    $filtro = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
    foreach ($u in $Utenti) { if ($u) { $null = $filtro.Add($u.Trim()) } }
    $daRipristinare = $daRipristinare | Where-Object { $filtro.Contains($_.UserPrincipalName) }
}

$eranoDisabilitati = @($snapshot | Where-Object { $_.AccountEnabled -ne 'True' }).Count

Write-Host ''
Write-Host '================ AMBITO DEL RIPRISTINO ================' -ForegroundColor Yellow
Write-Host ("  Da riabilitare (erano attivi)      : {0}" -f @($daRipristinare).Count) -ForegroundColor Green
Write-Host ("  Restano disabilitati (lo erano gia): {0}" -f $eranoDisabilitati)
Write-Host '======================================================' -ForegroundColor Yellow

if (-not $Esegui) {
    Write-Host ''
    Write-Host 'SIMULAZIONE: nessuna modifica effettuata.' -ForegroundColor Green
    Write-Host 'Rilanciare con -Esegui per riabilitare.' -ForegroundColor Yellow
    $daRipristinare |
        Select-Object UserPrincipalName, DisplayName, UserType, Sincronizzato,
                      @{n = 'Azione'; e = { 'Simulato' } } |
        Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host ("Elenco -> {0}" -f $OutputCsv) -ForegroundColor Cyan
    return
}

$log = New-Object System.Collections.Generic.List[object]
$i = 0
foreach ($u in $daRipristinare) {
    $i++
    if ($i % 25 -eq 0) {
        Write-Progress -Activity 'Ripristino' -Status ("{0}/{1}" -f $i, @($daRipristinare).Count) `
            -PercentComplete (($i / @($daRipristinare).Count) * 100)
    }

    $stato = 'NonEseguito'
    $errore = ''
    # si legge lo stato attuale: se e gia' abilitato non si tocca, per non sporcare l'audit
    $attuale = $null
    try {
        $attuale = Get-MgUser -UserId $u.Id -Property Id, AccountEnabled -ErrorAction Stop
    } catch {
        $stato = 'NonTrovato'
        $errore = $_.Exception.Message
    }

    if ($attuale) {
        if ($attuale.AccountEnabled) {
            $stato = 'GiaAbilitato'
        } elseif ($PSCmdlet.ShouldProcess($u.UserPrincipalName, 'Riabilita account')) {
            try {
                Update-MgUser -UserId $u.Id -AccountEnabled:$true -ErrorAction Stop
                $stato = 'Riabilitato'
            } catch {
                $stato = 'Errore'
                $errore = $_.Exception.Message
            }
        }
    }

    $log.Add([pscustomobject]@{
        UserPrincipalName = $u.UserPrincipalName
        DisplayName       = $u.DisplayName
        Sincronizzato     = $u.Sincronizzato
        Esito             = $stato
        Errore            = $errore
        OraUtc            = (Get-Date).ToUniversalTime().ToString('o')
    })
}
Write-Progress -Activity 'Ripristino' -Completed

$log | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$ok = @($log | Where-Object { $_.Esito -eq 'Riabilitato' }).Count
$gia = @($log | Where-Object { $_.Esito -eq 'GiaAbilitato' }).Count
$ko = @($log | Where-Object { $_.Esito -in @('Errore', 'NonTrovato') }).Count

Write-Host ''
Write-Host ("Riabilitati    : {0}" -f $ok) -ForegroundColor Green
Write-Host ("Gia abilitati  : {0}" -f $gia)
if ($ko -gt 0) { Write-Host ("Errori         : {0}" -f $ko) -ForegroundColor Red }
Write-Host ("Registro -> {0}" -f $OutputCsv) -ForegroundColor Cyan
Write-Host ''
Write-Host 'Prima di allargare il rientro: forzare il cambio password e verificare le regole' -ForegroundColor Yellow
Write-Host 'di posta con 09-Export-RegolePostaEInoltri.ps1. Le regole malevole sopravvivono al blocco.' -ForegroundColor Yellow
