<#
.SYNOPSIS
    Permessi applicativi e delegati concessi a ciascuna agent identity.
.DESCRIPTION
    Per ogni identita' prodotta dallo script 01 elenca i permessi realmente
    concessi: app role assignment (permessi applicativi, quelli che valgono
    senza un utente collegato) e oauth2 permission grant (permessi delegati).
    E' la base di un audit di least-privilege: un agente con Sites.Read.All
    applicativo vede l'intero SharePoint, indipendentemente dai permessi delle
    persone.

    Distinzione che cambia la lettura del report: ApplicationPermission agisce
    con l'identita' dell'agente e ignora i permessi dell'utente;
    DelegatedPermission agisce a nome di un utente ed e' limitata da cio' che
    quell'utente puo' vedere. In un audit vanno guardate prima le prime.

    Sola lettura.
.PARAMETER InventoryCsv
    CSV prodotto da 01-Get-AgentIdentityInventory.ps1. Se omesso, rilegge le
    ServiceIdentity direttamente.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\AI-AgentIdentityPermissions-<data>.csv
.EXAMPLE
    .\02-Get-AgentIdentityPermissions.ps1 -InventoryCsv .\AI-AgentIdentityInventory-20260819.csv
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Cmdlet verificati su learn.microsoft.com il 19 agosto 2026.
    Le superfici di governance degli agenti AI cambiano ogni mese: prima di un
    uso in produzione esegui 00-Test-Prerequisiti.ps1, che controlla che i
    cmdlet esistano davvero nella versione di modulo installata.
#>
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Applications
[CmdletBinding()]
param(
    [string]$InventoryCsv,
    [string]$OutputCsv = (".\AI-AgentIdentityPermissions-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes 'Application.Read.All', 'Directory.Read.All' -NoWelcome
}

if ($InventoryCsv) {
    if (-not (Test-Path $InventoryCsv)) { throw "CSV non trovato: $InventoryCsv" }
    $identita = Import-Csv -Path $InventoryCsv | Where-Object { $_.Id }
}
else {
    Write-Host 'Nessun inventario passato: rileggo le ServiceIdentity...' -ForegroundColor Cyan
    $identita = Get-MgServicePrincipal -Filter "servicePrincipalType eq 'ServiceIdentity'" `
                                       -All -ConsistencyLevel eventual |
        Select-Object @{n = 'Id'; e = { $_.Id } }, @{n = 'DisplayName'; e = { $_.DisplayName } }
}

Write-Host ("Identita da analizzare: {0}" -f @($identita).Count) -ForegroundColor Cyan

# Cache dei nomi delle resource API: senza, il report mostra soli GUID e nessuno
# lo legge.
$cacheRisorse = @{}
function Get-NomeRisorsa {
    param([string]$ResourceId)
    if (-not $ResourceId) { return '' }
    if ($cacheRisorse.ContainsKey($ResourceId)) { return $cacheRisorse[$ResourceId] }
    try {
        $r = Get-MgServicePrincipal -ServicePrincipalId $ResourceId -ErrorAction Stop
        $cacheRisorse[$ResourceId] = $r.DisplayName
    }
    catch { $cacheRisorse[$ResourceId] = $ResourceId }
    return $cacheRisorse[$ResourceId]
}

$righe = @()
$i = 0
foreach ($id in $identita) {
    $i++
    Write-Progress -Activity 'Permessi per agent identity' -Status $id.DisplayName `
                   -PercentComplete (($i / [math]::Max(@($identita).Count, 1)) * 100)

    # Permessi APPLICATIVI: agiscono senza utente. CreatedDateTime dice QUANDO,
    # ma non CHI ha consentito: l'attore vive solo nell'audit di directory,
    # ed e' il motivo per cui esiste lo script 03.
    try {
        foreach ($a in (Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $id.Id -All -ErrorAction Stop)) {
            $righe += [pscustomobject]@{
                Agente          = $id.DisplayName
                AgenteId        = $id.Id
                TipoPermesso    = 'ApplicationPermission'
                Risorsa         = Get-NomeRisorsa $a.ResourceId
                Permesso        = $a.AppRoleId
                Ambito          = 'tutto il tenant (nessun utente coinvolto)'
                ConcessoIl      = $a.CreatedDateTime
                PrincipalType   = $a.PrincipalType
            }
        }
    }
    catch { Write-Warning ("App role assignment non leggibili per {0}: {1}" -f $id.DisplayName, $_.Exception.Message) }

    # Permessi DELEGATI: limitati da cio' che vede l'utente a nome del quale
    # l'agente agisce.
    try {
        foreach ($g in (Get-MgServicePrincipalOauth2PermissionGrant -ServicePrincipalId $id.Id -All -ErrorAction Stop)) {
            $righe += [pscustomobject]@{
                Agente          = $id.DisplayName
                AgenteId        = $id.Id
                TipoPermesso    = 'DelegatedPermission'
                Risorsa         = Get-NomeRisorsa $g.ResourceId
                Permesso        = $g.Scope
                Ambito          = $g.ConsentType
                ConcessoIl      = ''
                PrincipalType   = if ($g.PrincipalId) { 'singolo utente' } else { 'tutti gli utenti' }
            }
        }
    }
    catch { Write-Warning ("Oauth2 grant non leggibili per {0}: {1}" -f $id.DisplayName, $_.Exception.Message) }
}
Write-Progress -Activity 'Permessi per agent identity' -Completed

$righe | Sort-Object Agente, TipoPermesso, Risorsa |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$appPerm = @($righe | Where-Object TipoPermesso -eq 'ApplicationPermission').Count
Write-Host ''
Write-Host ("Esportato: {0}  ({1} permessi, di cui {2} applicativi)" -f $OutputCsv, $righe.Count, $appPerm) -ForegroundColor Green
Write-Host ''
Write-Host 'DA GUARDARE PRIMA: i permessi applicativi con ambito tenant.' -ForegroundColor Yellow
Write-Host 'Sono quelli che un agente esercita senza nessun utente collegato,'
Write-Host 'quindi non sono limitati dai permessi delle persone.'
