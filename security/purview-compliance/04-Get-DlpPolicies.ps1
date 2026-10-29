#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Policy DLP con stato, modalita e posizioni coperte.
.DESCRIPTION
    Elenca le policy di prevenzione della perdita dei dati (DLP) di Microsoft Purview con
    stato, modalita operativa e le posizioni su cui sono configurate. La modalita e il campo
    da leggere per primo: una policy in modalita di test registra gli eventi ma non blocca
    nulla. Sola lettura.
    NOTA: questo script NON usa lo switch -DistributionDetail. La documentazione Microsoft
    avverte che la proprieta DistributionResults e inaffidabile e soggetta a errori, quindi
    fondarci un report darebbe risultati fuorvianti.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-DlpPolicies-<data>.csv
.EXAMPLE
    .\04-Get-DlpPolicies.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement v3.2.0+, via Connect-IPPSSession
    (Security & Compliance PowerShell). Il cmdlet NON esiste con Connect-ExchangeOnline.
    Per il dettaglio delle regole di ciascuna policy usare 05-Get-DlpRulesDetail.ps1;
    per isolare le policy rimaste in simulazione usare 06-Get-DlpPoliciesInTestMode.ps1.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-DlpPolicies-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
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
        $n = Get-Prop $v 'DisplayName'
        if ([string]::IsNullOrWhiteSpace($n)) { $n = [string]$v }
        if (-not [string]::IsNullOrWhiteSpace($n)) { $nomi += $n }
    }
    return ($nomi -join '; ')
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

    # Classifica sul prefisso invece che su un elenco cablato di valori: i valori di Mode
    # non sono documentati sulla pagina del cmdlet e possono cambiare.
    $inSimulazione = $modalita -like 'Test*'

    [pscustomobject]@{
        Nome            = Get-Prop $p 'Name'
        Abilitata       = Get-Prop $p 'Enabled'
        Modalita        = $modalita
        InSimulazione   = $inSimulazione
        Priorita        = Get-Prop $p 'Priority'
        Exchange        = Format-Location (Get-Prop $p 'ExchangeLocation')
        SharePoint      = Format-Location (Get-Prop $p 'SharePointLocation')
        OneDrive        = Format-Location (Get-Prop $p 'OneDriveLocation')
        Teams           = Format-Location (Get-Prop $p 'TeamsLocation')
        Endpoint        = Format-Location (Get-Prop $p 'EndpointDlpLocation')
        Descrizione     = Get-Prop $p 'Comment'
        Creata          = Get-Prop $p 'WhenCreated'
        Modificata      = Get-Prop $p 'WhenChanged'
    }
}

$report | Sort-Object Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$sim = @($report | Where-Object { $_.InSimulazione -eq $true })
Write-Host ("Trovate {0} policy DLP ({1} in modalita di test) -> {2}" -f $report.Count, $sim.Count, $OutputCsv) -ForegroundColor Green
if ($sim.Count -gt 0) {
    Write-Host "Le policy in modalita di test non bloccano nulla: dettaglio con 06-Get-DlpPoliciesInTestMode.ps1" -ForegroundColor Yellow
}
