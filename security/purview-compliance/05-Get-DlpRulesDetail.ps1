#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Regole DLP in dettaglio: cosa cercano e cosa fanno quando trovano.
.DESCRIPTION
    Per ogni regola DLP riporta i tipi di informazione sensibile richiamati con il numero di
    occorrenze e il livello di confidenza richiesti, le azioni configurate (blocco, notifica,
    possibilita di override da parte dell'utente) e la severita assegnata all'incidente.
    Serve a capire se una regola e realmente restrittiva o solo dichiarativa. Sola lettura.
    NOTA: una regola disabilitata dentro una policy attiva non produce alcun effetto. Le due
    colonne Disabilitata e ModalitaPolicy vanno lette insieme.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-DlpRules-<data>.csv
.EXAMPLE
    .\05-Get-DlpRulesDetail.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement v3.2.0+, via Connect-IPPSSession
    (Security & Compliance PowerShell).
    ContentContainsSensitiveInformation e una struttura annidata: lo script la appiattisce in
    "nome (conteggio min, confidenza min)".
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-DlpRules-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Oggetto, [string]$Nome)
    if ($null -ne $Oggetto -and ($Oggetto.PSObject.Properties.Name -contains $Nome)) {
        return $Oggetto.$Nome
    }
    return ''
}

# Appiattisce ContentContainsSensitiveInformation, che e un array di hashtable/oggetti
# con chiavi name, mincount, minconfidence (nomi in minuscolo nella struttura Purview).
function Format-SensitiveInfo {
    param($Valore)
    if ($null -eq $Valore) { return '' }
    $voci = @()
    foreach ($v in @($Valore)) {
        $nome = $null; $minCount = $null; $minConf = $null
        if ($v -is [System.Collections.IDictionary]) {
            if ($v.Contains('name')) { $nome = $v['name'] }
            if ($v.Contains('mincount')) { $minCount = $v['mincount'] }
            if ($v.Contains('minconfidence')) { $minConf = $v['minconfidence'] }
        }
        else {
            $nome = Get-Prop $v 'name'
            if ([string]::IsNullOrWhiteSpace([string]$nome)) { $nome = Get-Prop $v 'Name' }
            $minCount = Get-Prop $v 'mincount'
            $minConf = Get-Prop $v 'minconfidence'
        }
        if ([string]::IsNullOrWhiteSpace([string]$nome)) { continue }
        $dettagli = @()
        if (-not [string]::IsNullOrWhiteSpace([string]$minCount)) { $dettagli += ("min " + $minCount) }
        if (-not [string]::IsNullOrWhiteSpace([string]$minConf)) { $dettagli += ("conf " + $minConf) }
        if ($dettagli.Count -gt 0) {
            $voci += ("{0} ({1})" -f $nome, ($dettagli -join ', '))
        }
        else {
            $voci += [string]$nome
        }
    }
    return ($voci -join ' | ')
}

# Connette a Security & Compliance solo se non gia connesso
try {
    $regole = Get-DlpComplianceRule -ErrorAction Stop
}
catch {
    Connect-IPPSSession
    $regole = Get-DlpComplianceRule
}

# Mappa nome policy -> modalita, per dire subito se la regola sta in una policy in test.
$modalitaPolicy = @{}
try {
    foreach ($p in @(Get-DlpCompliancePolicy)) {
        $n = [string](Get-Prop $p 'Name')
        if (-not [string]::IsNullOrWhiteSpace($n)) { $modalitaPolicy[$n] = [string](Get-Prop $p 'Mode') }
    }
}
catch { }

$report = foreach ($r in $regole) {
    $policyNome = [string](Get-Prop $r 'Policy')
    $parentName = [string](Get-Prop $r 'ParentPolicyName')
    if (-not [string]::IsNullOrWhiteSpace($parentName)) { $policyNome = $parentName }

    $mod = ''
    if ($policyNome -and $modalitaPolicy.ContainsKey($policyNome)) { $mod = $modalitaPolicy[$policyNome] }

    [pscustomobject]@{
        Regola            = Get-Prop $r 'Name'
        Policy            = $policyNome
        ModalitaPolicy    = $mod
        Disabilitata      = Get-Prop $r 'Disabled'
        Priorita          = Get-Prop $r 'Priority'
        TipiInfoSensibile = Format-SensitiveInfo (Get-Prop $r 'ContentContainsSensitiveInformation')
        BloccaAccesso     = Get-Prop $r 'BlockAccess'
        TipoBlocco        = Get-Prop $r 'BlockAccessScope'
        NotificaUtente    = ((@(Get-Prop $r 'NotifyUser')) -join '; ')
        OverrideConsentito = Get-Prop $r 'NotifyAllowOverride'
        SeveritaIncidente = Get-Prop $r 'ReportSeverityLevel'
        GenerazioneIncidente = Get-Prop $r 'GenerateIncidentReport'
        Descrizione       = Get-Prop $r 'Comment'
    }
}

$report | Sort-Object Policy, Regola | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$bloccanti = @($report | Where-Object { $_.BloccaAccesso -eq $true -and $_.Disabilitata -ne $true })
Write-Host ("Trovate {0} regole DLP ({1} attive che bloccano l'accesso) -> {2}" -f $report.Count, $bloccanti.Count, $OutputCsv) -ForegroundColor Green
