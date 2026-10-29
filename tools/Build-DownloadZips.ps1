#Requires -Version 5.1
<#
.SYNOPSIS
    Rigenera gli ZIP e gli .ps1 serviti da synsphere.it/download a partire da
    questo repository.

.DESCRIPTION
    Questo repository e' la FONTE DI VERITA' degli script. Il sito ne distribuisce
    una copia confezionata: questo script la ricostruisce, cosi' le due superfici
    non possono divergere in silenzio.

    Il problema che risolve e' reale e lo abbiamo gia' avuto: lo stesso script
    esisteva in tre copie (scripts/assets, delega-kit, public/download) che
    potevano differire senza che nessun controllo lo notasse.

    Per ogni toolkit dichiarato in tools/mappa-download.json:
      - crea lo ZIP con gli .ps1 della cartella, in ordine di nome;
      - genera 00-LEGGIMI.txt convertendo il README.md della cartella in testo
        semplice (chi scarica lo ZIP non deve incontrare la sintassi markdown);
      - copia, se dichiarato, lo script singolo pubblicato come .ps1 nudo.

    Non cancella nulla nella destinazione: scrive solo i file che dichiara.

.PARAMETER Destinazione
    Cartella public/download del sito. Default: il percorso relativo dichiarato
    in mappa-download.json, risolto rispetto alla radice del repository.

.PARAMETER WhatIf
    Mostra cosa verrebbe scritto senza scrivere niente.

.EXAMPLE
    .\tools\Build-DownloadZips.ps1 -WhatIf
    Elenca gli ZIP che verrebbero rigenerati e le loro dimensioni.

.EXAMPLE
    .\tools\Build-DownloadZips.ps1
    Rigenera tutto nella cartella public/download del sito.

.NOTES
    SynSphere Italia - https://synsphere.it
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Destinazione
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$radice = Split-Path -Parent $PSScriptRoot
$mappaPath = Join-Path $PSScriptRoot 'mappa-download.json'
if (-not (Test-Path $mappaPath)) { throw "Mappa non trovata: $mappaPath" }
$mappa = Get-Content $mappaPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $Destinazione) {
    $Destinazione = Join-Path $radice $mappa._destinazione
}
$Destinazione = [System.IO.Path]::GetFullPath($Destinazione)
if (-not (Test-Path $Destinazione)) {
    throw "Destinazione inesistente: $Destinazione`nPassa -Destinazione con il percorso di public/download del sito."
}
Write-Host "Destinazione: $Destinazione" -ForegroundColor Cyan
Write-Host ""

function ConvertTo-TestoSemplice {
    <# Riduce un README.md a testo leggibile in Blocco note. Non e' un
       renderer markdown completo: toglie la sintassi che darebbe fastidio
       e lascia il resto intatto. #>
    param([string]$Markdown)
    $righe = $Markdown -split "`r?`n"
    $out = foreach ($r in $righe) {
        $t = $r
        $t = $t -replace '^\s*#{1,6}\s*', ''              # titoli
        $t = $t -replace '\*\*([^*]+)\*\*', '$1'          # grassetto
        $t = $t -replace '(?<!\*)\*([^*]+)\*(?!\*)', '$1' # corsivo
        $t = $t -replace '`([^`]+)`', '$1'                # codice inline
        $t = $t -replace '\[([^\]]+)\]\(([^)]+)\)', '$1 ($2)'  # link
        $t = $t -replace '^\s*[-*]\s+', '  - '            # elenchi
        $t = $t -replace '^\s*\|', '  |'                  # tabelle
        $t
    }
    ($out -join "`r`n").TrimEnd() + "`r`n"
}

$fatti = 0; $saltati = 0; $errori = @()
$riepilogo = @()

