#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Inventario delle ricerche di conformita (eDiscovery) presenti nel tenant.
.DESCRIPTION
    Elenca le ricerche di conformita create nel tenant con stato, autore, data e perimetro
    interrogato. Serve a due cose concrete: sapere cosa e gia stato oggetto di indagine
    prima di ripartire da zero alla prossima richiesta legale, e accorgersi delle ricerche
    dimenticate — una ricerca vecchia con la sua query resta un indizio di quali dati sono
    stati cercati e da chi. Sola lettura: lo script non avvia, non modifica e non esporta
    alcuna ricerca.
    NOTA: la query di ricerca (ContentMatchQuery) puo contenere nomi di persone o termini
    sensibili. Il CSV prodotto va trattato come documento riservato.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-ComplianceSearches-<data>.csv
.EXAMPLE
    .\09-Get-ComplianceSearchInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement v3.2.0+, via Connect-IPPSSession
    (Security & Compliance PowerShell).
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-ComplianceSearches-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Oggetto, [string]$Nome)
    if ($null -ne $Oggetto -and ($Oggetto.PSObject.Properties.Name -contains $Nome)) {
        return $Oggetto.$Nome
    }
    return ''
}

function Format-Location {
    param($Valore)
    if ($null -eq $Valore) { return '' }
    $nomi = @()
    foreach ($v in @($Valore)) {
        $n = [string]$v
        if (-not [string]::IsNullOrWhiteSpace($n)) { $nomi += $n }
    }
    $testo = ($nomi -join '; ')
    # Tronca elenchi molto lunghi (una ricerca "tutto il tenant" produce righe illeggibili)
    if ($testo.Length -gt 300) { return $testo.Substring(0, 300) + '… (' + $nomi.Count + ' voci)' }
    return $testo
}

# Connette a Security & Compliance solo se non gia connesso
try {
    $ricerche = Get-ComplianceSearch -ErrorAction Stop
}
catch {
    Connect-IPPSSession
    $ricerche = Get-ComplianceSearch
}

$report = foreach ($r in $ricerche) {
    $creata = Get-Prop $r 'CreatedTime'
    $giorni = ''
    if ($creata -is [datetime]) { $giorni = [int]((Get-Date) - $creata).TotalDays }

    [pscustomobject]@{
        Nome           = Get-Prop $r 'Name'
        Stato          = Get-Prop $r 'Status'
        CreataDa       = Get-Prop $r 'CreatedBy'
        CreataIl       = $creata
        GiorniDaCreazione = $giorni
        FineElaborazione = Get-Prop $r 'JobEndTime'
        ElementiTrovati = Get-Prop $r 'Items'
        Query          = Get-Prop $r 'ContentMatchQuery'
        Exchange       = Format-Location (Get-Prop $r 'ExchangeLocation')
        SharePoint     = Format-Location (Get-Prop $r 'SharePointLocation')
        Descrizione    = Get-Prop $r 'Description'
    }
}

$report | Sort-Object CreataIl -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ("Trovate {0} ricerche di conformita -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
if ($report.Count -gt 0) {
    Write-Host "Ripartizione per stato:" -ForegroundColor Cyan
    $report | Group-Object Stato | Sort-Object Count -Descending | ForEach-Object {
        $etichetta = $_.Name
        if ([string]::IsNullOrWhiteSpace($etichetta)) { $etichetta = '(stato non indicato)' }
        Write-Host ("  {0,5}  {1}" -f $_.Count, $etichetta)
    }
    Write-Host "Il CSV contiene le query di ricerca: trattalo come documento riservato." -ForegroundColor Yellow
}
