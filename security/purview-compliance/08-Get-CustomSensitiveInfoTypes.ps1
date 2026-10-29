#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Tipi di informazione sensibile personalizzati, e quali sono davvero usati.
.DESCRIPTION
    Elenca i tipi di informazione sensibile definiti nell'organizzazione raggruppandoli per
    editore, cosi da separare quelli creati internamente dalle centinaia predefinite fornite
    da Microsoft. Per ognuno indica se e referenziato da almeno una regola DLP: un tipo
    personalizzato che nessuna regola richiama e lavoro di configurazione che non produce
    alcun effetto. Sola lettura.
    NOTA: la proprieta che identifica l'editore non e documentata nella pagina del cmdlet.
    Per questo lo script la RIPORTA in colonna invece di filtrare su un valore atteso: un
    filtro cablato rischierebbe di restituire un elenco vuoto per una semplice differenza di
    stringa, facendo sembrare che non esistano tipi personalizzati.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-SensitiveInfoTypes-<data>.csv
.PARAMETER SoloNonMicrosoft
    Se presente, esporta solo i tipi il cui editore non contiene "Microsoft".
.EXAMPLE
    .\08-Get-CustomSensitiveInfoTypes.ps1
.EXAMPLE
    .\08-Get-CustomSensitiveInfoTypes.ps1 -SoloNonMicrosoft
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement v3.2.0+, via Connect-IPPSSession
    (Security & Compliance PowerShell).
    RecommendedConfidence e il livello di confidenza consigliato da usare nelle regole.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-SensitiveInfoTypes-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')),
    [switch]$SoloNonMicrosoft
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
    $tipi = Get-DlpSensitiveInformationType -ErrorAction Stop
}
catch {
    Connect-IPPSSession
    $tipi = Get-DlpSensitiveInformationType
}

# Raccoglie i nomi di tipo richiamati dalle regole DLP, per dire quali sono in uso.
$inUso = @{}
try {
    foreach ($r in @(Get-DlpComplianceRule)) {
        foreach ($v in @(Get-Prop $r 'ContentContainsSensitiveInformation')) {
            $nome = $null
            if ($v -is [System.Collections.IDictionary]) {
                if ($v.Contains('name')) { $nome = [string]$v['name'] }
            }
            else {
                $nome = [string](Get-Prop $v 'name')
                if ([string]::IsNullOrWhiteSpace($nome)) { $nome = [string](Get-Prop $v 'Name') }
            }
            if (-not [string]::IsNullOrWhiteSpace($nome)) { $inUso[$nome] = $true }
        }
    }
}
catch { }

$report = foreach ($t in $tipi) {
    $nome = [string](Get-Prop $t 'Name')
    $id = [string](Get-Prop $t 'Id')
    [pscustomobject]@{
        Nome                 = $nome
        Editore              = Get-Prop $t 'Publisher'
        UsatoDaRegoleDlp     = ($inUso.ContainsKey($nome) -or ($id -and $inUso.ContainsKey($id)))
        ConfidenzaConsigliata = Get-Prop $t 'RecommendedConfidence'
        Descrizione          = Get-Prop $t 'Description'
        Id                   = $id
    }
}

$daEsportare = $report
if ($SoloNonMicrosoft) {
    $daEsportare = @($report | Where-Object { [string]$_.Editore -notlike '*Microsoft*' })
}

$daEsportare | Sort-Object Editore, Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host ("Tipi di informazione sensibile totali: {0}" -f $report.Count) -ForegroundColor Cyan
Write-Host "Raggruppamento per editore:" -ForegroundColor Cyan
$report | Group-Object Editore | Sort-Object Count -Descending | ForEach-Object {
    $etichetta = $_.Name
    if ([string]::IsNullOrWhiteSpace($etichetta)) { $etichetta = '(editore non indicato)' }
    Write-Host ("  {0,5}  {1}" -f $_.Count, $etichetta)
}

$nonMs = @($report | Where-Object { [string]$_.Editore -notlike '*Microsoft*' })
$orfani = @($nonMs | Where-Object { $_.UsatoDaRegoleDlp -ne $true })
Write-Host ""
Write-Host ("Tipi non Microsoft: {0}, di cui NON richiamati da alcuna regola DLP: {1}" -f $nonMs.Count, $orfani.Count) -ForegroundColor Yellow
foreach ($o in $orfani) { Write-Host ("  - " + $o.Nome) -ForegroundColor Yellow }
Write-Host ("-> {0}" -f $OutputCsv) -ForegroundColor Green
