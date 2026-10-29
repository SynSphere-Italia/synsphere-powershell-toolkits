<#
.SYNOPSIS
    Elenca i client secret e i certificati di tutte le app registration di
    Microsoft Entra ID, ordinati per data di scadenza.

.DESCRIPTION
    Le credenziali delle app registration scadono senza produrre alcun avviso:
    nessuna mail, nessuna notifica nel portale, nessun alert. Il primo segnale e'
    un'integrazione che smette di funzionare - un invio SMTP che risponde 535, un
    job che non autentica piu', un webhook che non firma.

    Questo script rende visibile quello che il portale mostra solo entrando in
    ogni singola app: tutte le credenziali del tenant in un'unica tabella,
    ordinate per urgenza, con l'indicazione di quelle gia' scadute.

    Per ogni client secret riporta anche il campo HINT, cioe' i primi tre
    caratteri del valore: e' l'unico modo per capire QUALE secret sta usando una
    certa applicazione, confrontandolo con i primi tre caratteri del valore
    configurato nel file di ambiente o nel vault. Il valore completo di un secret
    non e' recuperabile dopo la creazione.

    Sola lettura: lo script non modifica nulla.

.PARAMETER GiorniAvviso
    Soglia in giorni entro cui una credenziale e' considerata "in scadenza".
    Default: 90.

.PARAMETER SoloInScadenza
    Mostra solo le credenziali scadute o entro la soglia, nascondendo quelle
    lontane. Utile per il controllo periodico.

.PARAMETER IncludiServicePrincipal
    Include anche le credenziali registrate sui service principal (enterprise
    applications), non solo sulle app registration. Alcune integrazioni di terze
    parti mettono le credenziali qui.

.PARAMETER EsportaCsv
    Percorso di un file CSV in cui salvare il risultato completo.

.PARAMETER TenantId
    Tenant su cui connettersi. Se omesso viene usato quello predefinito
    dell'utente.

.EXAMPLE
    .\get-entra-app-credentials-expiry-synsphere.ps1
    Elenca tutte le credenziali di tutte le app registration.

.EXAMPLE
    .\get-entra-app-credentials-expiry-synsphere.ps1 -SoloInScadenza -GiorniAvviso 60
    Solo cio' che scade entro 60 giorni o e' gia' scaduto.

.EXAMPLE
    .\get-entra-app-credentials-expiry-synsphere.ps1 -IncludiServicePrincipal -EsportaCsv .\credenziali.csv
    Report completo, app registration e service principal, esportato in CSV.

.NOTES
    Autore:      SynSphere Italia - https://synsphere.it
    Requisiti:   PowerShell 5.1+ oppure 7+, modulo Microsoft.Graph.Applications
    Permessi:    Application.Read.All (permesso minimo sufficiente: le
                 credenziali sono proprieta' ordinarie dell'oggetto application
                 e non richiedono uno scope dedicato)
    Ruoli:       Directory Readers, Global Reader, Cloud Application
                 Administrator o Application Administrator
    Licenza:     uso interno aziendale gratuito, no redistribuzione commerciale.
                 Fornito "as is": provare prima in un tenant di test.

    NOTA TECNICA - perche' NON si usa -Property/$select
    La documentazione Microsoft Graph impone un limite di 150 richieste al minuto
    per tenant quando si usa $select su keyCredentials. Iterare le app con
    -Property per leggere i certificati significa quindi finire in throttling su
    un tenant con molte registrazioni. Non serve: la risposta di default di
    Get-MgApplication contiene gia' tutto cio' che ci interessa (endDateTime,
    displayName, keyId, hint, type, usage). L'unico campo escluso di default e'
    il valore pubblico del certificato, che a noi non serve.

    NOTA TECNICA - perche' il filtro e' lato client
    passwordCredentials non supporta $filter in Microsoft Graph, quindi non
    esiste un modo per farsi restituire dal server solo i secret in scadenza.
    Il confronto sulle date si fa necessariamente in locale.
#>

[CmdletBinding()]
param(
    [int]$GiorniAvviso = 90,
    [switch]$SoloInScadenza,
    [switch]$IncludiServicePrincipal,
    [string]$EsportaCsv,
    [string]$TenantId
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# 1. Modulo e connessione
# --------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Applications)) {
    Write-Host ''
    Write-Host 'Modulo Microsoft.Graph.Applications non installato. Installalo con:' -ForegroundColor Yellow
    Write-Host '  Install-Module Microsoft.Graph.Applications -Scope CurrentUser' -ForegroundColor Cyan
    Write-Host ''
    return
}

