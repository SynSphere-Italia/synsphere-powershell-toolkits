#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Esporta i log di accesso di Microsoft Entra ID e ne estrae gli indicatori utili al triage.
.DESCRIPTION
    Sola lettura.

    DUE LIMITI DA CONOSCERE PRIMA, perche' nessuno dei due si vede dal portale:

      - I sign-in log via API richiedono Entra ID P1 o P2. Su un tenant Business Basic o
        Standard NON esistono: la chiamata fallisce con un errore di autorizzazione, che a
        occhio somiglia a un problema di permessi. Lo script distingue i due casi e lo dice.
        Business Premium include P1, quindi va.
      - La conservazione e' di 30 GIORNI (7 con Entra ID Free). Non esiste modo di recuperare
        accessi piu' vecchi: se l'intrusione e' iniziata prima, quella finestra e' persa e
        l'unica fonte residua e' il log di controllo unificato (script 07), che arriva a 180
        giorni.

    Estrae anche un secondo CSV di soli SOSPETTI: accessi RIUSCITI con esito di rischio,
    protocolli di autenticazione legacy (che aggirano l'MFA) e paesi non abituali.
.PARAMETER Giorni
    Finestra da esportare. Default 30, che e' anche il massimo conservato.
.PARAMETER PaesiAbituali
    Codici ISO dei paesi considerati normali per l'azienda. Default: IT.
    Gli accessi riusciti da altri paesi finiscono nel CSV dei sospetti.
.PARAMETER OutputCsv
    Export completo. Default: .\IR-05-SignIn-<data-ora>.csv
.EXAMPLE
    .\05-Export-SignInLogs.ps1
.EXAMPLE
    .\05-Export-SignInLogs.ps1 -Giorni 7 -PaesiAbituali 'IT','DE'
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Sola lettura. Permessi Graph: AuditLog.Read.All, Directory.Read.All
    Ruolo: Security Reader o Reports Reader.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 30)][int]$Giorni = 30,
    [string[]]$PaesiAbituali = @('IT'),
    [string]$OutputCsv = (".\IR-05-SignIn-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
)

$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'AuditLog.Read.All', 'Directory.Read.All' -NoWelcome

$da = (Get-Date).ToUniversalTime().AddDays(-$Giorni)
$filtro = "createdDateTime ge {0}" -f $da.ToString('yyyy-MM-ddTHH:mm:ssZ')

Write-Host ''
Write-Host ("Sign-in log dal {0} (UTC) a oggi..." -f $da.ToString('yyyy-MM-dd HH:mm')) -ForegroundColor Cyan
Write-Host 'Su tenant con molti utenti puo richiedere diversi minuti.' -ForegroundColor DarkGray

