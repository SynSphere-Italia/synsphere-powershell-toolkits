#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Esporta il log di controllo unificato (Exchange, SharePoint, Entra, Teams) con la paginazione corretta.
.DESCRIPTION
    Sola lettura. E' la fonte piu' longeva a disposizione: 180 giorni con Audit Standard
    (default dal 17 ottobre 2023), un anno solo con Audit Premium o E5. Quando i sign-in log
    di Entra sono esauriti o assenti, questo e' cio' che resta.

    LA TRAPPOLA CHE ROVINA LA RACCOLTA. Search-UnifiedAuditLog senza -SessionCommand
    restituisce 100 RECORD e non da' alcun errore: sembra semplicemente che nel periodo ci
    siano stati cento eventi. Un report costruito cosi' e' sbagliato e sembra completo.

    La paginazione corretta e quella implementata qui:
      - -SessionCommand ReturnLargeSet, che arriva a 50.000 record per sessione;
      - lo STESSO -SessionId su tutte le chiamate, ripetute finche' non tornano zero record;
      - non si mescolano mai ReturnLargeSet e ReturnNextPreviewPage sulla stessa sessione,
        o il risultato viene troncato a 10.000;
      - i record tornano NON ORDINATI: si ordinano alla fine, qui per data.

    Se si tocca il tetto dei 50.000 lo script lo dice a voce alta e va rilanciato su finestre
    piu' strette: quel numero non e' "tutti gli eventi", e' "il massimo che la sessione rende".
.PARAMETER Giorni
    Finestra. Default 30. Il massimo utile e 180 con Audit Standard.
.PARAMETER Operazioni
    Limita a operazioni specifiche (es. 'UserLoggedIn','New-InboxRule'). Senza, prende tutto.
.PARAMETER OutputCsv
    Export completo. Default: .\IR-07-UnifiedAudit-<data-ora>.csv
.EXAMPLE
    .\07-Export-UnifiedAuditLog.ps1 -Giorni 90
.EXAMPLE
    .\07-Export-UnifiedAuditLog.ps1 -Giorni 180 -Operazioni 'New-InboxRule','Set-InboxRule','UserLoggedIn'
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Sola lettura. Ruolo: View-Only Audit Logs o Audit Logs.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 180)][int]$Giorni = 30,
    [string[]]$Operazioni = @(),
    [string]$OutputCsv = (".\IR-07-UnifiedAudit-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
)

$ErrorActionPreference = 'Stop'

try {
    $null = Get-OrganizationConfig -ErrorAction Stop
} catch {
    Write-Host 'Connessione a Exchange Online...' -ForegroundColor Cyan
    Connect-ExchangeOnline -ShowBanner:$false
}

# Il log potrebbe essere spento: in quel caso non ci sono prove da raccogliere, e va detto
# subito invece di restituire un CSV vuoto che sembra un tenant tranquillo.
try {
    $cfg = Get-AdminAuditLogConfig -ErrorAction Stop
    if (-not $cfg.UnifiedAuditLogIngestionEnabled) {
        Write-Host ''
        Write-Host 'IL LOG DI CONTROLLO UNIFICATO RISULTA DISATTIVATO SU QUESTO TENANT.' -ForegroundColor Red
        Write-Host 'Per il periodo passato non esistono prove da raccogliere.' -ForegroundColor Red
        Write-Host 'Attivarlo subito: Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true' -ForegroundColor Yellow
        Write-Host 'La registrazione parte da quel momento, non e retroattiva.' -ForegroundColor Yellow
        Write-Host ''
    }
} catch {
    Write-Warning "Stato del log di controllo non leggibile: si prosegue comunque."
}

$da = (Get-Date).ToUniversalTime().AddDays(-$Giorni)
$a  = (Get-Date).ToUniversalTime()

Write-Host ''
Write-Host ("Ricerca dal {0} al {1} (UTC)" -f $da.ToString('yyyy-MM-dd'), $a.ToString('yyyy-MM-dd')) -ForegroundColor Cyan
if ($Operazioni.Count -gt 0) {
    Write-Host ("Operazioni: {0}" -f ($Operazioni -join ', ')) -ForegroundColor Cyan
}

$sessione = [guid]::NewGuid().ToString()
$tutti = New-Object System.Collections.Generic.List[object]
$giro = 0
$TETTO = 50000

do {
    $giro++
    $param = @{
        StartDate      = $da
        EndDate        = $a
        SessionId      = $sessione
        SessionCommand = 'ReturnLargeSet'
        ResultSize     = 5000
        ErrorAction    = 'Stop'
    }
    if ($Operazioni.Count -gt 0) { $param['Operations'] = $Operazioni }

    $blocco = @(Search-UnifiedAuditLog @param)
    if ($blocco.Count -gt 0) { $tutti.AddRange($blocco) }
    Write-Host ("  giro {0}: {1} record (totale {2})" -f $giro, $blocco.Count, $tutti.Count) -ForegroundColor DarkGray
} while ($blocco.Count -gt 0 -and $tutti.Count -lt $TETTO)

Write-Host ("Record recuperati: {0}" -f $tutti.Count) -ForegroundColor Green

if ($tutti.Count -eq 0) {
    Write-Host 'Nessun record. Verificare che il log di controllo sia attivo e la finestra corretta.' -ForegroundColor Yellow
    return
}

if ($tutti.Count -ge $TETTO) {
    Write-Host ''
    Write-Host ("RAGGIUNTO IL TETTO DI {0} RECORD PER SESSIONE." -f $TETTO) -ForegroundColor Red
    Write-Host 'Questo NON e il totale degli eventi: e il massimo che una sessione restituisce.' -ForegroundColor Red
    Write-Host 'Rilanciare su finestre piu strette (-Giorni 7) o filtrando con -Operazioni.' -ForegroundColor Yellow
    Write-Host ''
}

# I record di ReturnLargeSet arrivano NON ordinati: si ordina qui.
$righe = foreach ($r in $tutti) {
    $ip = ''
    $extra = ''
    if ($r.AuditData) {
        try {
            $d = $r.AuditData | ConvertFrom-Json -ErrorAction Stop
            if ($d.PSObject.Properties.Name -contains 'ClientIP') { $ip = $d.ClientIP }
            elseif ($d.PSObject.Properties.Name -contains 'ClientIPAddress') { $ip = $d.ClientIPAddress }
            if ($d.PSObject.Properties.Name -contains 'ObjectId') { $extra = $d.ObjectId }
        } catch { }
    }
    [pscustomobject]@{
        DataOraUtc     = $r.CreationDate
        Utente         = $r.UserIds
        Operazione     = $r.Operations
        CaricoDiLavoro = $r.RecordType
        IndirizzoIP    = $ip
        Oggetto        = $extra
        DatiCompleti   = $r.AuditData
    }
}

$righe = $righe | Sort-Object DataOraUtc
$righe | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Export -> {0}" -f $OutputCsv) -ForegroundColor Cyan

Write-Host ''
Write-Host 'Operazioni piu frequenti:' -ForegroundColor Yellow
$righe | Group-Object Operazione | Sort-Object Count -Descending |
    Select-Object -First 15 Count, Name | Format-Table -AutoSize

Write-Host 'Utenti piu attivi:' -ForegroundColor Yellow
$righe | Group-Object Utente | Sort-Object Count -Descending |
    Select-Object -First 10 Count, Name | Format-Table -AutoSize
