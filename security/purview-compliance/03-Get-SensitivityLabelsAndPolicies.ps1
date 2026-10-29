#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Etichette di riservatezza e verifica di quali sono davvero pubblicate.
.DESCRIPTION
    Elenca le etichette di riservatezza (sensitivity label) e le confronta con le policy di
    pubblicazione, segnalando quelle che esistono ma non sono incluse in nessuna policy.
    E' la distinzione che conta: un'etichetta non pubblicata non arriva a nessun utente, non
    compare nelle applicazioni Office e non protegge nulla — ma nell'elenco delle etichette
    c'e, col suo nome e il suo colore. Sola lettura.
    NOTA: un'etichetta disabilitata resta visibile nell'elenco: leggere sempre la colonna
    Disabilitata insieme a Pubblicata.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-SensitivityLabels-<data>.csv
.EXAMPLE
    .\03-Get-SensitivityLabelsAndPolicies.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement v3.2.0+, via Connect-IPPSSession
    (Security & Compliance PowerShell).
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-SensitivityLabels-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Oggetto, [string]$Nome)
    if ($null -ne $Oggetto -and ($Oggetto.PSObject.Properties.Name -contains $Nome)) {
        return $Oggetto.$Nome
    }
    return ''
}

function Format-Elenco {
    param($Valore)
    if ($null -eq $Valore) { return '' }
    $nomi = @()
    foreach ($v in @($Valore)) {
        $n = Get-Prop $v 'DisplayName'
        if ([string]::IsNullOrWhiteSpace($n)) { $n = [string]$v }
        if (-not [string]::IsNullOrWhiteSpace($n)) { $nomi += $n }
    }
    return ($nomi -join '; ')
}

# Connette a Security & Compliance solo se non gia connesso
try {
    $etichette = Get-Label -ErrorAction Stop
}
catch {
    Connect-IPPSSession
    $etichette = Get-Label
}

$policy = @()
try { $policy = @(Get-LabelPolicy) } catch { $policy = @() }

# Costruisce l'insieme dei nomi/GUID di etichetta referenziati da almeno una policy.
$pubblicate = @{}
foreach ($p in $policy) {
    foreach ($l in @(Get-Prop $p 'Labels')) {
        $chiave = [string]$l
        if (-not [string]::IsNullOrWhiteSpace($chiave)) { $pubblicate[$chiave] = $true }
    }
}

$report = foreach ($e in $etichette) {
    $nome = [string](Get-Prop $e 'Name')
    $guid = [string](Get-Prop $e 'Guid')
    $isPub = $pubblicate.ContainsKey($nome) -or ($guid -and $pubblicate.ContainsKey($guid))

    # Quali policy la pubblicano
    $vieneDa = @()
    foreach ($p in $policy) {
        foreach ($l in @(Get-Prop $p 'Labels')) {
            $c = [string]$l
            if ($c -eq $nome -or ($guid -and $c -eq $guid)) {
                $vieneDa += [string](Get-Prop $p 'Name')
                break
            }
        }
    }

    [pscustomobject]@{
        Etichetta        = $nome
        NomeVisualizzato = Get-Prop $e 'DisplayName'
        Pubblicata       = $isPub
        PolicyChePubblicano = ($vieneDa | Select-Object -Unique) -join '; '
        Disabilitata     = Get-Prop $e 'Disabled'
        Priorita         = Get-Prop $e 'Priority'
        TipoContenuto    = Format-Elenco (Get-Prop $e 'ContentType')
        Descrizione      = Get-Prop $e 'Tooltip'
        Creata           = Get-Prop $e 'WhenCreated'
        Modificata       = Get-Prop $e 'WhenChanged'
    }
}

$report | Sort-Object Etichetta | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$nonPub = @($report | Where-Object { $_.Pubblicata -ne $true })
Write-Host ("Trovate {0} etichette di riservatezza, {1} policy di pubblicazione -> {2}" -f $report.Count, $policy.Count, $OutputCsv) -ForegroundColor Green
if ($nonPub.Count -gt 0) {
    Write-Host ("ATTENZIONE: {0} etichette NON sono in alcuna policy di pubblicazione e non proteggono nulla:" -f $nonPub.Count) -ForegroundColor Yellow
    foreach ($n in $nonPub) { Write-Host ("  - " + $n.Etichetta) -ForegroundColor Yellow }
}
