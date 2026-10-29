#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Etichette di conservazione e regole collegate (durata, decorrenza, azione).
.DESCRIPTION
    Elenca le etichette di conservazione (retention label) di Microsoft Purview e le regole
    di conservazione associate: per quanto tempo si conserva, da quale data decorre il
    conteggio, cosa succede alla fine del periodo e se l'etichetta e un record. E' la
    risposta documentale alla domanda che fa un auditor: "per quanto tempo conservate
    questa categoria di documenti e in base a cosa". Sola lettura.
    NOTA: la durata puo essere illimitata (conservazione senza scadenza); in quel caso il
    campo durata resta vuoto e va letto insieme all'azione.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-RetentionLabels-<data>.csv
.EXAMPLE
    .\02-Get-RetentionLabelsAndRules.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement v3.2.0+, via Connect-IPPSSession
    (Security & Compliance PowerShell).
    RetentionType indica la decorrenza (es. CreationAgeInDays, ModificationAgeInDays,
    TaggedAgeInDays, EventAgeInDays); RetentionAction l'azione finale (Keep, Delete,
    KeepAndDelete).
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-RetentionLabels-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
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
    $etichette = Get-ComplianceTag -ErrorAction Stop
}
catch {
    Connect-IPPSSession
    $etichette = Get-ComplianceTag
}

# Le regole di conservazione sono oggetti separati, collegati alla policy: le indicizzo
# per nome di etichetta dove il collegamento e disponibile.
$regole = @()
try { $regole = @(Get-RetentionComplianceRule) } catch { $regole = @() }

$report = foreach ($e in $etichette) {
    $nome = Get-Prop $e 'Name'

    # Cerca una regola che referenzi questa etichetta (il campo puo non esserci)
    $regola = $null
    foreach ($r in $regole) {
        $applicata = Get-Prop $r 'ApplyComplianceTag'
        if (-not [string]::IsNullOrWhiteSpace($applicata) -and $applicata -eq $nome) {
            $regola = $r
            break
        }
    }

    [pscustomobject]@{
        Etichetta        = $nome
        Descrizione      = Get-Prop $e 'Comment'
        AzioneFinale     = Get-Prop $e 'RetentionAction'
        DurataGiorni     = Get-Prop $e 'RetentionDuration'
        Decorrenza       = Get-Prop $e 'RetentionType'
        EtichettaDiRecord = Get-Prop $e 'IsRecordLabel'
        Priorita         = Get-Prop $e 'Priority'
        RegolaCollegata  = if ($null -ne $regola) { Get-Prop $regola 'Name' } else { '' }
        PolicyDellaRegola = if ($null -ne $regola) { Get-Prop $regola 'Policy' } else { '' }
        Creata           = Get-Prop $e 'WhenCreated'
        Modificata       = Get-Prop $e 'WhenChanged'
    }
}

$report | Sort-Object Etichetta | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$record = @($report | Where-Object { $_.EtichettaDiRecord -eq $true })
Write-Host ("Trovate {0} etichette di conservazione ({1} di record) -> {2}" -f $report.Count, $record.Count, $OutputCsv) -ForegroundColor Green
Write-Host "Le etichette senza regola collegata non applicano conservazione da sole: vanno pubblicate o applicate automaticamente da una policy." -ForegroundColor Yellow
