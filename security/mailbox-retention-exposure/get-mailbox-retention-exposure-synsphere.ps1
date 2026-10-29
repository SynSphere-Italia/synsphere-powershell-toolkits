<#
.SYNOPSIS
    Inventario in sola lettura della conservazione della posta in Microsoft 365:
    blocchi sulle caselle, caselle inattive, criteri di conservazione Purview e
    conservazione dei registri di audit.

.DESCRIPTION
    Risponde a una domanda che il portale non sa mostrare in un colpo solo:
    "per quanto tempo conserviamo le email dei nostri dipendenti, e chi lo ha deciso?"

    Lo script raccoglie quattro insiemi di dati e li mette a confronto:

      A) BLOCCHI SULLE CASELLE
         Litigation hold e blocchi in-place per ogni casella, con la DURATA.
         Evidenzia i blocchi a tempo indeterminato: quando si attiva un litigation
         hold senza specificare una durata, la proprieta' LitigationHoldDuration
         assume il valore Unlimited e gli elementi non vengono mai eliminati.
         Segnala anche i blocchi che non informano l'utente (campi Note e URL vuoti).

      B) CASELLE INATTIVE
         Caselle di persone che hanno lasciato l'azienda e che sopravvivono alla
         rimozione della licenza perche' soggette a un blocco. E' il meccanismo che
         produce le conservazioni pluriennali post-cessazione senza che nessuno le
         abbia decise esplicitamente.

      C) CRITERI DI CONSERVAZIONE (Microsoft Purview)
         Criteri attivi sui carichi di lavoro di posta, con la durata configurata
         e l'azione a scadenza.

      D) CONSERVAZIONE DEI REGISTRI
         Audit log retention policy personalizzate e limite di conservazione del
         registro di audit per casella (AuditLogAgeLimit).

    Contesto normativo e criteri di lettura dei risultati:
    https://synsphere.it/notizie/conservazione-email-dipendenti-limiti-microsoft-365-pmi

.PARAMETER GiorniSoglia
    Soglia in giorni oltre la quale una durata di conservazione viene segnalata
    come da verificare. Default 1095 (3 anni).

.PARAMETER SoloRischi
    Mostra soltanto le voci segnalate: blocchi a tempo indeterminato, durate oltre
    la soglia, caselle inattive, blocchi non comunicati all'utente.
    Utile per il controllo periodico.

.PARAMETER SaltaConformita
    Salta le sezioni C e D, che richiedono la connessione a Security & Compliance
    PowerShell (Connect-IPPSSession) e permessi aggiuntivi. Usare quando si hanno
    solo i permessi Exchange.

.PARAMETER EsportaCsv
    Percorso di una cartella in cui salvare i quattro report in CSV.

.EXAMPLE
    .\get-mailbox-retention-exposure-synsphere.ps1
    Inventario completo di tutte le sezioni.

.EXAMPLE
    .\get-mailbox-retention-exposure-synsphere.ps1 -SoloRischi
    Solo le voci da verificare. E' la modalita' per il controllo periodico.

.EXAMPLE
    .\get-mailbox-retention-exposure-synsphere.ps1 -EsportaCsv "C:\Report"
    Inventario completo con esportazione dei quattro CSV.

.NOTES
    Autore  : SynSphere Italia SRL - https://synsphere.it
    Licenza : Uso interno aziendale gratuito (no redistribuzione commerciale).
              Fornito "as is", senza garanzia. Provare in un tenant di test.

    Requisiti:
      - PowerShell 5.1 o 7+
      - Modulo ExchangeOnlineManagement:
            Install-Module ExchangeOnlineManagement -Scope CurrentUser
      - Permessi in sola lettura. Il minimo pratico:
            Sezioni A-B : ruolo Exchange "View-Only Recipients"
                          (incluso in View-Only Organization Management)
            Sezioni C-D : lettura dei criteri di conservazione e di audit in
                          Microsoft Purview. Il ruolo Global Reader di Entra ID
                          copre entrambe le connessioni.

    QUESTO SCRIPT NON MODIFICA NULLA. Esegue solo cmdlet Get-*.
