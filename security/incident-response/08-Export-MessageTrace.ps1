#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Esporta il tracciamento dei messaggi con Get-MessageTraceV2, spezzando la finestra come impone il cmdlet.
.DESCRIPTION
    Sola lettura. Serve a rispondere alla domanda che segue sempre una compromissione della
    posta: che cosa e' uscito da qui, e verso chi.

    TRE VINCOLI DEL CMDLET, tutti verificati sulla documentazione, tutti in grado di produrre
    un export incompleto che sembra completo:

      - Get-MessageTrace, il cmdlet storico, e' DEPRECATO: la dismissione e' partita il
        1 settembre 2025 e il supporto legacy sul Reporting Webservice si e' chiuso il
        18 marzo 2026. Qui si usa Get-MessageTraceV2, che richiede il modulo
        ExchangeOnlineManagement 3.7.0 o superiore.
      - La cronologia arriva a 90 giorni ma si possono chiedere al MASSIMO 10 GIORNI PER
        QUERY. Lo script spezza da solo la finestra in blocchi.
      - Non esiste paginazione e il tetto e' 5.000 risultati per query. Se un blocco tocca il
        tetto, i messaggi oltre quel numero NON sono nell'export e nessun errore lo segnala.
        Qui il blocco che tocca il tetto viene automaticamente rifatto giorno per giorno, e
        se anche un singolo giorno lo tocca lo script lo dichiara.
.PARAMETER Giorni
    Finestra totale. Default 30, massimo 90.
.PARAMETER GiorniPerBlocco
    Ampiezza di ogni query. Default 10, che e' il massimo consentito.
.PARAMETER Mittente
    Filtra per indirizzo mittente. Utile per isolare la casella compromessa.
.PARAMETER OutputCsv
    Export. Default: .\IR-08-MessageTrace-<data-ora>.csv
.EXAMPLE
    .\08-Export-MessageTrace.ps1 -Giorni 30
.EXAMPLE
    .\08-Export-MessageTrace.ps1 -Giorni 90 -Mittente 'mario.rossi@contoso.com'
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Sola lettura. Richiede ExchangeOnlineManagement 3.7.0+.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 90)][int]$Giorni = 30,
    [ValidateRange(1, 10)][int]$GiorniPerBlocco = 10,
    [string]$Mittente,
    [string]$OutputCsv = (".\IR-08-MessageTrace-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
)

$ErrorActionPreference = 'Stop'

$exo = Get-Module -ListAvailable -Name ExchangeOnlineManagement |
    Sort-Object Version -Descending | Select-Object -First 1
if (-not $exo) {
    throw "Modulo ExchangeOnlineManagement non installato. Install-Module ExchangeOnlineManagement -Scope CurrentUser"
}
if ($exo.Version -lt [version]'3.7.0') {
    throw ("ExchangeOnlineManagement {0}: Get-MessageTraceV2 richiede la 3.7.0 o superiore. Update-Module ExchangeOnlineManagement" -f $exo.Version)
}
if (-not (Get-Command Get-MessageTraceV2 -ErrorAction SilentlyContinue)) {
    try {
        $null = Get-OrganizationConfig -ErrorAction Stop
    } catch {
        Write-Host 'Connessione a Exchange Online...' -ForegroundColor Cyan
        Connect-ExchangeOnline -ShowBanner:$false
    }
}
if (-not (Get-Command Get-MessageTraceV2 -ErrorAction SilentlyContinue)) {
    throw "Get-MessageTraceV2 non disponibile in questa sessione. Verificare la versione del modulo e i permessi."
}

$TETTO = 5000
$fine = (Get-Date).ToUniversalTime()
$inizio = $fine.AddDays(-$Giorni)

Write-Host ''
Write-Host ("Message trace dal {0} al {1} (UTC)" -f $inizio.ToString('yyyy-MM-dd'), $fine.ToString('yyyy-MM-dd')) -ForegroundColor Cyan
Write-Host ("Blocchi da {0} giorni (il cmdlet non accetta finestre piu ampie)." -f $GiorniPerBlocco) -ForegroundColor DarkGray

