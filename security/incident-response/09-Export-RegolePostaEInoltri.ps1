#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Censisce regole della posta in arrivo e inoltri: la persistenza che sopravvive al blocco.
.DESCRIPTION
    Sola lettura.

    Bloccare gli utenti e revocare le sessioni ferma l'accesso. NON tocca cio' che
    l'attaccante ha lasciato dentro le cassette. Una regola che sposta in "Elementi eliminati"
    tutte le mail contenenti "fattura" o "bonifico", o un inoltro verso un dominio esterno,
    continua a funzionare da sola: e' il meccanismo classico della frode del bonifico, e
    resta attivo quando l'utente rientra.

    Cerca quattro cose, in ordine di gravita':
      1. inoltro a livello di CASSETTA (ForwardingSmtpAddress / ForwardingAddress): e' quello
         che l'utente non vede in Outlook, perche' non e' una sua regola;
      2. regole della posta in arrivo che INOLTRANO o REINDIRIZZANO fuori dal tenant;
      3. regole che CANCELLANO o nascondono (spostano in Posta eliminata, segnano come letto):
         servono a impedire alla vittima di accorgersi delle risposte;
      4. regole con nomi sospetti (una lettera, un punto, vuoti): tipiche di chi non vuole
         essere notato in una lista.

    NOTA SUI TEMPI: Get-InboxRule interroga una cassetta per volta. Su un tenant di qualche
    centinaio di caselle sono diversi minuti. In emergenza si parte da -Utenti con le caselle
    sospette e si lancia la scansione totale in parallelo, su un'altra finestra.
.PARAMETER Utenti
    Limita l'analisi agli UPN indicati. Senza, esamina tutte le cassette utente.
.PARAMETER DominiInterni
    Domini considerati interni. Senza, li ricava dai domini accettati del tenant.
.PARAMETER OutputCsv
    Export delle regole. Default: .\IR-09-RegolePosta-<data-ora>.csv
.EXAMPLE
    .\09-Export-RegolePostaEInoltri.ps1
.EXAMPLE
    .\09-Export-RegolePostaEInoltri.ps1 -Utenti 'mario.rossi@contoso.com'
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Sola lettura. Ruolo: View-Only Organization Management.
#>
[CmdletBinding()]
param(
    [string[]]$Utenti = @(),
    [string[]]$DominiInterni = @(),
    [string]$OutputCsv = (".\IR-09-RegolePosta-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
)

$ErrorActionPreference = 'Stop'

try {
    $null = Get-OrganizationConfig -ErrorAction Stop
} catch {
    Write-Host 'Connessione a Exchange Online...' -ForegroundColor Cyan
    Connect-ExchangeOnline -ShowBanner:$false
}

if ($DominiInterni.Count -eq 0) {
    $DominiInterni = @(Get-AcceptedDomain | Select-Object -ExpandProperty DomainName)
}
$dominiSet = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
foreach ($d in $DominiInterni) { if ($d) { $null = $dominiSet.Add(([string]$d).Trim()) } }
Write-Host ("Domini interni: {0}" -f (($dominiSet) -join ', ')) -ForegroundColor DarkGray

function Test-Esterno {
    param([string]$Indirizzo)
    if (-not $Indirizzo) { return $false }
    if (-not $Indirizzo.Contains('@')) { return $false }
    $dom = ($Indirizzo -split '@')[-1].Trim().TrimEnd('>')
    return (-not $dominiSet.Contains($dom))
}

# -ResultSize Unlimited: il default di TUTTI i Get-* di Exchange Online e 1000.
# Su un tenant piu grande le cassette oltre la millesima sarebbero semplicemente assenti.
Write-Host 'Lettura delle cassette...' -ForegroundColor Cyan
if ($Utenti.Count -gt 0) {
    $cassette = foreach ($u in $Utenti) {
        try { Get-EXOMailbox -Identity $u -Properties ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward -ErrorAction Stop }
        catch { Write-Warning ("Cassetta non trovata: {0}" -f $u) }
    }
} else {
    $cassette = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox `
        -Properties ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward
}
$cassette = @($cassette)
Write-Host ("Cassette da esaminare: {0}" -f $cassette.Count) -ForegroundColor Green

# ----------------------------------------------------------------------------------
# 1. Inoltro a livello di cassetta
# ----------------------------------------------------------------------------------
$inoltri = foreach ($m in $cassette) {
    if ($m.ForwardingSmtpAddress -or $m.ForwardingAddress) {
        $dest = $m.ForwardingSmtpAddress
        if (-not $dest) { $dest = $m.ForwardingAddress }
        $dest = ([string]$dest) -replace '^smtp:', ''
        [pscustomobject]@{
            UserPrincipalName = $m.UserPrincipalName
            Destinazione      = $dest
            Esterno           = (Test-Esterno $dest)
            CopiaInCassetta   = $m.DeliverToMailboxAndForward
        }
    }
}
$inoltri = @($inoltri)

# ----------------------------------------------------------------------------------
# 2-4. Regole della posta in arrivo
# ----------------------------------------------------------------------------------
$regole = New-Object System.Collections.Generic.List[object]
$i = 0
foreach ($m in $cassette) {
    $i++
    if ($i % 20 -eq 0) {
        Write-Progress -Activity 'Lettura regole' -Status ("{0}/{1}" -f $i, $cassette.Count) `
            -PercentComplete (($i / $cassette.Count) * 100)
    }
    $r = @()
    try {
        $r = @(Get-InboxRule -Mailbox $m.UserPrincipalName -ErrorAction Stop)
    } catch {
        continue
    }
    foreach ($x in $r) {
        $destinazioni = New-Object System.Collections.Generic.List[string]
        foreach ($campo in @($x.ForwardTo, $x.ForwardAsAttachmentTo, $x.RedirectTo)) {
            foreach ($v in @($campo)) { if ($v) { $destinazioni.Add([string]$v) } }
        }
        $esterna = $false
        foreach ($d in $destinazioni) {
            # il valore puo essere "Nome [SMTP:indirizzo@dominio]"
            $estratto = $d
            if ($d -match '\[?SMTP:([^\]\s]+)\]?') { $estratto = $Matches[1] }
            if (Test-Esterno $estratto) { $esterna = $true }
        }

        $nascondi = ($x.DeleteMessage -eq $true) -or
                    ($x.MarkAsRead -eq $true) -or
                    ($x.MoveToFolder -and (([string]$x.MoveToFolder) -match 'Deleted|Eliminat|Junk|Posta indesiderata|RSS'))

        $nome = [string]$x.Name
        $nomeSospetto = ($nome.Trim().Length -le 2)

        $gravita = 'Informativa'
        if ($esterna) { $gravita = 'ALTA' }
        elseif ($nascondi) { $gravita = 'Media' }
        elseif ($nomeSospetto) { $gravita = 'Media' }

        $regole.Add([pscustomobject]@{
            UserPrincipalName = $m.UserPrincipalName
            NomeRegola        = $nome
            Abilitata         = $x.Enabled
            InoltroEsterno    = $esterna
            Destinazioni      = ($destinazioni -join '; ')
            CancellaONasconde = $nascondi
            SpostaInCartella  = [string]$x.MoveToFolder
            NomeSospetto      = $nomeSospetto
            Gravita           = $gravita
            # parentesi obbligatorie: dentro una hashtable la virgola di -replace
            # verrebbe letta come separatore di voce e il file non compila
            Descrizione       = (([string]$x.Description) -replace '\s+', ' ')
        })
    }
}
Write-Progress -Activity 'Lettura regole' -Completed

