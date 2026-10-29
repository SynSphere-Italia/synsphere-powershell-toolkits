#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Policy di conservazione di Purview con l'ambito REALMENTE applicato.
.DESCRIPTION
    Elenca le retention policy di Microsoft Purview riportando le posizioni su cui sono
    davvero distribuite (Exchange, SharePoint, OneDrive, gruppi, chat di Teams) e lo stato
    di distribuzione. Serve a verificare che il perimetro di conservazione dichiarato
    corrisponda a quello effettivo. Sola lettura.
    NOTA: il campo "Workload" del cmdlet elenca SEMPRE tutti i workload possibili e non
    l'ambito su cui la policy e applicata — la documentazione Microsoft lo dichiara
    esplicitamente. Senza lo switch -DistributionDetail anche DistributionStatus e le
    proprieta *Location sono inaccurate: per questo lo script lo usa sempre.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-RetentionPolicyScope-<data>.csv
.EXAMPLE
    .\01-Get-RetentionPolicyScope.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement v3.2.0+, via Connect-IPPSSession
    (Security & Compliance PowerShell). Il cmdlet NON esiste con Connect-ExchangeOnline.
    Mode possibili documentati: Test, AuditAndNotify, Enforce.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-RetentionPolicyScope-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

# Legge una proprieta solo se esiste sull'oggetto: evita sia il crash sia una colonna
# che sembra vuota per errore quando il modulo cambia versione.
function Get-Prop {
    param($Oggetto, [string]$Nome)
    if ($null -ne $Oggetto -and ($Oggetto.PSObject.Properties.Name -contains $Nome)) {
        return $Oggetto.$Nome
    }
    return ''
}

# Appiattisce una proprieta *Location (array di oggetti) in stringa leggibile.
function Format-Location {
    param($Valore)
    if ($null -eq $Valore) { return '' }
    $nomi = @()
    foreach ($v in @($Valore)) {
        $n = Get-Prop $v 'DisplayName'
        if ([string]::IsNullOrWhiteSpace($n)) { $n = [string]$v }
        if (-not [string]::IsNullOrWhiteSpace($n)) { $nomi += $n }
    }
    if ($nomi.Count -eq 0) { return '' }
    return ($nomi -join '; ')
}

# Connette a Security & Compliance solo se non gia connesso
try {
    $policies = Get-RetentionCompliancePolicy -DistributionDetail -ErrorAction Stop
}
catch {
    Connect-IPPSSession
    $policies = Get-RetentionCompliancePolicy -DistributionDetail
}

$report = foreach ($p in $policies) {
    [pscustomobject]@{
        Nome                = Get-Prop $p 'Name'
        Abilitata           = Get-Prop $p 'Enabled'
        Modalita            = Get-Prop $p 'Mode'
        StatoDistribuzione  = Get-Prop $p 'DistributionStatus'
        Exchange            = Format-Location (Get-Prop $p 'ExchangeLocation')
        ExchangeEsclusi     = Format-Location (Get-Prop $p 'ExchangeLocationException')
        SharePoint          = Format-Location (Get-Prop $p 'SharePointLocation')
        SharePointEsclusi   = Format-Location (Get-Prop $p 'SharePointLocationException')
        OneDrive            = Format-Location (Get-Prop $p 'OneDriveLocation')
        GruppiModerni       = Format-Location (Get-Prop $p 'ModernGroupLocation')
        ChatTeams           = Format-Location (Get-Prop $p 'TeamsChatLocation')
        CanaliTeams         = Format-Location (Get-Prop $p 'TeamsChannelLocation')
        Creata              = Get-Prop $p 'WhenCreated'
        Modificata          = Get-Prop $p 'WhenChanged'
    }
}

$report | Sort-Object Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$attive = @($report | Where-Object { $_.Modalita -eq 'Enforce' -and $_.Abilitata -eq $true })
Write-Host ("Trovate {0} retention policy ({1} in Enforce e abilitate) -> {2}" -f $report.Count, $attive.Count, $OutputCsv) -ForegroundColor Green
if ($report.Count -gt 0 -and $attive.Count -eq 0) {
    Write-Host "ATTENZIONE: nessuna policy risulta in modalita Enforce e abilitata: la conservazione non sta agendo." -ForegroundColor Yellow
}