$eventi = $null
try {
    $eventi = @(Get-MgAuditLogSignIn -Filter $filtro -All -ErrorAction Stop)
} catch {
    $msg = $_.Exception.Message
    if ($msg -match 'Premium|license|licens|B2C|NonPremium') {
        Write-Host ''
        Write-Host 'SIGN-IN LOG NON DISPONIBILI SU QUESTO TENANT.' -ForegroundColor Red
        Write-Host 'Richiedono Microsoft Entra ID P1 o P2 (incluso in Business Premium).' -ForegroundColor Red
        Write-Host 'Non e un problema di permessi e non e un tenant senza accessi.' -ForegroundColor Red
        Write-Host ''
        Write-Host 'Alternativa: il log di controllo unificato (07-Export-UnifiedAuditLog.ps1)' -ForegroundColor Yellow
        Write-Host 'contiene gli eventi UserLoggedIn di Entra e arriva a 180 giorni.' -ForegroundColor Yellow
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
    $paese = ''
    $citta = ''
    if ($e.Location) {
        $paese = $e.Location.CountryOrRegion
        $citta = $e.Location.City
    }
    $codice = ''
    $motivo = ''
    if ($e.Status) {
        $codice = $e.Status.ErrorCode
        $motivo = $e.Status.FailureReason
    }
    $riuscito = ($codice -eq 0)

    [pscustomobject]@{
        DataOraUtc            = $e.CreatedDateTime
        UserPrincipalName     = $e.UserPrincipalName
        UtenteVisualizzato    = $e.UserDisplayName
        Applicazione          = $e.AppDisplayName
        Riuscito              = $riuscito
        CodiceErrore          = $codice
        MotivoFallimento      = $motivo
        IndirizzoIP           = $e.IpAddress
        Paese                 = $paese
        Citta                 = $citta
        ClientUsato           = $e.ClientAppUsed
        Interattivo           = $e.IsInteractive
        AccessoCondizionale   = $e.ConditionalAccessStatus
        LivelloRischio        = $e.RiskLevelAggregated
        StatoRischio          = $e.RiskState
        DettaglioRischio      = $e.RiskDetail
        SistemaOperativo      = $(if ($e.DeviceDetail) { $e.DeviceDetail.OperatingSystem } else { '' })
        Browser               = $(if ($e.DeviceDetail) { $e.DeviceDetail.Browser } else { '' })
    }
}

$righe | Sort-Object DataOraUtc | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Export completo -> {0}" -f $OutputCsv) -ForegroundColor Cyan

# ----------------------------------------------------------------------------------
# Triage: solo cio' che merita uno sguardo umano, e solo fra gli accessi RIUSCITI.
# Un tentativo fallito da un paese esotico e rumore; uno riuscito e un incidente.
# ----------------------------------------------------------------------------------
$paesiSet = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
foreach ($p in $PaesiAbituali) { if ($p) { $null = $paesiSet.Add($p.Trim()) } }

# I client legacy non supportano l'MFA moderno: un accesso riuscito con questi
# protocolli e la via classica per aggirare l'autenticazione a piu fattori.
$clientLegacy = @('Other clients', 'IMAP4', 'POP3', 'SMTP', 'MAPI Over HTTP',
                  'Exchange ActiveSync', 'Exchange Web Services', 'Authenticated SMTP',
                  'AutoDiscover', 'Offline Address Book')

$sospetti = foreach ($r in $righe) {
    if (-not $r.Riuscito) { continue }
    $motivi = New-Object System.Collections.Generic.List[string]

    if ($r.LivelloRischio -and $r.LivelloRischio -notin @('none', 'hidden', 'unknownFutureValue')) {
        $motivi.Add(("rischio {0}" -f $r.LivelloRischio))
    }
    if ($r.StatoRischio -and $r.StatoRischio -in @('atRisk', 'confirmedCompromised')) {
        $motivi.Add(("stato rischio {0}" -f $r.StatoRischio))
    }
    if ($r.ClientUsato -and ($clientLegacy -contains $r.ClientUsato)) {
        $motivi.Add(("client legacy: {0}" -f $r.ClientUsato))
    }
    if ($r.Paese -and (-not $paesiSet.Contains($r.Paese))) {
        $motivi.Add(("paese non abituale: {0}" -f $r.Paese))
    }

    if ($motivi.Count -gt 0) {
        $r | Select-Object *, @{ n = 'MotivoSospetto'; e = { $motivi -join ' | ' } }
    }
}

$sospetti = @($sospetti)
$csvSospetti = $OutputCsv -replace '\.csv$', '-SOSPETTI.csv'

Write-Host ''
if ($sospetti.Count -gt 0) {
    $sospetti | Export-Csv -Path $csvSospetti -NoTypeInformation -Encoding UTF8
    Write-Host ("{0} accessi RIUSCITI da guardare -> {1}" -f $sospetti.Count, $csvSospetti) -ForegroundColor Red

    Write-Host ''
    Write-Host 'Per utente:' -ForegroundColor Yellow
    $sospetti | Group-Object UserPrincipalName | Sort-Object Count -Descending |
        Select-Object -First 15 Count, Name | Format-Table -AutoSize

    $paesi = @($sospetti | Where-Object { $_.Paese } | Select-Object -ExpandProperty Paese -Unique)
    if ($paesi.Count -gt 0) {
        Write-Host ("Paesi non abituali visti: {0}" -f ($paesi -join ', ')) -ForegroundColor Yellow
    }
} else {
    Write-Host 'Nessun accesso riuscito con indicatori di sospetto nella finestra esaminata.' -ForegroundColor Green
    Write-Host 'Attenzione: significa che questi CONTROLLI non hanno trovato nulla, non che' -ForegroundColor DarkGray
    Write-Host 'non sia successo nulla. La finestra resta di 30 giorni.' -ForegroundColor DarkGray
}