Import-Module Microsoft.Graph.Applications -ErrorAction Stop

$parametriConnessione = @{ Scopes = 'Application.Read.All'; NoWelcome = $true }
if ($TenantId) { $parametriConnessione['TenantId'] = $TenantId }

try {
    Connect-MgGraph @parametriConnessione
}
catch {
    Write-Host "Connessione a Microsoft Graph fallita: $($_.Exception.Message)" -ForegroundColor Red
    return
}

$contesto = Get-MgContext
Write-Host ''
Write-Host "Tenant:  $($contesto.TenantId)" -ForegroundColor DarkGray
Write-Host "Account: $($contesto.Account)" -ForegroundColor DarkGray

# --------------------------------------------------------------------------
# 2. Raccolta credenziali
# --------------------------------------------------------------------------
$adesso = (Get-Date).ToUniversalTime()
$righe = New-Object System.Collections.Generic.List[object]

function Add-Credenziali {
    param(
        [Parameter(Mandatory)] $Oggetto,
        [Parameter(Mandatory)] [string] $Origine
    )

    # Client secret. Nota: passwordCredential NON ha le proprieta' type/usage,
    # e il suo customKeyIdentifier e' documentato come "Do not use".
    foreach ($secret in @($Oggetto.PasswordCredentials)) {
        $scadenza = $secret.EndDateTime
        $righe.Add([pscustomobject]@{
            Origine        = $Origine
            Applicazione   = $Oggetto.DisplayName
            AppId          = $Oggetto.AppId
            Tipo           = 'Secret'
            Descrizione    = if ($secret.DisplayName) { $secret.DisplayName } else { '(senza descrizione)' }
            Hint           = if ($secret.Hint) { "$($secret.Hint)..." } else { '' }
            Identificativo = $secret.KeyId
            Inizio         = $secret.StartDateTime
            Scadenza       = $scadenza
            GiorniRimasti  = if ($scadenza) { [math]::Floor(($scadenza.ToUniversalTime() - $adesso).TotalDays) } else { $null }
        })
    }

    # Certificati. L'impronta sta in customKeyIdentifier (per default e' proprio
    # il thumbprint del certificato) e arriva come array di byte.
    foreach ($cert in @($Oggetto.KeyCredentials)) {
        $scadenza = $cert.EndDateTime
        $impronta = ''
        if ($cert.CustomKeyIdentifier) {
            $impronta = (($cert.CustomKeyIdentifier | ForEach-Object { $_.ToString('x2') }) -join '').ToUpper()
        }
        $righe.Add([pscustomobject]@{
            Origine        = $Origine
            Applicazione   = $Oggetto.DisplayName
            AppId          = $Oggetto.AppId
            Tipo           = if ($cert.Usage) { "Certificato ($($cert.Usage))" } else { 'Certificato' }
            Descrizione    = if ($cert.DisplayName) { $cert.DisplayName } else { '(senza descrizione)' }
            Hint           = if ($impronta.Length -ge 8) { $impronta.Substring(0, 8) + '...' } else { $impronta }
            Identificativo = $cert.KeyId
            Inizio         = $cert.StartDateTime
            Scadenza       = $scadenza
            GiorniRimasti  = if ($scadenza) { [math]::Floor(($scadenza.ToUniversalTime() - $adesso).TotalDays) } else { $null }
        })
    }
}

Write-Host ''
Write-Host 'Lettura delle app registration...' -ForegroundColor DarkGray
$applicazioni = @(Get-MgApplication -All)
foreach ($app in $applicazioni) { Add-Credenziali -Oggetto $app -Origine 'App registration' }
Write-Host "  $($applicazioni.Count) app registration esaminate" -ForegroundColor DarkGray

if ($IncludiServicePrincipal) {
    Write-Host 'Lettura dei service principal...' -ForegroundColor DarkGray
    $principal = @(Get-MgServicePrincipal -All)
    foreach ($sp in $principal) { Add-Credenziali -Oggetto $sp -Origine 'Service principal' }
    Write-Host "  $($principal.Count) service principal esaminati" -ForegroundColor DarkGray
}

if ($righe.Count -eq 0) {
    Write-Host ''
    Write-Host 'Nessuna credenziale trovata. Verifica di avere i permessi di lettura.' -ForegroundColor Yellow
    return
}

# --------------------------------------------------------------------------
# 3. Ordinamento e output
# --------------------------------------------------------------------------
# Le credenziali senza scadenza vanno in fondo, non in testa.
$ordinate = $righe | Sort-Object @{ Expression = { if ($null -eq $_.GiorniRimasti) { [int]::MaxValue } else { $_.GiorniRimasti } } }

