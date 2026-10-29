#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Groups
<#
.SYNOPSIS
    Oggetti Entra ID: utenti cloud-only contro sincronizzati da on-premises, guest e gruppi.
.DESCRIPTION
    E' la distinzione da cui dipende tutto il piano di mappatura. Un utente sincronizzato da
    Active Directory on-premises non si "sposta": va deciso se il target restera' ibrido, se la
    sincronizzazione verra' ripuntata o se l'oggetto diventera' cloud-only. Sbagliare questo
    conteggio significa pianificare la migrazione sbagliata.

    Il campo che inganna: onPremisesSyncEnabled ha bisogno di essere richiesto esplicitamente
    (senza -Property vale $null per tutti, e su un tenant ibrido il conteggio dei sincronizzati
    esce ZERO senza alcun errore) ed e' TRI-STATO: vale $true per i sincronizzati e $null — non
    $false — per i cloud-only. Un filtro -eq $false non trova nessuno.

    Include anche i gruppi di sicurezza NON mail-enabled, che Exchange non vede e che quindi
    mancano dallo script 04.

    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV utenti. Default: .\T2T-EntraUsers-<data>.csv
.PARAMETER GroupsCsv
    Percorso del CSV gruppi. Default: .\T2T-EntraGroups-<data>.csv
.EXAMPLE
    .\09-Get-T2TEntraObjects.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, Group.Read.All, Directory.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv  = (".\T2T-EntraUsers-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')),
    [string]$GroupsCsv  = (".\T2T-EntraGroups-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'User.Read.All', 'Group.Read.All', 'Directory.Read.All' -NoWelcome

Write-Host "Utenti..." -ForegroundColor Cyan
$utenti = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, UserType, Mail,
    AccountEnabled, OnPremisesSyncEnabled, OnPremisesImmutableId, OnPremisesSamAccountName,
    CreatedDateTime, UsageLocation

$reportUtenti = foreach ($u in $utenti) {
    # $true = sincronizzato; $null = cloud-only. Non esiste $false.
    $sincronizzato = ($u.OnPremisesSyncEnabled -eq $true)
    [pscustomobject]@{
        DisplayName        = $u.DisplayName
        UserPrincipalName  = $u.UserPrincipalName
        Tipo               = $u.UserType                # Member oppure Guest
        Origine            = if ($sincronizzato) { 'Sincronizzato da on-premises' } else { 'Cloud-only' }
        Abilitato          = $u.AccountEnabled
        ImmutableId        = $u.OnPremisesImmutableId
        SamAccountName     = $u.OnPremisesSamAccountName
        UsageLocation      = $u.UsageLocation
        Mail               = $u.Mail
        CreatoIl           = $u.CreatedDateTime
    }
}
$reportUtenti | Sort-Object Tipo, Origine, UserPrincipalName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Gruppi..." -ForegroundColor Cyan
$gruppi = Get-MgGroup -All -Property Id, DisplayName, Mail, MailEnabled, SecurityEnabled,
    GroupTypes, OnPremisesSyncEnabled, Visibility, CreatedDateTime, Description

$reportGruppi = foreach ($g in $gruppi) {
    $tipo =
        if ($g.GroupTypes -contains 'Unified')                     { 'Microsoft 365' }
        elseif ($g.GroupTypes -contains 'DynamicMembership')       { 'Dinamico' }
        elseif ($g.MailEnabled -and $g.SecurityEnabled)            { 'Sicurezza mail-enabled' }
        elseif ($g.MailEnabled)                                    { 'Distribuzione' }
        elseif ($g.SecurityEnabled)                                { 'Sicurezza (NON mail-enabled)' }
        else                                                       { 'Altro' }

    [pscustomobject]@{
        Nome            = $g.DisplayName
        Tipo            = $tipo
        Mail            = $g.Mail
        MailEnabled     = $g.MailEnabled
        SecurityEnabled = $g.SecurityEnabled
        Origine         = if ($g.OnPremisesSyncEnabled -eq $true) { 'Sincronizzato da on-premises' } else { 'Cloud-only' }
        Visibilita      = $g.Visibility
        VistoDaExchange = [bool]$g.MailEnabled
        CreatoIl        = $g.CreatedDateTime
    }
}
$reportGruppi | Sort-Object Tipo, Nome | Export-Csv -Path $GroupsCsv -NoTypeInformation -Encoding UTF8

$sync  = @($reportUtenti | Where-Object Origine -like 'Sincronizzato*').Count
$cloud = @($reportUtenti | Where-Object Origine -eq 'Cloud-only').Count
$guest = @($reportUtenti | Where-Object Tipo -eq 'Guest').Count
$soloEntra = @($reportGruppi | Where-Object { -not $_.VistoDaExchange }).Count

Write-Host ""
Write-Host ("Utenti totali            : {0}" -f @($reportUtenti).Count)
Write-Host ("  cloud-only             : {0}" -f $cloud)
Write-Host ("  sincronizzati da on-prem: {0}" -f $sync) -ForegroundColor $(if ($sync) { 'Yellow' } else { 'Gray' })
Write-Host ("  di cui guest           : {0}" -f $guest)
Write-Host ("Gruppi totali            : {0}" -f @($reportGruppi).Count)
Write-Host ("  invisibili a Exchange  : {0} (mancano dallo script 04)" -f $soloEntra)
if ($sync) {
    Write-Host ""
    Write-Host "Tenant IBRIDO: gli oggetti sincronizzati richiedono una decisione esplicita" -ForegroundColor Yellow
    Write-Host "prima della migrazione (ripuntare la sincronizzazione o convertirli in cloud-only)." -ForegroundColor Yellow
}
Write-Host ("Esportati: {0} e {1}" -f $OutputCsv, $GroupsCsv)
