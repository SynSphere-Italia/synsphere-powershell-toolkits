#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Le policy DLP mai promosse da simulazione a produzione.
.DESCRIPTION
    Isola le policy DLP che non stanno proteggendo nulla: quelle in modalita di test
    (simulazione, con o senza notifiche) e quelle disabilitate. Attivare una policy in test
    per misurarne l'impatto e la pratica corretta; il problema e che la promozione in
    produzione e un passaggio manuale che spesso nessuno esegue, e una policy in test
    registra gli eventi senza impedire niente. E' lo scarto piu frequente fra compliance
    dichiarata e compliance reale. Sola lettura.
    NOTA: la classificazione avviene sul prefisso del valore di Mode (Test*) e non su un
    elenco cablato di valori, perche i valori possibili non sono documentati sulla pagina
    del cmdlet e sono cambiati nel tempo. Il valore grezzo resta nella colonna Modalita.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-DlpTestMode-<data>.csv
.PARAMETER SoloProblemi
    Se presente, esporta solo le policy che non proteggono (test o disabilitate).
.EXAMPLE
    .\06-Get-DlpPoliciesInTestMode.ps1
.EXAMPLE
    .\06-Get-DlpPoliciesInTestMode.ps1 -SoloProblemi
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement v3.2.0+, via Connect-IPPSSession
    (Security & Compliance PowerShell).
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-DlpTestMode-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')),
    [switch]$SoloProblemi
)
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Oggetto, [string]$Nome)
    if ($null -ne $Oggetto -and ($Oggetto.PSObject.Properties.Name -contains $Nome)) {
        return $Oggetto.$Nome
    }
    return ''
}

# Connette a Security & Compliance solo se non gia connesso
try {
    $policies = Get-DlpCompliancePolicy -ErrorAction Stop
}
catch {
    Connect-IPPSSession
    $policies = Get-DlpCompliancePolicy
}

$report = foreach ($p in $policies) {
    $modalita = [string](Get-Prop $p 'Mode')
    $abilitata = Get-Prop $p 'Enabled'
    $inTest = $modalita -like 'Test*'
    $spenta = ($abilitata -eq $false) -or ($modalita -like 'Disable*')

    if ($inTest) { $stato = 'In simulazione: non blocca' }
    elseif ($spenta) { $stato = 'Disabilitata: non agisce' }
    else { $stato = 'In produzione' }

    $modificata = Get-Prop $p 'WhenChanged'
    $giorni = ''
    if ($modificata -is [datetime]) {
        $giorni = [int]((Get-Date) - $modificata).TotalDays
    }

    [pscustomobject]@{
        Nome              = Get-Prop $p 'Name'
        Stato             = $stato
        Protegge         = (-not $inTest -and -not $spenta)
        Modalita          = $modalita
        Abilitata         = $abilitata
        Creata            = Get-Prop $p 'WhenCreated'
        Modificata        = $modificata
        GiorniDaModifica  = $giorni
        Descrizione       = Get-Prop $p 'Comment'
    }
}

$daEsportare = $report
if ($SoloProblemi) {
    $daEsportare = @($report | Where-Object { $_.Protegge -ne $true })
}

$daEsportare | Sort-Object Stato, Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$test = @($report | Where-Object { $_.Stato -like 'In simulazione*' })
$off = @($report | Where-Object { $_.Stato -like 'Disabilitata*' })
$prod = @($report | Where-Object { $_.Protegge -eq $true })

Write-Host ""
Write-Host ("Policy DLP totali: {0}" -f $report.Count) -ForegroundColor Cyan
Write-Host ("  in produzione     : {0}" -f $prod.Count) -ForegroundColor Green
Write-Host ("  in simulazione    : {0}" -f $test.Count) -ForegroundColor Yellow
Write-Host ("  disabilitate      : {0}" -f $off.Count) -ForegroundColor Yellow
Write-Host ""

foreach ($t in ($test + $off)) {
    $eta = ''
    if (-not [string]::IsNullOrWhiteSpace([string]$t.GiorniDaModifica)) {
        $eta = (" — ultima modifica {0} giorni fa" -f $t.GiorniDaModifica)
    }
    Write-Host ("  [{0}] {1}{2}" -f $t.Modalita, $t.Nome, $eta) -ForegroundColor Yellow
}

Write-Host ""
Write-Host ("-> {0}" -f $OutputCsv) -ForegroundColor Green
if ($report.Count -gt 0 -and $prod.Count -eq 0) {
    Write-Host "ATTENZIONE: nessuna policy DLP e in produzione. Nessun contenuto viene bloccato." -ForegroundColor Red
}
