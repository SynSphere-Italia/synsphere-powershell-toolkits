<#
.SYNOPSIS
    Costruisce un report HTML unico a partire dai CSV prodotti dagli script precedenti.
.DESCRIPTION
    Non interroga il tenant: legge i CSV gia' presenti nella cartella e li mette insieme.
    Puo' quindi girare su un'altra macchina, a incidente chiuso, o essere allegato alla
    comunicazione al cliente.

    UNA REGOLA CHE VALE PER TUTTO IL REPORT: una fonte ASSENTE e una fonte VUOTA non sono
    la stessa cosa e non vengono mai mostrate allo stesso modo. "Nessun accesso sospetto"
    quando i sign-in log non sono stati raccolti sarebbe la conclusione piu' pericolosa che
    questo strumento possa produrre. Dove la fonte manca, il report scrive che manca.

    Il report NON dice se c'e' stata una compromissione: raccoglie in una pagina i numeri su
    cui una persona decide. La lettura resta umana.
.PARAMETER Cartella
    Cartella dei CSV. Default: la cartella corrente.
.PARAMETER Cliente
    Nome da stampare in intestazione.
.PARAMETER OutputHtml
    File di destinazione. Default: .\IR-Report-<data-ora>.html
.EXAMPLE
    .\10-New-ReportIncidente.ps1 -Cliente 'Contoso Srl'
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Non richiede connessione al tenant.
#>
[CmdletBinding()]
param(
    [string]$Cartella = '.',
    [string]$Cliente = '',
    [string]$OutputHtml = (".\IR-Report-{0}.html" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
)

$ErrorActionPreference = 'Stop'

function Get-CsvPiuRecente {
    param([string]$Pattern)
    $f = Get-ChildItem -Path $Cartella -Filter $Pattern -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $f) { return $null }
    return [pscustomobject]@{
        Percorso = $f.FullName
        Nome     = $f.Name
        Righe    = @(Import-Csv -LiteralPath $f.FullName)
    }
}

