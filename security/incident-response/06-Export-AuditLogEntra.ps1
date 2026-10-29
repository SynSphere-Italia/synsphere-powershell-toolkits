#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Esporta il log di controllo di Entra ID e isola le azioni con cui si costruisce la persistenza.
.DESCRIPTION
    Sola lettura.

    I sign-in log dicono CHI e' entrato. Questo dice COSA HA FATTO all'identita': ed e' qui
    che si vede la differenza fra un accesso anomalo e una compromissione che si sta radicando.

    Isola sette famiglie di eventi che, in un tenant sotto attacco, sono il modo normale di
    restare dentro anche dopo il cambio password:

      - metodi di autenticazione aggiunti o modificati (un secondo fattore dell'attaccante);
      - consensi applicativi e service principal aggiunti (l'accesso alla posta senza password:
        sopravvive al reset della password E alla revoca delle sessioni);
      - credenziali aggiunte a un'applicazione (stessa cosa, lato app registrata);
      - ruoli di amministrazione assegnati;
      - utenti creati;
      - domini aggiunti o verificati (per firmare posta a nome dell'azienda);
      - criteri di accesso condizionale modificati o disattivati.

    La conservazione del log di controllo di Entra e' di 30 giorni con P1/P2 (7 con Free),
    esattamente come i sign-in log.
.PARAMETER Giorni
    Finestra. Default 30.
.PARAMETER OutputCsv
    Export completo. Default: .\IR-06-AuditEntra-<data-ora>.csv
.EXAMPLE
    .\06-Export-AuditLogEntra.ps1
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Sola lettura. Permessi Graph: AuditLog.Read.All, Directory.Read.All
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 30)][int]$Giorni = 30,
    [string]$OutputCsv = (".\IR-06-AuditEntra-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
)

$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'AuditLog.Read.All', 'Directory.Read.All' -NoWelcome

$da = (Get-Date).ToUniversalTime().AddDays(-$Giorni)
$filtro = "activityDateTime ge {0}" -f $da.ToString('yyyy-MM-ddTHH:mm:ssZ')

Write-Host ''
Write-Host ("Log di controllo Entra dal {0} (UTC)..." -f $da.ToString('yyyy-MM-dd HH:mm')) -ForegroundColor Cyan

$eventi = $null
try {
    $eventi = @(Get-MgAuditLogDirectoryAudit -Filter $filtro -All -ErrorAction Stop)
} catch {
    $msg = $_.Exception.Message
    if ($msg -match 'Premium|license|licens|NonPremium') {
        Write-Host 'Log di controllo non disponibile: richiede Entra ID P1/P2.' -ForegroundColor Red
        Write-Host 'Ripiegare sul log di controllo unificato (script 07).' -ForegroundColor Yellow
        return
    }
    throw
}

Write-Host ("Eventi letti: {0}" -f $eventi.Count) -ForegroundColor Green
if ($eventi.Count -eq 0) {
    Write-Host 'Nessun evento nella finestra richiesta.' -ForegroundColor Yellow
    return
}

$righe = foreach ($e in $eventi) {
    $chi = ''
    if ($e.InitiatedBy) {
        if ($e.InitiatedBy.User -and $e.InitiatedBy.User.UserPrincipalName) {
            $chi = $e.InitiatedBy.User.UserPrincipalName
        } elseif ($e.InitiatedBy.App -and $e.InitiatedBy.App.DisplayName) {
            $chi = ("[app] {0}" -f $e.InitiatedBy.App.DisplayName)
        }
    }
    $ip = ''
    if ($e.InitiatedBy -and $e.InitiatedBy.User) { $ip = $e.InitiatedBy.User.IPAddress }

    $bersagli = ''
    if ($e.TargetResources) {
        $bersagli = (@($e.TargetResources | ForEach-Object {
            if ($_.UserPrincipalName) { $_.UserPrincipalName } else { $_.DisplayName }
        }) | Where-Object { $_ }) -join '; '
    }

    [pscustomobject]@{
        DataOraUtc     = $e.ActivityDateTime
        Categoria      = $e.Category
        Attivita       = $e.ActivityDisplayName
        Esito          = $e.Result
        MotivoEsito    = $e.ResultReason
        EseguitaDa     = $chi
        IndirizzoIP    = $ip
        Bersaglio      = $bersagli
        Servizio       = $e.LoggedByService
        Correlazione   = $e.CorrelationId
    }
}

$righe | Sort-Object DataOraUtc | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Export completo -> {0}" -f $OutputCsv) -ForegroundColor Cyan

# ----------------------------------------------------------------------------------
# Le azioni con cui si costruisce la persistenza.
# I nomi delle attivita' variano nel tempo e per lingua del tenant: si filtra per
# SOTTOSTRINGA su piu' varianti, non per uguaglianza a un enum cablato.
# ----------------------------------------------------------------------------------
$famiglie = [ordered]@{
    'Metodo di autenticazione'      = @('security info', 'authentication method', 'strong authentication', 'metodo di autenticazione')
    'Consenso / service principal'  = @('consent to application', 'add service principal', 'add app role assignment', 'add oauth2permissiongrant', 'add delegated permission')
    'Credenziali applicative'       = @('add application', 'update application', 'certificates and secrets', 'add owner to application')
    'Ruoli di amministrazione'      = @('add member to role', 'add eligible member to role', 'aggiunta membro al ruolo')
    'Creazione utenti'              = @('add user', 'aggiunta utente')
    'Domini'                        = @('add domain', 'verify domain', 'add verified domain')
    'Accesso condizionale'          = @('conditional access', 'accesso condizionale')
}

$sospetti = New-Object System.Collections.Generic.List[object]
foreach ($r in $righe) {
    $att = ''
    if ($r.Attivita) { $att = ([string]$r.Attivita).ToLowerInvariant() }
    if (-not $att) { continue }
    foreach ($nome in $famiglie.Keys) {
        $trovato = $false
        foreach ($chiave in $famiglie[$nome]) {
            if ($att.Contains($chiave)) { $trovato = $true; break }
        }
        if ($trovato) {
            $sospetti.Add(($r | Select-Object *, @{ n = 'Famiglia'; e = { $nome } }))
            break
        }
    }
}

$csvSospetti = $OutputCsv -replace '\.csv$', '-PERSISTENZA.csv'
Write-Host ''
if ($sospetti.Count -gt 0) {
    $sospetti | Export-Csv -Path $csvSospetti -NoTypeInformation -Encoding UTF8
    Write-Host ("{0} eventi nelle famiglie di persistenza -> {1}" -f $sospetti.Count, $csvSospetti) -ForegroundColor Red
    Write-Host ''
    $sospetti | Group-Object Famiglia | Sort-Object Count -Descending |
        Select-Object Count, Name | Format-Table -AutoSize
    Write-Host 'I consensi applicativi vanno guardati per primi: sopravvivono al cambio password' -ForegroundColor Yellow
    Write-Host 'E alla revoca delle sessioni. Bloccare gli utenti non li disattiva.' -ForegroundColor Yellow
} else {
    Write-Host 'Nessun evento nelle famiglie di persistenza nella finestra esaminata.' -ForegroundColor Green
}