$scadute    = @($ordinate | Where-Object { $null -ne $_.GiorniRimasti -and $_.GiorniRimasti -lt 0 })
$inScadenza = @($ordinate | Where-Object { $null -ne $_.GiorniRimasti -and $_.GiorniRimasti -ge 0 -and $_.GiorniRimasti -le $GiorniAvviso })

$daMostrare = if ($SoloInScadenza) { @($scadute) + @($inScadenza) } else { $ordinate }

Write-Host ''
Write-Host ('=' * 100) -ForegroundColor DarkGray
Write-Host " CREDENZIALI ENTRA ID - $($righe.Count) totali, soglia di avviso $GiorniAvviso giorni" -ForegroundColor White
Write-Host ('=' * 100) -ForegroundColor DarkGray
Write-Host ''

$intestazione = '{0,-6} {1,-30} {2,-22} {3,-8} {4,-11} {5}' -f 'GG', 'APPLICAZIONE', 'DESCRIZIONE', 'TIPO', 'SCADENZA', 'HINT'
Write-Host $intestazione -ForegroundColor DarkGray
Write-Host ('-' * 100) -ForegroundColor DarkGray

foreach ($r in $daMostrare) {
    if ($null -eq $r.GiorniRimasti) {
        $etichettaGiorni = '  --'
        $colore = 'DarkGray'
        $dataTesto = 'nessuna'
    }
    else {
        $etichettaGiorni = '{0,4}' -f $r.GiorniRimasti
        $dataTesto = $r.Scadenza.ToString('yyyy-MM-dd')
        $colore =
            if ($r.GiorniRimasti -lt 0)  { 'Red' }
            elseif ($r.GiorniRimasti -le 30) { 'Yellow' }
            elseif ($r.GiorniRimasti -le $GiorniAvviso) { 'Cyan' }
            else { 'Gray' }
    }

    $tipoBreve = if ($r.Tipo -like 'Certificato*') { 'Cert' } else { 'Secret' }
    $riga = '{0,-6} {1,-30} {2,-22} {3,-8} {4,-11} {5}' -f `
        $etichettaGiorni,
        $(if ($r.Applicazione.Length -gt 29) { $r.Applicazione.Substring(0, 28) + '.' } else { $r.Applicazione }),
        $(if ($r.Descrizione.Length -gt 21) { $r.Descrizione.Substring(0, 20) + '.' } else { $r.Descrizione }),
        $tipoBreve,
        $dataTesto,
        $r.Hint

    Write-Host $riga -ForegroundColor $colore
}

# --------------------------------------------------------------------------
# 4. Riepilogo
# --------------------------------------------------------------------------
Write-Host ''
Write-Host ('-' * 100) -ForegroundColor DarkGray

if ($scadute.Count -gt 0) {
    Write-Host "SCADUTE: $($scadute.Count)" -ForegroundColor Red
    foreach ($r in $scadute) {
        Write-Host ("  $($r.Applicazione) / $($r.Descrizione) - scaduta il $($r.Scadenza.ToString('yyyy-MM-dd')) ($([math]::Abs($r.GiorniRimasti)) giorni fa)") -ForegroundColor Red
    }
}
else {
    Write-Host 'Nessuna credenziale scaduta.' -ForegroundColor Green
}

if ($inScadenza.Count -gt 0) {
    Write-Host ''
    Write-Host "IN SCADENZA entro $GiorniAvviso giorni: $($inScadenza.Count)" -ForegroundColor Yellow
    foreach ($r in $inScadenza) {
        Write-Host ("  $($r.Applicazione) / $($r.Descrizione) - fra $($r.GiorniRimasti) giorni ($($r.Scadenza.ToString('yyyy-MM-dd')))") -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'Per capire quale secret usa una data applicazione, confronta la colonna HINT' -ForegroundColor DarkGray
Write-Host 'con i primi tre caratteri del valore configurato: e la sola corrispondenza' -ForegroundColor DarkGray
Write-Host 'possibile, perche il valore completo non e recuperabile dopo la creazione.' -ForegroundColor DarkGray

# --------------------------------------------------------------------------
# 5. Esportazione
# --------------------------------------------------------------------------
if ($EsportaCsv) {
    try {
        $ordinate | Export-Csv -Path $EsportaCsv -NoTypeInformation -Encoding UTF8
        Write-Host ''
        Write-Host "Report salvato in $EsportaCsv" -ForegroundColor Green
    }
    catch {
        Write-Host "Esportazione CSV fallita: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ''