$regole | Sort-Object Gravita, UserPrincipalName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$csvInoltri = $OutputCsv -replace '\.csv$', '-INOLTRI-CASSETTA.csv'
if ($inoltri.Count -gt 0) {
    $inoltri | Export-Csv -Path $csvInoltri -NoTypeInformation -Encoding UTF8
}

# ----------------------------------------------------------------------------------
# Esito
# ----------------------------------------------------------------------------------
$alta = @($regole | Where-Object { $_.Gravita -eq 'ALTA' })
$media = @($regole | Where-Object { $_.Gravita -eq 'Media' })
$inoltriEsterni = @($inoltri | Where-Object { $_.Esterno })

Write-Host ''
Write-Host ("Regole esaminate: {0} su {1} cassette" -f $regole.Count, $cassette.Count) -ForegroundColor Green
Write-Host ("Export -> {0}" -f $OutputCsv) -ForegroundColor Cyan
Write-Host ''

if ($inoltriEsterni.Count -gt 0) {
    Write-Host ("INOLTRO DI CASSETTA VERSO L ESTERNO: {0} caselle" -f $inoltriEsterni.Count) -ForegroundColor Red
    $inoltriEsterni | Format-Table UserPrincipalName, Destinazione, CopiaInCassetta -AutoSize
    Write-Host ("  dettaglio -> {0}" -f $csvInoltri) -ForegroundColor Cyan
    Write-Host ''
}

if ($alta.Count -gt 0) {
    Write-Host ("REGOLE CHE INOLTRANO FUORI DAL TENANT: {0}" -f $alta.Count) -ForegroundColor Red
    $alta | Select-Object -First 20 UserPrincipalName, NomeRegola, Abilitata, Destinazioni |
        Format-Table -AutoSize
    Write-Host ''
}

if ($media.Count -gt 0) {
    Write-Host ("Regole che cancellano/nascondono o con nome anomalo: {0}" -f $media.Count) -ForegroundColor Yellow
}

if ($alta.Count -eq 0 -and $inoltriEsterni.Count -eq 0) {
    Write-Host 'Nessun inoltro esterno trovato.' -ForegroundColor Green
    Write-Host 'Questo esclude UNA forma di persistenza, non tutte: restano i consensi' -ForegroundColor DarkGray
    Write-Host 'applicativi (script 06) e le credenziali aggiunte alle app registrate.' -ForegroundColor DarkGray
}