function ConvertTo-TestoHtml {
    param([string]$Testo)
    if ($null -eq $Testo) { return '' }
    return ([string]$Testo).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

function New-Tabella {
    param([object[]]$Righe, [string[]]$Colonne, [int]$Massimo = 50)
    if (-not $Righe -or $Righe.Count -eq 0) { return '<p class="ok">Nessuna riga.</p>' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('<table><thead><tr>')
    foreach ($c in $Colonne) { [void]$sb.Append('<th>' + (ConvertTo-TestoHtml $c) + '</th>') }
    [void]$sb.Append('</tr></thead><tbody>')
    $n = 0
    foreach ($r in $Righe) {
        if ($n -ge $Massimo) { break }
        [void]$sb.Append('<tr>')
        foreach ($c in $Colonne) {
            [void]$sb.Append('<td>' + (ConvertTo-TestoHtml $r.$c) + '</td>')
        }
        [void]$sb.Append('</tr>')
        $n++
    }
    [void]$sb.Append('</tbody></table>')
    if ($Righe.Count -gt $Massimo) {
        [void]$sb.Append('<p class="nota">Mostrate ' + $Massimo + ' righe su ' + $Righe.Count + '. Il CSV le contiene tutte.</p>')
    }
    return $sb.ToString()
}

function New-Sezione {
    param(
        [string]$Titolo,
        [object]$Fonte,
        [string]$NomeAtteso,
        [string]$SeAssente,
        [string]$Corpo
    )
    if (-not $Fonte) {
        return @"
<section><h2>$Titolo</h2>
<div class="assente"><strong>Fonte non raccolta.</strong> Non e' stato trovato alcun file <code>$NomeAtteso</code> in questa cartella.
Questo non significa che non ci sia nulla da vedere: significa che <em>non e' stato guardato</em>. $SeAssente</div>
</section>
"@
    }
    return @"
<section><h2>$Titolo</h2>
<p class="fonte">Fonte: <code>$(ConvertTo-TestoHtml $Fonte.Nome)</code> &mdash; $($Fonte.Righe.Count) righe</p>
$Corpo
</section>
"@
}

# ----------------------------------------------------------------------------------
# Lettura delle fonti
# ----------------------------------------------------------------------------------
Write-Host ''
Write-Host ("Lettura dei CSV in {0}" -f (Resolve-Path $Cartella)) -ForegroundColor Cyan

$prereq    = Get-CsvPiuRecente 'IR-01-Prerequisiti-*.csv'
$snapshot  = Get-CsvPiuRecente 'IR-02-StatoUtenti-*.csv'
$blocco    = Get-CsvPiuRecente 'IR-03-Blocco-*.csv'
$signin    = Get-CsvPiuRecente 'IR-05-SignIn-*-SOSPETTI.csv'
$signinAll = Get-CsvPiuRecente 'IR-05-SignIn-2*.csv'
$persist   = Get-CsvPiuRecente 'IR-06-AuditEntra-*-PERSISTENZA.csv'
$ual       = Get-CsvPiuRecente 'IR-07-UnifiedAudit-*.csv'
$trace     = Get-CsvPiuRecente 'IR-08-MessageTrace-*.csv'
$regole    = Get-CsvPiuRecente 'IR-09-RegolePosta-2*.csv'
$inoltri   = Get-CsvPiuRecente 'IR-09-RegolePosta-*-INOLTRI-CASSETTA.csv'

foreach ($x in @(
    @{ n = '01 prerequisiti'; f = $prereq },  @{ n = '02 snapshot utenti'; f = $snapshot },
    @{ n = '03 blocco'; f = $blocco },        @{ n = '05 sign-in sospetti'; f = $signin },
    @{ n = '06 persistenza'; f = $persist },  @{ n = '07 audit unificato'; f = $ual },
    @{ n = '08 message trace'; f = $trace },  @{ n = '09 regole posta'; f = $regole }
)) {
    if ($x.f) { Write-Host ("  trovato  {0}  ({1} righe)" -f $x.n, $x.f.Righe.Count) -ForegroundColor Green }
    else      { Write-Host ("  ASSENTE  {0}" -f $x.n) -ForegroundColor Yellow }
}

# ----------------------------------------------------------------------------------
# Cruscotto
# ----------------------------------------------------------------------------------
$schede = New-Object System.Collections.Generic.List[string]
function Add-Scheda {
    param([string]$Etichetta, [string]$Valore, [string]$Classe = '')
    $schede.Add('<div class="scheda ' + $Classe + '"><div class="valore">' + (ConvertTo-TestoHtml $Valore) + '</div><div class="etichetta">' + (ConvertTo-TestoHtml $Etichetta) + '</div></div>')
}

if ($snapshot) {
    Add-Scheda 'Account nel tenant' ([string]$snapshot.Righe.Count)
    Add-Scheda 'Erano abilitati' ([string]@($snapshot.Righe | Where-Object { $_.AccountEnabled -eq 'True' }).Count)
    $sinc = @($snapshot.Righe | Where-Object { $_.Sincronizzato -eq 'Si' }).Count
    if ($sinc -gt 0) { Add-Scheda 'Sincronizzati da AD' ([string]$sinc) 'attenzione' }
} else { Add-Scheda 'Account nel tenant' 'n.d.' 'assente-scheda' }

if ($blocco) {
    Add-Scheda 'Account bloccati' ([string]@($blocco.Righe | Where-Object { $_.Blocco -eq 'Bloccato' }).Count) 'grave'
    Add-Scheda 'Sessioni revocate' ([string]@($blocco.Righe | Where-Object { $_.RevocaSessioni -eq 'Revocate' }).Count)
} else { Add-Scheda 'Account bloccati' 'n.d.' 'assente-scheda' }

if ($signin) { Add-Scheda 'Accessi riusciti sospetti' ([string]$signin.Righe.Count) 'grave' }
else { Add-Scheda 'Accessi riusciti sospetti' 'n.d.' 'assente-scheda' }

if ($persist) { Add-Scheda 'Eventi di persistenza' ([string]$persist.Righe.Count) 'grave' }
else { Add-Scheda 'Eventi di persistenza' 'n.d.' 'assente-scheda' }

if ($regole) {
    Add-Scheda 'Regole con inoltro esterno' ([string]@($regole.Righe | Where-Object { $_.InoltroEsterno -eq 'True' }).Count) 'grave'
} else { Add-Scheda 'Regole con inoltro esterno' 'n.d.' 'assente-scheda' }

# ----------------------------------------------------------------------------------
# Sezioni
# ----------------------------------------------------------------------------------
$secPrereq = New-Sezione -Titolo '1. Cosa si e'' potuto raccogliere' -Fonte $prereq `
    -NomeAtteso 'IR-01-Prerequisiti-*.csv' `
    -SeAssente 'Eseguire <code>01-Test-PrerequisitiEmergenza.ps1</code>: senza, non si sa quali fonti esistano su questo tenant.' `
    -Corpo (New-Tabella -Righe $prereq.Righe -Colonne @('Area', 'Controllo', 'Stato', 'Dettaglio', 'Impatto'))

$corpoBlocco = ''
if ($blocco) {
    $perEsito = $blocco.Righe | Group-Object Blocco | Sort-Object Count -Descending |
        ForEach-Object { [pscustomobject]@{ Esito = $_.Name; Account = $_.Count } }
    $errori = @($blocco.Righe | Where-Object { $_.Blocco -eq 'Errore' })
    $corpoBlocco = (New-Tabella -Righe $perEsito -Colonne @('Esito', 'Account'))
    if ($errori.Count -gt 0) {
        $corpoBlocco += '<h3>Account su cui il blocco e'' fallito</h3>'
        $corpoBlocco += (New-Tabella -Righe $errori -Colonne @('UserPrincipalName', 'Sincronizzato', 'Errore') -Massimo 30)
    }
}
$secBlocco = New-Sezione -Titolo '2. Contenimento' -Fonte $blocco `
    -NomeAtteso 'IR-03-Blocco-*.csv' `
    -SeAssente 'Se il contenimento non e'' stato eseguito, questa e'' la prima decisione da prendere.' `
    -Corpo $corpoBlocco

$corpoSignin = ''
if ($signin) {
    $corpoSignin = (New-Tabella -Righe ($signin.Righe | Sort-Object DataOraUtc -Descending) `
        -Colonne @('DataOraUtc', 'UserPrincipalName', 'Applicazione', 'IndirizzoIP', 'Paese', 'ClientUsato', 'MotivoSospetto') -Massimo 60)
}
$secSignin = New-Sezione -Titolo '3. Accessi riusciti con indicatori di sospetto' -Fonte $signin `
    -NomeAtteso 'IR-05-SignIn-*-SOSPETTI.csv' `
    -SeAssente 'Eseguire <code>05-Export-SignInLogs.ps1</code>. Se il tenant non ha Entra ID P1 questi log non esistono: la fonte alternativa e'' il log unificato.' `
    -Corpo $corpoSignin

$corpoPersist = ''
if ($persist) {
    $perFamiglia = $persist.Righe | Group-Object Famiglia | Sort-Object Count -Descending |
        ForEach-Object { [pscustomobject]@{ Famiglia = $_.Name; Eventi = $_.Count } }
    $corpoPersist = (New-Tabella -Righe $perFamiglia -Colonne @('Famiglia', 'Eventi'))
    $corpoPersist += '<h3>Dettaglio</h3>'
    $corpoPersist += (New-Tabella -Righe ($persist.Righe | Sort-Object DataOraUtc -Descending) `
        -Colonne @('DataOraUtc', 'Famiglia', 'Attivita', 'EseguitaDa', 'Bersaglio', 'Esito') -Massimo 60)
}
$secPersist = New-Sezione -Titolo '4. Azioni di persistenza sull''identita''' -Fonte $persist `
    -NomeAtteso 'IR-06-AuditEntra-*-PERSISTENZA.csv' `
    -SeAssente 'Eseguire <code>06-Export-AuditLogEntra.ps1</code>. E'' la sezione che dice se la compromissione si e'' radicata.' `
    -Corpo $corpoPersist

$corpoRegole = ''
if ($regole) {
    $alta = @($regole.Righe | Where-Object { $_.Gravita -eq 'ALTA' })
    if ($alta.Count -gt 0) {
        $corpoRegole = '<p class="grave-testo">' + $alta.Count + ' regole inoltrano fuori dal tenant. Restano attive anche ad account bloccato.</p>'
        $corpoRegole += (New-Tabella -Righe $alta -Colonne @('UserPrincipalName', 'NomeRegola', 'Abilitata', 'Destinazioni') -Massimo 40)
    } else {
        $corpoRegole = '<p class="ok">Nessuna regola con inoltro esterno.</p>'
    }
    if ($inoltri -and $inoltri.Righe.Count -gt 0) {
        $corpoRegole += '<h3>Inoltro impostato a livello di cassetta</h3>'
        $corpoRegole += '<p class="nota">Non visibile all''utente in Outlook.</p>'
        $corpoRegole += (New-Tabella -Righe $inoltri.Righe -Colonne @('UserPrincipalName', 'Destinazione', 'Esterno', 'CopiaInCassetta') -Massimo 40)
    }
}
$secRegole = New-Sezione -Titolo '5. Regole di posta e inoltri' -Fonte $regole `
    -NomeAtteso 'IR-09-RegolePosta-*.csv' `
    -SeAssente 'Eseguire <code>09-Export-RegolePostaEInoltri.ps1</code> PRIMA di riabilitare gli utenti: le regole malevole sopravvivono al blocco.' `
    -Corpo $corpoRegole

$corpoUal = ''
if ($ual) {
    $perOp = $ual.Righe | Group-Object Operazione | Sort-Object Count -Descending |
        Select-Object -First 20 | ForEach-Object { [pscustomobject]@{ Operazione = $_.Name; Eventi = $_.Count } }
    $corpoUal = (New-Tabella -Righe $perOp -Colonne @('Operazione', 'Eventi'))
}
$secUal = New-Sezione -Titolo '6. Log di controllo unificato' -Fonte $ual `
    -NomeAtteso 'IR-07-UnifiedAudit-*.csv' `
    -SeAssente 'Eseguire <code>07-Export-UnifiedAuditLog.ps1</code>. E'' la fonte piu'' longeva: 180 giorni.' `
    -Corpo $corpoUal

$corpoTrace = ''
if ($trace) {
    $perDominio = $trace.Righe |
        Where-Object { $_.Destinatario -and ([string]$_.Destinatario).Contains('@') } |
        Group-Object { (([string]$_.Destinatario) -split '@')[-1] } |
        Sort-Object Count -Descending | Select-Object -First 20 |
        ForEach-Object { [pscustomobject]@{ Dominio = $_.Name; Messaggi = $_.Count } }
    $corpoTrace = '<h3>Domini di destinazione</h3>' + (New-Tabella -Righe $perDominio -Colonne @('Dominio', 'Messaggi'))
}
$secTrace = New-Sezione -Titolo '7. Posta in uscita' -Fonte $trace `
    -NomeAtteso 'IR-08-MessageTrace-*.csv' `
    -SeAssente 'Eseguire <code>08-Export-MessageTrace.ps1</code> per sapere che cosa e'' uscito e verso chi.' `
    -Corpo $corpoTrace

$intestazioneCliente = ''
if ($Cliente) { $intestazioneCliente = '<p class="cliente">' + (ConvertTo-TestoHtml $Cliente) + '</p>' }

$html = @"
<!doctype html>
<html lang="it"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Report incidente Microsoft 365</title>
<style>
 :root { --ink:#191A1E; --muted:#6C757D; --linea:#E9ECEF; --brand:#0177FF; --grave:#C1121F; --attenzione:#B45309; --ok:#15803D; }
 * { box-sizing:border-box; }
 body { margin:0; padding:32px 20px 64px; font:15px/1.6 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; color:var(--ink); background:#fff; }
 .wrap { max-width:1100px; margin:0 auto; }
 h1 { font-size:26px; margin:0 0 4px; }
 h2 { font-size:19px; margin:36px 0 10px; padding-bottom:6px; border-bottom:2px solid var(--linea); }
 h3 { font-size:15px; margin:22px 0 8px; color:var(--muted); text-transform:uppercase; letter-spacing:.04em; }
 .cliente { font-size:17px; font-weight:600; margin:2px 0 0; }
 .meta { color:var(--muted); font-size:13px; margin:6px 0 0; }
 .schede { display:flex; flex-wrap:wrap; gap:12px; margin:26px 0 8px; }
 .scheda { flex:1 1 150px; border:1px solid var(--linea); border-radius:8px; padding:14px 16px; }
 .scheda .valore { font-size:24px; font-weight:700; }
 .scheda .etichetta { font-size:12px; color:var(--muted); margin-top:2px; }
 .scheda.grave { border-color:var(--grave); } .scheda.grave .valore { color:var(--grave); }
 .scheda.attenzione { border-color:var(--attenzione); } .scheda.attenzione .valore { color:var(--attenzione); }
 .scheda.assente-scheda .valore { color:var(--muted); font-weight:500; }
 table { border-collapse:collapse; width:100%; margin:10px 0; font-size:13px; }
 th,td { border:1px solid var(--linea); padding:6px 9px; text-align:left; vertical-align:top; word-break:break-word; }
 th { background:#F8F9FA; font-weight:600; }
 tbody tr:nth-child(even) { background:#FCFCFD; }
 .assente { border-left:4px solid var(--attenzione); background:#FFFBEB; padding:12px 14px; border-radius:0 6px 6px 0; }
 .fonte { color:var(--muted); font-size:12px; margin:0 0 8px; }
 .nota { color:var(--muted); font-size:12px; }
 .ok { color:var(--ok); }
 .grave-testo { color:var(--grave); font-weight:600; }
 code { background:#F1F3F5; padding:1px 5px; border-radius:3px; font-size:12px; }
 footer { margin-top:48px; padding-top:16px; border-top:1px solid var(--linea); color:var(--muted); font-size:12px; }
 @media print { body { padding:0; } .scheda { break-inside:avoid; } section { break-inside:avoid; } }
</style></head><body><div class="wrap">
<h1>Report incidente Microsoft 365</h1>
$intestazioneCliente
<p class="meta">Generato il $(Get-Date -Format 'dd/MM/yyyy alle HH:mm') &middot; SynSphere Italia</p>

<div class="schede">
$($schede -join "`n")
</div>
<p class="nota">Le voci <strong>n.d.</strong> indicano una fonte <em>non raccolta</em>, non un valore pari a zero.</p>

$secPrereq
$secBlocco
$secSignin
$secPersist
$secRegole
$secUal
$secTrace

<section><h2>Limiti di questo report</h2>
<ul>
<li>I sign-in log di Entra coprono <strong>30 giorni</strong> (7 con Entra ID Free) e richiedono Entra ID P1 o P2. Oltre quella finestra non esistono.</li>
<li>Il log di controllo unificato copre <strong>180 giorni</strong> con Audit Standard, un anno solo con Audit Premium o E5, e solo se la registrazione era <em>gia' attiva</em> al momento dei fatti.</li>
<li>Il tracciamento dei messaggi copre <strong>90 giorni</strong>, con un massimo di 10 giorni per interrogazione e 5.000 risultati per volta.</li>
<li>Questo documento raccoglie indizi e non stabilisce se ci sia stata una compromissione: quella resta una valutazione umana.</li>
</ul>
</section>

<footer>SynSphere Italia &middot; <a href="https://synsphere.it">synsphere.it</a> &middot; Documento generato automaticamente dal toolkit di emergenza. Fornito "as is".</footer>
</div></body></html>
"@

$html | Out-File -FilePath $OutputHtml -Encoding UTF8

Write-Host ''
Write-Host ("Report -> {0}" -f $OutputHtml) -ForegroundColor Green
$assenti = @(@($prereq, $snapshot, $blocco, $signin, $persist, $ual, $trace, $regole) | Where-Object { -not $_ }).Count
if ($assenti -gt 0) {
    Write-Host ("{0} fonti su 8 non sono state raccolte: nel report sono marcate come n.d., non come zero." -f $assenti) -ForegroundColor Yellow
}
