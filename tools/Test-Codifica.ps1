#Requires -Version 5.1
<#
.SYNOPSIS
    Verifica che ogni script del repository sia UTF-8 CON BOM e con fine-riga LF.

.DESCRIPTION
    Non e' pedanteria di stile: e' una guardia contro un difetto funzionale che
    abbiamo gia' avuto in produzione.

    Windows PowerShell 5.1 legge un file privo di BOM usando la code page ANSI.
    Un file UTF-8 senza BOM che contiene accenti italiani stampa mojibake:

        senza BOM  ->  "FullAccess: giA  presente, salto."
        con BOM    ->  "FullAccess: gia presente, salto."

    Misurato su PowerShell 5.1.26100 contro PowerShell 7.5.4: PowerShell 7 non
    e' sensibile al BOM, 5.1 si'. Siccome i prerequisiti dichiarano "PowerShell
    5.1+", la regola vale per tutti i file e non solo per quelli che oggi hanno
    un accento: il giorno in cui qualcuno ne aggiunge uno a un file senza BOM,
    nessuno se ne accorge. Il controllo sostituisce la memoria di chi scrive.

    Verifica anche i fine-riga: il repository e' interamente LF e deve restarlo.
    Una conversione a CRLF non rompe niente a runtime, ma riscrive ogni riga di
    ogni file e rende illeggibile il diff — cioe' toglie l'unico strumento che
    puo' provare che una modifica e' soltanto quella dichiarata.

.PARAMETER Correggi
    Invece di limitarsi a segnalare, aggiunge il BOM mancante. I fine-riga non
    vengono mai toccati.

.EXAMPLE
    .\tools\Test-Codifica.ps1
    Elenca i file non conformi ed esce con codice 1 se ce n'e' almeno uno.

.EXAMPLE
    .\tools\Test-Codifica.ps1 -Correggi
    Aggiunge il BOM ai file che ne sono privi.

.NOTES
    SynSphere Italia - https://synsphere.it
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Correggi
)

$ErrorActionPreference = 'Stop'
$radice = Split-Path -Parent $PSScriptRoot
$BOM = [byte[]](0xEF, 0xBB, 0xBF)

$file = @(Get-ChildItem $radice -Recurse -File -Include *.ps1, *.psm1, *.psd1 |
    Where-Object { $_.FullName -notmatch '\\\.git\\' })

Write-Host ("Script esaminati: {0}" -f $file.Count) -ForegroundColor Cyan

$senzaBom = @(); $conCrlf = @(); $nonUtf8 = @()

