#Requires -Version 5.1
<#
.SYNOPSIS
    Scarica la Tassonomia Cyber dell'ACN dalla fonte ufficiale e la rende consultabile,
    ricercabile ed esportabile in CSV. Include la validazione di un tag e la generazione
    di una scheda di classificazione da compilare.

.DESCRIPTION
    La Tassonomia Cyber dell'Agenzia per la Cybersicurezza Nazionale (TC-ACN) e' il vocabolario
    comune per descrivere eventi e minacce cyber: 219 valori distribuiti su 21 predicati.
    Oltre che come documento, ACN la pubblica in formato JSON come tassonomia MISP, nel
    repository ufficiale del progetto MISP.

    Questo script NON incorpora la tassonomia: la SCARICA da quel repository a ogni esecuzione.
    Due conseguenze, entrambe volute:
      - i dati sono sempre quelli correnti, senza copie che invecchiano in una cartella;
      - non ridistribuiamo il lavoro dell'ACN, lo leggiamo dalla sua fonte.

    Il formato dei tag e' quello MISP: namespace:predicato="valore", per esempio
    acn:impact="account-compromise".

    Sola lettura: lo script scarica, legge ed esporta. Non modifica nulla sul sistema oltre
    ai file CSV che gli chiedi di scrivere.

.PARAMETER Predicato
    Filtra su un predicato (es. impact, malicious-code, involved-asset, vector).
    Senza questo parametro esporta l'intera tassonomia.

.PARAMETER Cerca
    Cerca un testo fra valori, etichette e descrizioni. Utile per capire come si chiama una
    cosa nel vocabolario ACN: -Cerca ransomware, -Cerca phishing, -Cerca router.

.PARAMETER ValidaTag
    Verifica che un tag esista davvero nella tassonomia ufficiale, es.
    -ValidaTag 'acn:impact="account-compromise"'. Serve a non inventare codici.

.PARAMETER SchedaEvento
    Genera una scheda di classificazione vuota da compilare per un evento, con i predicati
    raggruppati nelle quattro famiglie della tassonomia.

.PARAMETER File
    Percorso di una copia locale del JSON, da usare al posto del download (utile se la
    postazione non ha accesso a internet).

.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\ACN-Tassonomia-<data>.csv

.EXAMPLE
    .\Get-AcnCyberTaxonomy.ps1
    Scarica la tassonomia ed esporta tutti i 219 valori in CSV.

.EXAMPLE
    .\Get-AcnCyberTaxonomy.ps1 -Predicato malicious-code
    Solo i valori del predicato Malicious Code.

.EXAMPLE
    .\Get-AcnCyberTaxonomy.ps1 -Cerca ransomware
    Cerca "ransomware" fra valori, etichette e descrizioni.

.EXAMPLE
    .\Get-AcnCyberTaxonomy.ps1 -ValidaTag 'acn:impact="account-compromise"'
    Verifica che quel tag esista nella tassonomia ufficiale.

.EXAMPLE
    .\Get-AcnCyberTaxonomy.ps1 -SchedaEvento
    Genera una scheda di classificazione vuota da compilare.

.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is", senza garanzia.

    Fonte dei dati: Tassonomia Cyber dell'ACN, pubblicata come tassonomia MISP
    https://github.com/MISP/misp-taxonomies/tree/main/acn
    Documento di riferimento: Agenzia per la Cybersicurezza Nazionale — https://www.acn.gov.it/

    Lo script legge la fonte ufficiale: non sostituisce il documento dell'ACN e non ne
    costituisce una interpretazione autentica.
#>
[CmdletBinding(DefaultParameterSetName = 'Esporta')]
param(
    [Parameter(ParameterSetName = 'Esporta')]
    [string]$Predicato,

    [Parameter(ParameterSetName = 'Esporta')]
    [string]$Cerca,

    [Parameter(ParameterSetName = 'Valida', Mandatory = $true)]
    [string]$ValidaTag,

    [Parameter(ParameterSetName = 'Scheda', Mandatory = $true)]
    [switch]$SchedaEvento,

    [string]$File,

    [string]$OutputCsv
)
$ErrorActionPreference = 'Stop'

$FonteUrl = 'https://raw.githubusercontent.com/MISP/misp-taxonomies/main/acn/machinetag.json'