foreach ($t in $mappa.toolkit) {
    $cartella = Join-Path $radice ($t.cartella -replace '/', '\')
    if (-not (Test-Path $cartella)) {
        $errori += "cartella mancante: $($t.cartella)"
        continue
    }

    $script = @(Get-ChildItem $cartella -Filter *.ps1 -File | Sort-Object Name)
    if ($script.Count -eq 0) {
        $errori += "nessuno script in: $($t.cartella)"
        continue
    }

    # ── lo ZIP ────────────────────────────────────────────────────────────
    if ($t.zip) {
        $zipPath = Join-Path $Destinazione $t.zip
        if ($PSCmdlet.ShouldProcess($t.zip, "rigenera ZIP da $($t.cartella)")) {
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("szkit-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $tmp -Force | Out-Null
            try {
                # il LEGGIMI, generato dal README
                $readme = Join-Path $cartella 'README.md'
                if (Test-Path $readme) {
                    $testo = ConvertTo-TestoSemplice (Get-Content $readme -Raw -Encoding UTF8)
                    [System.IO.File]::WriteAllText(
                        (Join-Path $tmp '00-LEGGIMI.txt'), $testo,
                        (New-Object System.Text.UTF8Encoding $false))
                }
                foreach ($s in $script) { Copy-Item $s.FullName -Destination $tmp }

                if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
                [System.IO.Compression.ZipFile]::CreateFromDirectory(
                    $tmp, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
                $dim = (Get-Item $zipPath).Length
                $riepilogo += [pscustomobject]@{
                    Cartella = $t.cartella; File = $t.zip
                    Script = $script.Count; Byte = $dim
                }
                $fatti++
            } finally {
                Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
            }
        } else { $saltati++ }
    }

    # ── lo script singolo pubblicato nudo ─────────────────────────────────
    if ($t.ps1Pubblicato) {
        # quando la cartella ha piu' script, il pubblicato e' il primo per nome
        # che NON sia un file di soli esempi
        $principale = @($script | Where-Object { $_.BaseName -notmatch '^(Esempi|Examples)$' })[0]
        $destPs1 = Join-Path $Destinazione $t.ps1Pubblicato
        if ($PSCmdlet.ShouldProcess($t.ps1Pubblicato, "copia da $($principale.Name)")) {
            Copy-Item $principale.FullName -Destination $destPs1 -Force
            $riepilogo += [pscustomobject]@{
                Cartella = $t.cartella; File = $t.ps1Pubblicato
                Script = 1; Byte = (Get-Item $destPs1).Length
            }
            $fatti++
        } else { $saltati++ }
    }
}

Write-Host ""
$riepilogo | Format-Table Cartella, File, Script, Byte -AutoSize | Out-String -Width 160 | Write-Host

Write-Host ("Generati: {0}   Simulati: {1}   Errori: {2}" -f $fatti, $saltati, $errori.Count) -ForegroundColor $(if ($errori) { 'Red' } else { 'Green' })
foreach ($e in $errori) { Write-Warning $e }
if ($errori) { exit 1 }

# ── controprova: il conto degli script deve tornare ───────────────────────
# In -WhatIf non viene costruito nulla, quindi $riepilogo e' vuoto e il
# confronto direbbe "247 script non distribuiti": un allarme falso, che e'
# peggio di nessun allarme. Il controllo si fa solo su una corsa vera.
if ($fatti -gt 0) {
    $totRepo = @(Get-ChildItem $radice -Recurse -Filter *.ps1 -File |
        Where-Object { $_.FullName -notmatch '\\tools\\|\\\.github\\' }).Count
    $totMappa = [int](($riepilogo | Where-Object { $_.File -like '*.zip' } |
        Measure-Object Script -Sum).Sum)
    # gli script distribuiti SOLO come .ps1 nudo non stanno in nessuno ZIP:
    # sono previsti, e vanno sottratti prima di gridare alla divergenza
    $soloNudi = @($mappa.toolkit | Where-Object { -not $_.zip -and $_.ps1Pubblicato })
    $attesiFuoriZip = 0
    foreach ($n in $soloNudi) {
        $c = Join-Path $radice ($n.cartella -replace '/', '\')
        $attesiFuoriZip += @(Get-ChildItem $c -Filter *.ps1 -File).Count
    }
    Write-Host ""
    Write-Host ("Script .ps1 nel repository (esclusi tools/): {0}" -f $totRepo)
    Write-Host ("Script finiti negli ZIP:                     {0}" -f $totMappa)
    Write-Host ("Distribuiti solo come .ps1 nudo:             {0}" -f $attesiFuoriZip)
    $scoperti = $totRepo - $totMappa - $attesiFuoriZip
    if ($scoperti -ne 0) {
        Write-Warning ("{0} script non sono distribuiti da nessuna parte: un toolkit " -f $scoperti +
                       "manca da tools/mappa-download.json, oppure la mappa punta a una cartella sbagliata.")
    } else {
        Write-Host "Ogni script del repository e' distribuito." -ForegroundColor Green
    }
}