foreach ($f in $file) {
    $b = [System.IO.File]::ReadAllBytes($f.FullName)
    $rel = $f.FullName.Substring($radice.Length).TrimStart('\')

    $haBom = $b.Length -ge 3 -and $b[0] -eq $BOM[0] -and $b[1] -eq $BOM[1] -and $b[2] -eq $BOM[2]
    if (-not $haBom) { $senzaBom += $rel }

    # UTF-8 valido? (decodifica stretta: un byte invalido solleva)
    try {
        $utf8Stretto = New-Object System.Text.UTF8Encoding $false, $true
        [void]$utf8Stretto.GetString($b)
    } catch {
        $nonUtf8 += $rel
    }

    $nCrlf = 0
    for ($i = 1; $i -lt $b.Length; $i++) {
        if ($b[$i] -eq 10 -and $b[$i - 1] -eq 13) { $nCrlf++ }
    }
    if ($nCrlf -gt 0) { $conCrlf += ("{0} ({1} righe CRLF)" -f $rel, $nCrlf) }
}

Write-Host ""
Write-Host ("UTF-8 non valido : {0}" -f $nonUtf8.Count)
Write-Host ("Senza BOM        : {0}" -f $senzaBom.Count)
Write-Host ("Con fine-riga CRLF: {0}" -f $conCrlf.Count)

foreach ($x in $nonUtf8) { Write-Host ("   NON UTF-8  {0}" -f $x) -ForegroundColor Red }
foreach ($x in $senzaBom | Select-Object -First 40) { Write-Host ("   senza BOM  {0}" -f $x) -ForegroundColor Yellow }
if ($senzaBom.Count -gt 40) { Write-Host ("   ... e altri {0}" -f ($senzaBom.Count - 40)) }
foreach ($x in $conCrlf | Select-Object -First 40) { Write-Host ("   CRLF       {0}" -f $x) -ForegroundColor Yellow }

if ($Correggi -and $senzaBom.Count -gt 0) {
    Write-Host ""
    $n = 0
    foreach ($rel in $senzaBom) {
        $p = Join-Path $radice $rel
        if ($PSCmdlet.ShouldProcess($rel, 'aggiungi BOM UTF-8')) {
            $b = [System.IO.File]::ReadAllBytes($p)
            [System.IO.File]::WriteAllBytes($p, ($BOM + $b))
            # controprova immediata: il contenuto oltre il BOM deve essere identico
            $dopo = [System.IO.File]::ReadAllBytes($p)
            if ($dopo.Length -ne $b.Length + 3) { throw "Scrittura non attesa su $rel" }
            $n++
        }
    }
    Write-Host ("BOM aggiunto a {0} file." -f $n) -ForegroundColor Green
    Write-Host "Rilancia senza -Correggi per la verifica." -ForegroundColor Green
    exit 0
}

# ── i Markdown: regola OPPOSTA, e va detto perche' ────────────────────────
# Gli .md NON devono avere il BOM: GitHub li serve come UTF-8 e un BOM in
# testa puo' comparire come carattere invisibile nella prima riga. Devono
# pero' essere UTF-8 validi, LF, e senza mojibake.
#
# Eccezione sul mojibake: i README spiegano il difetto di PowerShell 5.1
# mostrando come si vede ("perchA©"), e quell'esempio sta fra apici inversi.
# Il controllo ignora il codice inline, altrimenti segnala l'unico posto in
# cui la sequenza e' voluta.
$md = @(Get-ChildItem $radice -Recurse -File -Filter *.md |
    Where-Object { $_.FullName -notmatch '\\\.git\\' })

$mdBom = @(); $mdCrlf = @(); $mdMoji = @(); $mdNonUtf8 = @()
$spie = @(
    [string][char]0x00C3 + [char]0x00A8   # A-tilde + dieresi: "e" accentata letta come ANSI
    [string][char]0x00C3 + [char]0x00A9
    [string][char]0x00C3 + [char]0x00B9
    [string][char]0x00C3 + [char]0x00B2
    [string][char]0x00E2 + [char]0x0080 + [char]0x0099
)

foreach ($f in $md) {
    $b = [System.IO.File]::ReadAllBytes($f.FullName)
    $rel = $f.FullName.Substring($radice.Length).TrimStart('\')
    if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { $mdBom += $rel }
    try {
        $u = New-Object System.Text.UTF8Encoding $false, $true
        $t = $u.GetString($b)
    } catch { $mdNonUtf8 += $rel; continue }
    if ($t -match "`r`n") { $mdCrlf += $rel }
    # via il codice inline e i blocchi recintati, poi cerco le spie
    $senzaCodice = [regex]::Replace($t, '(?s)```.*?```', ' ')
    $senzaCodice = [regex]::Replace($senzaCodice, '`[^`]*`', ' ')
    foreach ($s in $spie) { if ($senzaCodice.Contains($s)) { $mdMoji += "$rel ($s)"; break } }
}

Write-Host ""
Write-Host ("Markdown esaminati: {0}" -f $md.Count) -ForegroundColor Cyan
Write-Host ("   con BOM (non devono averlo): {0}" -f $mdBom.Count)
Write-Host ("   con CRLF                   : {0}" -f $mdCrlf.Count)
Write-Host ("   UTF-8 non valido           : {0}" -f $mdNonUtf8.Count)
Write-Host ("   con mojibake (fuori dal codice): {0}" -f $mdMoji.Count)
foreach ($x in $mdBom + $mdCrlf + $mdNonUtf8 + $mdMoji) { Write-Host ("   $x") -ForegroundColor Yellow }

if ($nonUtf8.Count -or $senzaBom.Count -or $conCrlf.Count -or
    $mdBom.Count -or $mdCrlf.Count -or $mdNonUtf8.Count -or $mdMoji.Count) {
    Write-Host ""
    Write-Host "NON CONFORME." -ForegroundColor Red
    Write-Host "  Script senza BOM: .\tools\Test-Codifica.ps1 -Correggi" -ForegroundColor Red
    Write-Host "  Markdown con BOM, o fine-riga CRLF: vanno corretti a mano, non li tocco io." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host ("Conforme: {0}/{0} script UTF-8 CON BOM, {1}/{1} Markdown UTF-8 SENZA BOM, tutti LF." -f $file.Count, $md.Count) -ForegroundColor Green
