#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Fotografa lo stato di TUTTI gli account prima del blocco. E' cio' che rende il blocco reversibile.
.DESCRIPTION
    Da eseguire PRIMA dello script 03, sempre. Non modifica nulla.

    Salva per ogni utente lo stato di abilitazione corrente. Senza questo file, dopo un
    blocco di massa non esiste piu' alcun modo di sapere QUALI account erano gia' disabilitati
    prima dell'incidente: riabilitandoli tutti si riattiverebbero anche gli ex dipendenti, i
    contractor scaduti e gli account disattivati apposta. Lo script 04 usa questo CSV per
    riportare il tenant esattamente com'era.

    Registra anche due informazioni che cambiano l'esito del contenimento:

      - onPremisesSyncEnabled: sugli account SINCRONIZZATI da Active Directory locale il
        blocco lato cloud viene sovrascritto al successivo ciclo di sincronizzazione. Vanno
        disabilitati a monte, in AD. La proprieta' e' TRI-STATO (True o assente, mai False):
        confrontarla con $false non trova nessuno e un tenant ibrido sembra tutto cloud.
      - i ruoli di amministrazione, per sapere chi NON si puo' bloccare senza perdere il tenant.
.PARAMETER OutputCsv
    Percorso dello snapshot. Default: .\IR-02-StatoUtenti-<data-ora>.csv
.EXAMPLE
    .\02-Backup-StatoUtenti.ps1
.EXAMPLE
    .\02-Backup-StatoUtenti.ps1 -OutputCsv D:\incidente\stato-pre-blocco.csv
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Sola lettura. Permessi Graph: User.Read.All, Directory.Read.All, RoleManagement.Read.Directory
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\IR-02-StatoUtenti-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
)

$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All', 'Directory.Read.All', 'RoleManagement.Read.Directory' -NoWelcome

$ctx = Get-MgContext
Write-Host ''
Write-Host ("Snapshot del tenant {0}" -f $ctx.TenantId) -ForegroundColor Cyan
Write-Host ("Operatore: {0}" -f $ctx.Account) -ForegroundColor Cyan
Write-Host ''

# ----------------------------------------------------------------------------------
# Chi ha un ruolo di amministrazione: da segnalare, non da bloccare alla cieca
# ----------------------------------------------------------------------------------
Write-Host 'Lettura dei ruoli di amministrazione...' -ForegroundColor Cyan
$ruoliPerUtente = @{}
try {
    foreach ($ruolo in Get-MgDirectoryRole -All) {
        # -DirectoryRoleId, NON -Id: con -Id il cmdlet non risolve i membri
        $membri = Get-MgDirectoryRoleMember -DirectoryRoleId $ruolo.Id -All -ErrorAction SilentlyContinue
        foreach ($m in $membri) {
            # UPN e displayName dei membri stanno in AdditionalProperties, non in proprieta' dirette
            $tipo = $m.AdditionalProperties['@odata.type']
            if ($tipo -ne '#microsoft.graph.user') { continue }
            if (-not $ruoliPerUtente.ContainsKey($m.Id)) {
                $ruoliPerUtente[$m.Id] = New-Object System.Collections.Generic.List[string]
            }
            $ruoliPerUtente[$m.Id].Add($ruolo.DisplayName)
        }
    }
} catch {
    Write-Warning ("Ruoli non leggibili ({0}). Lo snapshot prosegue senza la colonna RuoliAdmin." -f $_.Exception.Message)
}

# ----------------------------------------------------------------------------------
# Tutti gli utenti.
# -Property e' OBBLIGATORIO: senza, Graph restituisce solo 11 proprieta' di default e
# AccountEnabled / OnPremisesSyncEnabled tornano vuote per tutti. Lo snapshot sarebbe inutile.
# ----------------------------------------------------------------------------------
Write-Host 'Lettura degli utenti...' -ForegroundColor Cyan
$props = @(
    'Id', 'DisplayName', 'UserPrincipalName', 'AccountEnabled', 'UserType',
    'CreatedDateTime', 'OnPremisesSyncEnabled', 'Mail', 'AssignedLicenses'
)
$utenti = Get-MgUser -All -Property $props

$snapshot = foreach ($u in $utenti) {
    $ruoli = ''
    if ($ruoliPerUtente.ContainsKey($u.Id)) { $ruoli = ($ruoliPerUtente[$u.Id] -join '; ') }

    # tri-stato: $true oppure $null. Mai $false. Un -eq $false non trova nessuno.
    $sincronizzato = 'No'
    if ($u.OnPremisesSyncEnabled -eq $true) { $sincronizzato = 'Si' }

    [pscustomobject]@{
        Id                 = $u.Id
        DisplayName        = $u.DisplayName
        UserPrincipalName  = $u.UserPrincipalName
        Mail               = $u.Mail
        AccountEnabled     = $u.AccountEnabled
        UserType           = $u.UserType
        Sincronizzato      = $sincronizzato
        RuoliAdmin         = $ruoli
        HaLicenze          = (@($u.AssignedLicenses).Count -gt 0)
        CreatedDateTime    = $u.CreatedDateTime
        SnapshotUtc        = (Get-Date).ToUniversalTime().ToString('o')
    }
}

$snapshot | Sort-Object UserPrincipalName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

# ----------------------------------------------------------------------------------
# Riepilogo: sono i numeri su cui si decide il contenimento
# ----------------------------------------------------------------------------------
$abilitati = @($snapshot | Where-Object { $_.AccountEnabled }).Count
$disabilitati = @($snapshot | Where-Object { -not $_.AccountEnabled }).Count
$sincronizzati = @($snapshot | Where-Object { $_.Sincronizzato -eq 'Si' }).Count
$admin = @($snapshot | Where-Object { $_.RuoliAdmin }).Count
$guest = @($snapshot | Where-Object { $_.UserType -eq 'Guest' }).Count

Write-Host ''
Write-Host ("Snapshot salvato: {0} account" -f $snapshot.Count) -ForegroundColor Green
Write-Host ("   abilitati adesso : {0}" -f $abilitati)
Write-Host ("   gia disabilitati : {0}   <- lo script 04 NON li riabilitera" -f $disabilitati)
Write-Host ("   guest            : {0}" -f $guest)
Write-Host ("   con ruoli admin  : {0}" -f $admin)
Write-Host ''
if ($sincronizzati -gt 0) {
    Write-Host ("ATTENZIONE: {0} account sono SINCRONIZZATI da Active Directory locale." -f $sincronizzati) -ForegroundColor Red
    Write-Host '  Il blocco lato cloud su questi account viene sovrascritto al successivo ciclo di' -ForegroundColor Red
    Write-Host '  sincronizzazione. Vanno disabilitati in AD, non solo qui.' -ForegroundColor Red
    Write-Host ''
}
Write-Host ("File -> {0}" -f $OutputCsv) -ForegroundColor Cyan
Write-Host 'CONSERVATELO FUORI DAL TENANT (chiavetta, altro cloud): e la vostra via di ritorno.' -ForegroundColor Yellow