#>

[CmdletBinding()]
param(
    [int]$GiorniSoglia = 1095,
    [switch]$SoloRischi,
    [switch]$SaltaConformita,
    [string]$EsportaCsv
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Utilita' di output
# ---------------------------------------------------------------------------

function Write-Titolo {
    param([string]$Testo)
    Write-Host ''
    Write-Host ('=' * 78) -ForegroundColor DarkCyan
    Write-Host ("  $Testo") -ForegroundColor Cyan
    Write-Host ('=' * 78) -ForegroundColor DarkCyan
}

function Write-Sezione {
    param([string]$Testo)
    Write-Host ''
    Write-Host ("--- $Testo ") -ForegroundColor White -NoNewline
    Write-Host ('-' * [Math]::Max(4, 74 - $Testo.Length)) -ForegroundColor DarkGray
}

function Write-Nota {
    param([string]$Testo, [string]$Colore = 'Gray')
    Write-Host "    $Testo" -ForegroundColor $Colore
}

# ---------------------------------------------------------------------------
# Connessioni
# ---------------------------------------------------------------------------

Write-Titolo 'Inventario conservazione posta - Microsoft 365 - SynSphere Italia'
Write-Nota "Sola lettura: nessuna modifica al tenant." 'DarkGray'
Write-Nota "Soglia di segnalazione durate: $GiorniSoglia giorni." 'DarkGray'

if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host ''
    Write-Host "  Modulo ExchangeOnlineManagement non trovato." -ForegroundColor Red
    Write-Host "  Installarlo con:" -ForegroundColor Yellow
    Write-Host "      Install-Module ExchangeOnlineManagement -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

Import-Module ExchangeOnlineManagement -ErrorAction Stop

# Connessione Exchange Online (sezioni A e B)
$exoConnessa = $false
try {
    $null = Get-OrganizationConfig -ErrorAction Stop
    $exoConnessa = $true
    Write-Nota "Exchange Online: sessione gia' attiva." 'DarkGreen'
}
catch {
    Write-Nota "Connessione a Exchange Online..." 'DarkGray'
    try {
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        $exoConnessa = $true
        Write-Nota "Exchange Online: connesso." 'DarkGreen'
    }
    catch {
        Write-Host ''
        Write-Host "  Connessione a Exchange Online non riuscita: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Connessione Security & Compliance (sezioni C e D)
$ippsConnessa = $false
if (-not $SaltaConformita) {
    try {
        $null = Get-RetentionCompliancePolicy -ErrorAction Stop
        $ippsConnessa = $true
        Write-Nota "Security & Compliance: sessione gia' attiva." 'DarkGreen'
    }
    catch {
        Write-Nota "Connessione a Security & Compliance PowerShell..." 'DarkGray'
        try {
            Connect-IPPSSession -ShowBanner:$false -ErrorAction Stop
            $ippsConnessa = $true
            Write-Nota "Security & Compliance: connesso." 'DarkGreen'
        }
        catch {
            Write-Nota "Security & Compliance non disponibile: le sezioni C e D verranno saltate." 'Yellow'
            Write-Nota "Causa: $($_.Exception.Message)" 'DarkGray'
        }
    }
}

# ---------------------------------------------------------------------------
# SEZIONE A - Blocchi sulle caselle
# ---------------------------------------------------------------------------

Write-Titolo 'A) BLOCCHI SULLE CASELLE'

Write-Nota "Lettura delle caselle utente..." 'DarkGray'

$proprieta = @(
    'DisplayName', 'PrimarySmtpAddress', 'RecipientTypeDetails',
    'LitigationHoldEnabled', 'LitigationHoldDuration', 'LitigationHoldDate',
    'LitigationHoldOwner', 'ComplianceTagHoldApplied', 'RetentionHoldEnabled',
    'InPlaceHolds', 'RetentionComment', 'RetentionUrl',
    'AuditEnabled', 'AuditLogAgeLimit', 'WhenMailboxCreated'
)

$caselle = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox |
    Select-Object $proprieta

Write-Nota "Caselle lette: $($caselle.Count)" 'DarkGray'

$reportBlocchi = foreach ($m in $caselle) {

    # La durata puo' essere un intervallo oppure il valore Unlimited
    $durataTesto = 'n/d'
    $durataGiorni = $null
    $indeterminato = $false

    if ($m.LitigationHoldEnabled) {
        $d = $m.LitigationHoldDuration
        if ($null -eq $d -or "$d" -match 'Unlimited') {
            $durataTesto = 'ILLIMITATA'
            $indeterminato = $true
        }
        else {
            try {
                $ts = [TimeSpan]::Parse("$d")
                $durataGiorni = [int]$ts.TotalDays
                $durataTesto = "$durataGiorni giorni"
            }
            catch {
                $durataTesto = "$d"
            }
        }
    }

    # Un blocco senza Note e senza URL non viene comunicato all'utente in Outlook
    $utenteInformato = -not ([string]::IsNullOrWhiteSpace($m.RetentionComment) -and
                             [string]::IsNullOrWhiteSpace($m.RetentionUrl))

    $altriBlocchi = 0
    if ($m.InPlaceHolds) { $altriBlocchi = @($m.InPlaceHolds).Count }

    $segnalazioni = New-Object System.Collections.ArrayList
    if ($indeterminato) {
        [void]$segnalazioni.Add('durata illimitata')
    }
    if ($durataGiorni -ne $null -and $durataGiorni -gt $GiorniSoglia) {
        [void]$segnalazioni.Add("durata oltre soglia ($durataGiorni g)")
    }
    if ($m.LitigationHoldEnabled -and -not $utenteInformato) {
        [void]$segnalazioni.Add('utente non informato')
    }
    if ($m.RetentionHoldEnabled) {
        [void]$segnalazioni.Add('retention hold attivo')
    }

    [PSCustomObject]@{
        Casella            = $m.PrimarySmtpAddress
        Nome               = $m.DisplayName
        Tipo               = $m.RecipientTypeDetails
        LitigationHold     = $m.LitigationHoldEnabled
        Durata             = $durataTesto
        DurataGiorni       = $durataGiorni
        AttivatoIl         = if ($m.LitigationHoldDate) { (Get-Date $m.LitigationHoldDate -Format 'yyyy-MM-dd') } else { '' }
        AttivatoDa         = $m.LitigationHoldOwner
        UtenteInformato    = $utenteInformato
        AltriBlocchi       = $altriBlocchi
        EtichetteConserv   = $m.ComplianceTagHoldApplied
        AuditAttivo        = $m.AuditEnabled
        AuditGiorni        = $m.AuditLogAgeLimit
        Segnalazioni       = ($segnalazioni -join '; ')
    }
}

$conBlocco     = @($reportBlocchi | Where-Object { $_.LitigationHold -or $_.AltriBlocchi -gt 0 })
$illimitati    = @($reportBlocchi | Where-Object { $_.Durata -eq 'ILLIMITATA' })
$oltreSoglia   = @($reportBlocchi | Where-Object { $_.DurataGiorni -ne $null -and $_.DurataGiorni -gt $GiorniSoglia })
$nonInformati  = @($reportBlocchi | Where-Object { $_.LitigationHold -and -not $_.UtenteInformato })

Write-Sezione 'Riepilogo blocchi'
Write-Host ("    Caselle totali                  : {0}" -f $reportBlocchi.Count)
Write-Host ("    Con almeno un blocco attivo     : {0}" -f $conBlocco.Count) -ForegroundColor $(if ($conBlocco.Count) { 'Yellow' } else { 'Green' })
Write-Host ("    Litigation hold ILLIMITATO      : {0}" -f $illimitati.Count) -ForegroundColor $(if ($illimitati.Count) { 'Red' } else { 'Green' })
Write-Host ("    Durata oltre $GiorniSoglia giorni          : {0}" -f $oltreSoglia.Count) -ForegroundColor $(if ($oltreSoglia.Count) { 'Yellow' } else { 'Green' })
Write-Host ("    Blocco non comunicato all'utente: {0}" -f $nonInformati.Count) -ForegroundColor $(if ($nonInformati.Count) { 'Yellow' } else { 'Green' })

$daMostrare = if ($SoloRischi) {
    @($reportBlocchi | Where-Object { $_.Segnalazioni })
} else {
    @($reportBlocchi | Where-Object { $_.LitigationHold -or $_.AltriBlocchi -gt 0 })
}

if ($daMostrare.Count) {
    Write-Sezione 'Dettaglio'
    $daMostrare |
        Sort-Object -Property @{Expression = { if ($_.Durata -eq 'ILLIMITATA') { 0 } else { 1 } } }, DurataGiorni -Descending |
        Format-Table -AutoSize -Property Casella, Durata, AttivatoIl, UtenteInformato, AltriBlocchi, Segnalazioni
}
else {
    Write-Nota 'Nessun blocco da segnalare.' 'Green'
}

if ($illimitati.Count) {
    Write-Nota "Ogni voce ILLIMITATA e' una conservazione senza termine: va confermata con una" 'Yellow'
    Write-Nota "finalita' dichiarata nell'informativa, oppure sostituita con una durata." 'Yellow'
}

# ---------------------------------------------------------------------------
# SEZIONE B - Caselle inattive
# ---------------------------------------------------------------------------

Write-Titolo 'B) CASELLE INATTIVE (persone che hanno lasciato l''azienda)'

$reportInattive = @()
try {
    $inattive = Get-Mailbox -InactiveMailboxOnly -ResultSize Unlimited -ErrorAction Stop |
        Select-Object DisplayName, PrimarySmtpAddress, WhenSoftDeleted,
                      LitigationHoldEnabled, LitigationHoldDuration, InPlaceHolds

    $oggi = Get-Date

    $reportInattive = foreach ($i in $inattive) {
        $giorni = $null
        if ($i.WhenSoftDeleted) {
            $giorni = [int]($oggi - (Get-Date $i.WhenSoftDeleted)).TotalDays
        }

        $d = $i.LitigationHoldDuration
        $durataTesto = if ($null -eq $d -or "$d" -match 'Unlimited') { 'ILLIMITATA' } else { "$d" }

        [PSCustomObject]@{
            Casella       = $i.PrimarySmtpAddress
            Nome          = $i.DisplayName
            InattivaDal   = if ($i.WhenSoftDeleted) { (Get-Date $i.WhenSoftDeleted -Format 'yyyy-MM-dd') } else { '' }
            GiorniTrascorsi = $giorni
            Durata        = $durataTesto
            AltriBlocchi  = if ($i.InPlaceHolds) { @($i.InPlaceHolds).Count } else { 0 }
        }
    }

    if ($reportInattive.Count) {
        Write-Host ("    Caselle inattive trovate: {0}" -f $reportInattive.Count) -ForegroundColor Yellow
        Write-Sezione 'Dettaglio'
        $reportInattive | Sort-Object GiorniTrascorsi -Descending |
            Format-Table -AutoSize -Property Casella, InattivaDal, GiorniTrascorsi, Durata, AltriBlocchi
        Write-Nota "Ognuna di queste caselle conserva il contenuto di una persona non piu' in" 'Yellow'
        Write-Nota "azienda. Il periodo post-cessazione va deciso e dichiarato, non ereditato." 'Yellow'
    }
    else {
        Write-Nota 'Nessuna casella inattiva.' 'Green'
    }
}
catch {
    Write-Nota "Lettura delle caselle inattive non riuscita: $($_.Exception.Message)" 'Yellow'
}

# ---------------------------------------------------------------------------
# SEZIONE C - Criteri di conservazione Purview
# ---------------------------------------------------------------------------

$reportCriteri = @()

if ($ippsConnessa) {
    Write-Titolo 'C) CRITERI DI CONSERVAZIONE (Microsoft Purview)'

    try {
        $criteri = Get-RetentionCompliancePolicy -ErrorAction Stop
        $regole  = @()
        try { $regole = Get-RetentionComplianceRule -ErrorAction Stop } catch { }

        $reportCriteri = foreach ($c in $criteri) {

            $rr = @($regole | Where-Object { $_.Policy -eq $c.Guid -or $_.Policy -eq $c.Name })

            $durate = @()
            $azioni = @()
            foreach ($r in $rr) {
                if ($r.RetentionDuration) { $durate += "$($r.RetentionDuration)" }
                if ($r.RetentionComplianceAction) { $azioni += "$($r.RetentionComplianceAction)" }
            }

            $ambitoPosta = $false
            if ($c.ExchangeLocation) { $ambitoPosta = @($c.ExchangeLocation).Count -gt 0 }

            [PSCustomObject]@{
                Criterio      = $c.Name
                Abilitato     = $c.Enabled
                Modalita      = $c.Mode
                CopreLaPosta  = $ambitoPosta
                SediExchange  = if ($c.ExchangeLocation) { (@($c.ExchangeLocation) -join ', ') } else { '' }
                DurataGiorni  = ($durate | Sort-Object -Unique) -join ' / '
                AzioneScadenza= ($azioni | Sort-Object -Unique) -join ' / '
                Creato        = if ($c.WhenCreated) { (Get-Date $c.WhenCreated -Format 'yyyy-MM-dd') } else { '' }
            }
        }

        if ($reportCriteri.Count) {
            $postali = @($reportCriteri | Where-Object { $_.CopreLaPosta })
            Write-Host ("    Criteri totali: {0} - di cui sulla posta: {1}" -f $reportCriteri.Count, $postali.Count)
            Write-Sezione 'Dettaglio'
            $reportCriteri | Format-Table -AutoSize -Property Criterio, Abilitato, CopreLaPosta, DurataGiorni, AzioneScadenza, Creato
            Write-Nota "La durata qui configurata e' il numero che deve comparire nell'informativa." 'DarkGray'
        }
        else {
            Write-Nota 'Nessun criterio di conservazione configurato.' 'Yellow'
            Write-Nota "Assenza di criteri non significa assenza di conservazione: verificare la" 'DarkGray'
            Write-Nota "sezione A, dove i blocchi agiscono indipendentemente dai criteri." 'DarkGray'
        }
    }
    catch {
        Write-Nota "Lettura dei criteri non riuscita: $($_.Exception.Message)" 'Yellow'
    }
}

# ---------------------------------------------------------------------------
# SEZIONE D - Conservazione dei registri
# ---------------------------------------------------------------------------

$reportAudit = @()

Write-Titolo 'D) CONSERVAZIONE DEI REGISTRI DI AUDIT'

if ($ippsConnessa) {
    try {
        $policyAudit = Get-UnifiedAuditLogRetentionPolicy -ErrorAction Stop

        $reportAudit = foreach ($p in $policyAudit) {
            [PSCustomObject]@{
                Policy       = $p.Name
                Durata       = "$($p.RetentionDuration)"
                TipiRecord   = if ($p.RecordTypes) { (@($p.RecordTypes) -join ', ') } else { '(tutti)' }
                Priorita     = $p.Priority
                Abilitata    = $p.Enabled
            }
        }

        if ($reportAudit.Count) {
            Write-Host ("    Audit log retention policy personalizzate: {0}" -f $reportAudit.Count)
            Write-Sezione 'Dettaglio'
            $reportAudit | Sort-Object Priorita | Format-Table -AutoSize
        }
        else {
            Write-Nota 'Nessuna policy personalizzata: vale il periodo predefinito del tenant.' 'Yellow'
        }
    }
    catch {
        Write-Nota "Lettura delle policy di audit non riuscita: $($_.Exception.Message)" 'Yellow'
        Write-Nota "Le audit log retention policy richiedono Microsoft Purview Audit (Premium)." 'DarkGray'
    }
}

Write-Sezione 'Limite di conservazione audit per casella (AuditLogAgeLimit)'
$gruppiAudit = $reportBlocchi | Group-Object AuditGiorni | Sort-Object Count -Descending
foreach ($g in $gruppiAudit) {
    $val = if ([string]::IsNullOrWhiteSpace($g.Name)) { '(non impostato)' } else { $g.Name }
    Write-Host ("    {0,-24} {1} caselle" -f $val, $g.Count)
}

Write-Host ''
Write-Nota "Promemoria sui limiti di piano, verificati sulla documentazione Microsoft:" 'DarkGray'
Write-Nota "  - Audit (Standard): 180 giorni predefiniti, non riducibili." 'DarkGray'
Write-Nota "  - Le opzioni da 7 e 30 giorni richiedono Microsoft 365 E5." 'DarkGray'
Write-Nota "  - Il message trace di Exchange Online copre fino a 90 giorni e non e'" 'DarkGray'
Write-Nota "    configurabile dall'amministratore." 'DarkGray'
Write-Nota "Chi resta sopra i 21 giorni indicati dal Garante per i metadati deve poter" 'DarkGray'
Write-Nota "documentare perche' quel periodo e' necessario." 'DarkGray'

# ---------------------------------------------------------------------------
# Esportazione
# ---------------------------------------------------------------------------

if ($EsportaCsv) {
    Write-Titolo 'ESPORTAZIONE'

    if (-not (Test-Path -LiteralPath $EsportaCsv)) {
        New-Item -ItemType Directory -Path $EsportaCsv -Force | Out-Null
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmm'
    $mappa = @(
        @{ Dati = $reportBlocchi;  Nome = "blocchi-caselle-$stamp.csv" }
        @{ Dati = $reportInattive; Nome = "caselle-inattive-$stamp.csv" }
        @{ Dati = $reportCriteri;  Nome = "criteri-conservazione-$stamp.csv" }
        @{ Dati = $reportAudit;    Nome = "policy-audit-$stamp.csv" }
    )

    foreach ($voce in $mappa) {
        if (@($voce.Dati).Count -gt 0) {
            $percorso = Join-Path $EsportaCsv $voce.Nome
            $voce.Dati | Export-Csv -Path $percorso -NoTypeInformation -Encoding UTF8
            Write-Nota "Salvato: $percorso" 'Green'
        }
        else {
            Write-Nota "Saltato (nessun dato): $($voce.Nome)" 'DarkGray'
        }
    }
}

# ---------------------------------------------------------------------------
# Chiusura
# ---------------------------------------------------------------------------

Write-Titolo 'PROSSIMI PASSI'

$azioni = New-Object System.Collections.ArrayList
if ($illimitati.Count) {
    [void]$azioni.Add("Confermare o sostituire i $($illimitati.Count) blocchi a durata illimitata.")
}
if ($reportInattive.Count) {
    [void]$azioni.Add("Decidere e dichiarare il periodo post-cessazione per le $($reportInattive.Count) caselle inattive.")
}
if ($nonInformati.Count) {
    [void]$azioni.Add("Valutare l'informativa per i $($nonInformati.Count) blocchi non comunicati all'utente.")
}
if ($ippsConnessa -and -not $reportCriteri.Count) {
    [void]$azioni.Add('Nessun criterio di conservazione: la durata effettiva dipende solo dai blocchi.')
}

if ($azioni.Count) {
    $n = 1
    foreach ($a in $azioni) {
        Write-Host ("    {0}. {1}" -f $n, $a) -ForegroundColor Yellow
        $n++
    }
}
else {
    Write-Nota 'Nessuna voce da verificare con i parametri correnti.' 'Green'
}

Write-Host ''
Write-Nota 'Criteri di lettura e riferimenti normativi:' 'DarkGray'
Write-Nota 'https://synsphere.it/notizie/conservazione-email-dipendenti-limiti-microsoft-365-pmi' 'DarkGray'
Write-Host ''
Write-Nota 'SynSphere Italia SRL - https://synsphere.it - Nessuna modifica effettuata.' 'DarkGray'
Write-Host ''