$tutti = New-Object System.Collections.Generic.List[object]
$blocchiTroncati = New-Object System.Collections.Generic.List[string]

function Get-Blocco {
    param([datetime]$Da, [datetime]$A)
    $p = @{
        StartDate   = $Da
        EndDate     = $A
        ResultSize  = $TETTO
        ErrorAction = 'Stop'
    }
    if ($Mittente) { $p['SenderAddress'] = $Mittente }
    return @(Get-MessageTraceV2 @p)
}

$cursore = $inizio
while ($cursore -lt $fine) {
    $finBlocco = $cursore.AddDays($GiorniPerBlocco)
    if ($finBlocco -gt $fine) { $finBlocco = $fine }

    $etichetta = ("{0} -> {1}" -f $cursore.ToString('yyyy-MM-dd'), $finBlocco.ToString('yyyy-MM-dd'))
    $blocco = Get-Blocco -Da $cursore -A $finBlocco
    Write-Host ("  {0}: {1} messaggi" -f $etichetta, $blocco.Count) -ForegroundColor DarkGray

    if ($blocco.Count -ge $TETTO) {
        # Tetto toccato: l'export sarebbe incompleto in silenzio. Si riprova giorno per giorno.
        Write-Host ("    tetto di {0} raggiunto: riprovo giorno per giorno" -f $TETTO) -ForegroundColor Yellow
        $g = $cursore
        while ($g -lt $finBlocco) {
            $gFine = $g.AddDays(1)
            if ($gFine -gt $finBlocco) { $gFine = $finBlocco }
            $bg = Get-Blocco -Da $g -A $gFine
            if ($bg.Count -gt 0) { $tutti.AddRange($bg) }
            if ($bg.Count -ge $TETTO) {
                $blocchiTroncati.Add($g.ToString('yyyy-MM-dd'))
                Write-Host ("    {0}: {1} messaggi - TRONCATO" -f $g.ToString('yyyy-MM-dd'), $bg.Count) -ForegroundColor Red
            }
            $g = $gFine
        }
    } elseif ($blocco.Count -gt 0) {
        $tutti.AddRange($blocco)
    }

    $cursore = $finBlocco
}

Write-Host ("Messaggi recuperati: {0}" -f $tutti.Count) -ForegroundColor Green

if ($tutti.Count -eq 0) {
    Write-Host 'Nessun messaggio nella finestra richiesta.' -ForegroundColor Yellow
    return
}

$righe = foreach ($m in $tutti) {
    [pscustomobject]@{
        DataOraUtc   = $m.Received
        Mittente     = $m.SenderAddress
        Destinatario = $m.RecipientAddress
        Oggetto      = $m.Subject
        Stato        = $m.Status
        DimensioneKB = [math]::Round(($m.Size / 1KB), 1)
        IPMittente   = $m.FromIP
        IPDestinatario = $m.ToIP
        MessageId    = $m.MessageId
    }
}

$righe = $righe | Sort-Object DataOraUtc
$righe | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Export -> {0}" -f $OutputCsv) -ForegroundColor Cyan

if ($blocchiTroncati.Count -gt 0) {
    Write-Host ''
    Write-Host ("{0} GIORNI SONO STATI TRONCATI al tetto di {1} messaggi:" -f $blocchiTroncati.Count, $TETTO) -ForegroundColor Red
    Write-Host ("  {0}" -f ($blocchiTroncati -join ', ')) -ForegroundColor Red
    Write-Host '  Per quei giorni l export NON e completo. Rilanciare filtrando con -Mittente.' -ForegroundColor Red
}

Write-Host ''
Write-Host 'Mittenti interni piu attivi:' -ForegroundColor Yellow
$righe | Group-Object Mittente | Sort-Object Count -Descending |
    Select-Object -First 15 Count, Name | Format-Table -AutoSize

Write-Host 'Domini di destinazione piu frequenti:' -ForegroundColor Yellow
$righe |
    Where-Object { $_.Destinatario -and $_.Destinatario.Contains('@') } |
    Group-Object { ($_.Destinatario -split '@')[-1] } |
    Sort-Object Count -Descending |
    Select-Object -First 15 Count, Name | Format-Table -AutoSize