# Le quattro famiglie della tassonomia. I predicati sono quelli del JSON ufficiale: qui si
# dichiara solo a quale famiglia appartengono, per raggruppare l'output in modo leggibile.
$Famiglie = [ordered]@{
    'Baseline Characterization' = @('impact', 'root-cause', 'severity', 'victim-geography')
    'Threat Type'               = @('active-scanning', 'availability', 'brand-abuse', 'fraud',
                                    'data-exposure', 'information-gathering', 'malicious-code',
                                    'social-engineering', 'vulnerability')
    'Threat Actor'              = @('adversary-motivation', 'adversary-type')
    'Additional Context'        = @('abusive-content', 'asset-source-geography', 'involved-asset',
                                    'outlook', 'physical-security', 'vector')
}

function Get-Famiglia([string]$Pred) {
    foreach ($k in $Famiglie.Keys) { if ($Famiglie[$k] -contains $Pred) { return $k } }
    return '(non classificato)'
}

function Get-Tassonomia {
    if ($File) {
        if (-not (Test-Path $File)) { throw "File non trovato: $File" }
        Write-Host "Leggo la copia locale: $File" -ForegroundColor Cyan
        return (Get-Content -Path $File -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    Write-Host "Scarico la tassonomia dalla fonte ufficiale..." -ForegroundColor Cyan
    try {
        # UseBasicParsing per PowerShell 5.1 senza Internet Explorer configurato.
        $r = Invoke-WebRequest -Uri $FonteUrl -UseBasicParsing -TimeoutSec 60
        return ($r.Content | ConvertFrom-Json)
    } catch {
        throw ("Download non riuscito da {0}: {1}`n" -f $FonteUrl, $_.Exception.Message) +
              "Se la postazione non ha accesso a internet, scarica il file altrove e usa -File."
    }
}

$tax = Get-Tassonomia

# Appiattisco predicati e valori in un unico elenco di righe.
$righe = New-Object System.Collections.Generic.List[object]
foreach ($blocco in $tax.values) {
    $pred = $blocco.predicate
    $etichettaPred = ($tax.predicates | Where-Object { $_.value -eq $pred }).expanded
    foreach ($e in $blocco.entry) {
        $righe.Add([pscustomobject]@{
            Famiglia    = Get-Famiglia $pred
            Predicato   = $pred
            EtichettaPredicato = $etichettaPred
            Valore      = $e.value
            Etichetta   = $e.expanded
            Tag         = ('{0}:{1}="{2}"' -f $tax.namespace, $pred, $e.value)
            Descrizione = ($e.description -replace '\s+', ' ')
        })
    }
}

# Da qui in poi si lavora su un array, non sulla List: in PowerShell 7 l'operatore di
# sottoespressione array `@(...)` applicato a un System.Collections.Generic.List[object]
# solleva "Argument types do not match". La List serve solo a costruire l'elenco in modo
# efficiente; convertirla una volta evita che il difetto ricompaia a ogni `@(...)` a valle.
$righe = $righe.ToArray()

Write-Host ("Tassonomia '{0}' — {1} predicati, {2} valori." -f $tax.namespace, @($tax.predicates).Count, $righe.Count)

# ─────────────────────────────────────────────────────────────────────────────
switch ($PSCmdlet.ParameterSetName) {

    'Valida' {
        # Accetta sia acn:predicato="valore" sia predicato="valore" sia predicato:valore
        $t = $ValidaTag.Trim()
        if ($t -match '^\s*(?:([\w-]+):)?([\w-]+)\s*[=:]\s*"?([^"]+)"?\s*$') {
            $ns   = $Matches[1]
            $pred = $Matches[2]
            $val  = $Matches[3]
        } else {
            Write-Host "Formato non riconosciuto. Atteso: acn:predicato=`"valore`"" -ForegroundColor Red
            return
        }

        if ($ns -and $ns -ne $tax.namespace) {
            Write-Host ("Namespace '{0}' diverso da quello della tassonomia ('{1}')." -f $ns, $tax.namespace) -ForegroundColor Yellow
        }

        $hitPred = $righe | Where-Object { $_.Predicato -eq $pred }
        if (-not $hitPred) {
            Write-Host ("PREDICATO INESISTENTE: '{0}'" -f $pred) -ForegroundColor Red
            $vicini = $righe.Predicato | Select-Object -Unique | Where-Object { $_ -like "*$pred*" }
            if ($vicini) { Write-Host ("  forse intendevi: {0}" -f ($vicini -join ', ')) }
            return
        }

        $hit = $hitPred | Where-Object { $_.Valore -eq $val }
        if ($hit) {
            Write-Host "TAG VALIDO" -ForegroundColor Green
            $hit | Select-Object Famiglia, Predicato, Valore, Etichetta, Tag, Descrizione | Format-List
        } else {
            Write-Host ("VALORE INESISTENTE nel predicato '{0}': '{1}'" -f $pred, $val) -ForegroundColor Red
            $vicini = $hitPred | Where-Object { $_.Valore -like "*$val*" -or $_.Etichetta -like "*$val*" }
            if ($vicini) {
                Write-Host "  valori simili in questo predicato:"
                $vicini | ForEach-Object { Write-Host ("    {0}" -f $_.Tag) }
            } else {
                Write-Host ("  il predicato '{0}' ha {1} valori: usa -Predicato {0} per vederli." -f $pred, @($hitPred).Count)
            }
        }
    }

    'Scheda' {
        if (-not $OutputCsv) { $OutputCsv = ".\ACN-SchedaEvento-{0}.csv" -f (Get-Date -Format 'yyyyMMdd') }
        $scheda = foreach ($k in $Famiglie.Keys) {
            foreach ($p in $Famiglie[$k]) {
                $r = $righe | Where-Object { $_.Predicato -eq $p } | Select-Object -First 1
                if (-not $r) { continue }
                [pscustomobject]@{
                    Famiglia          = $k
                    Predicato         = $p
                    EtichettaPredicato = $r.EtichettaPredicato
                    ValoriDisponibili = (@($righe | Where-Object { $_.Predicato -eq $p }).Count)
                    ValoreScelto      = ''      # <- da compilare
                    TagRisultante     = ''      # <- da compilare, formato acn:predicato="valore"
                    Note              = ''
                }
            }
        }
        $scheda | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
        Write-Host ("Scheda di classificazione generata: {0}" -f $OutputCsv) -ForegroundColor Green
        Write-Host "Compila ValoreScelto per i predicati che descrivono l'evento: non serve"
        Write-Host "riempirli tutti. Per vedere i valori di un predicato:"
        Write-Host "   .\Get-AcnCyberTaxonomy.ps1 -Predicato impact" -ForegroundColor Cyan
    }

    default {
        $sel = $righe
        if ($Predicato) {
            $sel = $sel | Where-Object { $_.Predicato -eq $Predicato }
            if (-not $sel) {
                Write-Host ("Predicato '{0}' inesistente. Quelli disponibili:" -f $Predicato) -ForegroundColor Red
                $righe.Predicato | Select-Object -Unique | Sort-Object | ForEach-Object { Write-Host ("   {0}" -f $_) }
                return
            }
        }
        if ($Cerca) {
            $sel = $sel | Where-Object {
                $_.Valore -like "*$Cerca*" -or $_.Etichetta -like "*$Cerca*" -or $_.Descrizione -like "*$Cerca*"
            }
            Write-Host ("Ricerca '{0}': {1} risultati." -f $Cerca, @($sel).Count)
        }

        # Confronto esplicito, non `-not @($sel).Count`: senza filtri $sel e' ancora la
        # List[object] di partenza, dopo un Where-Object diventa un array, e su quella
        # differenza di tipo la forma con -not solleva "Argument types do not match".
        if (@($sel).Count -eq 0) { Write-Host "Nessun risultato."; return }

        if (-not $OutputCsv) { $OutputCsv = ".\ACN-Tassonomia-{0}.csv" -f (Get-Date -Format 'yyyyMMdd') }
        $sel | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

        if ($Predicato -or $Cerca) {
            $sel | Select-Object Tag, Etichetta | Format-Table -AutoSize
        } else {
            Write-Host ""
            $righe | Group-Object Famiglia | Sort-Object Name | ForEach-Object {
                Write-Host ("  {0,-28} {1,3} valori" -f $_.Name, $_.Count)
            }
        }
        Write-Host ("Esportato in {0}" -f $OutputCsv) -ForegroundColor Green
    }
}
