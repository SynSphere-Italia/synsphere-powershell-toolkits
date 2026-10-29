<#
.SYNOPSIS
    Verifica moduli, versioni e cmdlet prima di eseguire il resto del toolkit.
.DESCRIPTION
    E' lo script da lanciare per primo, e su questa superficie e' il piu' utile
    del set. Meta' dei cmdlet per la governance degli agenti AI e' comparsa in
    versioni di modulo recenti o vive ancora in rami beta: uno script che
    presume la loro esistenza fallisce con un errore che sembra un problema di
    permessi e non lo e'.

    Controlla, per ogni area: se il modulo e' installato, con quale versione, e
    se i cmdlet che il toolkit usa rispondono davvero a Get-Command. Non
    modifica nulla e non si connette a nessun tenant.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\AI-Prerequisiti-<data>.csv
.EXAMPLE
    .\00-Test-Prerequisiti.ps1
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Cmdlet verificati su learn.microsoft.com il 19 agosto 2026.
    Le superfici di governance degli agenti AI cambiano ogni mese: prima di un
    uso in produzione esegui 00-Test-Prerequisiti.ps1, che controlla che i
    cmdlet esistano davvero nella versione di modulo installata.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\AI-Prerequisiti-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Continue'

# Soglie di versione che contano davvero. Microsoft.Entra sotto la 1.3 NON ha i
# cmdlet Agent*: e' il caso in cui "il cmdlet non esiste" significa solo
# "il modulo e' vecchio".
$Requisiti = @(
    @{ Modulo = 'Microsoft.Graph.Authentication';            Minima = '2.0.0'; Area = 'Graph - connessione';        Ps = '7' }
    @{ Modulo = 'Microsoft.Graph.Applications';              Minima = '2.0.0'; Area = 'Inventario agenti e permessi'; Ps = '7' }
    @{ Modulo = 'Microsoft.Graph.Users';                     Minima = '2.0.0'; Area = 'Licenze e utenti';           Ps = '7' }
    @{ Modulo = 'Microsoft.Graph.Identity.DirectoryManagement'; Minima = '2.0.0'; Area = 'SKU sottoscritti';        Ps = '7' }
    @{ Modulo = 'Microsoft.Graph.Reports';                   Minima = '2.0.0'; Area = 'Audit di directory';         Ps = '7' }
    @{ Modulo = 'Microsoft.Entra';                           Minima = '1.3.0'; Area = 'Agent identity (opzionale)'; Ps = '7' }
    @{ Modulo = 'ExchangeOnlineManagement';                  Minima = '3.2.0'; Area = 'Audit log unificato';        Ps = '7' }
    @{ Modulo = 'Microsoft.Online.SharePoint.PowerShell';    Minima = '16.0.0'; Area = 'Oversharing SharePoint';    Ps = '7' }
    @{ Modulo = 'Az.ResourceGraph';                          Minima = '0.13.0'; Area = 'Agenti Copilot Studio';     Ps = '7' }
    @{ Modulo = 'Microsoft.PowerApps.Administration.PowerShell'; Minima = '2.0.0'; Area = 'Shadow AI Power Platform'; Ps = '5.1 SOLTANTO' }
)

# I cmdlet effettivamente usati dagli script del toolkit.
$Cmdlet = @(
    @{ Nome = 'Get-MgServicePrincipal';                  Usato = '01, 02' }
    @{ Nome = 'Get-MgServicePrincipalAppRoleAssignment'; Usato = '02, 03' }
    @{ Nome = 'Get-MgServicePrincipalOauth2PermissionGrant'; Usato = '02' }
    @{ Nome = 'Get-MgAuditLogDirectoryAudit';            Usato = '03' }
    @{ Nome = 'Get-MgSubscribedSku';                     Usato = '06' }
    @{ Nome = 'Get-MgUser';                              Usato = '06' }
    @{ Nome = 'Get-AdminAuditLogConfig';                 Usato = '04' }
    @{ Nome = 'Search-UnifiedAuditLog';                  Usato = '05' }
    @{ Nome = 'Get-SPOTenant';                           Usato = '07, 08' }
    @{ Nome = 'Get-SPOSite';                             Usato = '07, 08' }
    @{ Nome = 'Search-AzGraph';                          Usato = '10' }
    # Dedicati agli agenti: comodi ma NON necessari. Il toolkit non li richiede,
    # perche' non consentono un inventario (vogliono sempre un ID).
    @{ Nome = 'Get-EntraAgentIdentity';                  Usato = '02 (opzionale)' }
    @{ Nome = 'Get-EntraAgentUser';                      Usato = '02 (opzionale)' }
)

$righe = @()

Write-Host ''
Write-Host 'MODULI' -ForegroundColor Cyan
Write-Host ('-' * 78)
foreach ($r in $Requisiti) {
    $m = Get-Module -ListAvailable -Name $r.Modulo |
         Sort-Object Version -Descending | Select-Object -First 1
    if ($null -eq $m) {
        $stato = 'ASSENTE'
        $ver = ''
        $colore = 'Yellow'
    }
    else {
        $ver = $m.Version.ToString()
        if ([version]$ver -lt [version]$r.Minima) {
            $stato = 'DA AGGIORNARE'
            $colore = 'Yellow'
        }
        else {
            $stato = 'OK'
            $colore = 'Green'
        }
    }
    Write-Host ("  {0,-14} {1,-52} {2}" -f $stato, $r.Modulo, $ver) -ForegroundColor $colore
    $righe += [pscustomobject]@{
        Tipo = 'Modulo'; Nome = $r.Modulo; Stato = $stato
        VersioneInstallata = $ver; VersioneMinima = $r.Minima
        Area = $r.Area; RichiedePowerShell = $r.Ps; UsatoDa = ''
    }
}

Write-Host ''
Write-Host 'CMDLET' -ForegroundColor Cyan
Write-Host ('-' * 78)
foreach ($c in $Cmdlet) {
    $g = Get-Command -Name $c.Nome -ErrorAction SilentlyContinue
    if ($g) {
        $stato = 'OK'
        $src = if ($g.ModuleName) { $g.ModuleName } else { '' }
        $colore = 'Green'
    }
    else {
        $stato = 'NON TROVATO'
        $src = ''
        $colore = 'Yellow'
    }
    Write-Host ("  {0,-14} {1,-52} {2}" -f $stato, $c.Nome, $src) -ForegroundColor $colore
    $righe += [pscustomobject]@{
        Tipo = 'Cmdlet'; Nome = $c.Nome; Stato = $stato
        VersioneInstallata = $src; VersioneMinima = ''
        Area = ''; RichiedePowerShell = ''; UsatoDa = $c.Usato
    }
}

Write-Host ''
Write-Host 'AMBIENTE' -ForegroundColor Cyan
Write-Host ('-' * 78)
Write-Host ("  PowerShell        {0} ({1})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)
if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Host '  NOTA: lo script 09 (shadow AI Power Platform) NON gira qui.' -ForegroundColor Yellow
    Write-Host '        Va lanciato da Windows PowerShell 5.1 (powershell.exe).' -ForegroundColor Yellow
}
else {
    Write-Host '  NOTA: gli script Graph/Entra e il 10 vogliono PowerShell 7 (pwsh.exe).' -ForegroundColor Yellow
}

$righe | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ''
Write-Host ("Esportato: {0}" -f $OutputCsv) -ForegroundColor Green
Write-Host ''
Write-Host 'Nessun cmdlet dedicato agli agenti e obbligatorio: il toolkit usa i'
Write-Host 'cmdlet generici di Graph, che sono l unica via a un inventario completo.'
