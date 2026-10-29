<#
.SYNOPSIS
    Baseline della condivisione di SharePoint e OneDrive, sito per sito.
.DESCRIPTION
    Copilot non crea permessi: amplifica quelli che ci sono. Un sito condiviso
    con "chiunque" era un rischio silenzioso finche' nessuno lo cercava; con un
    assistente che riassume su richiesta, diventa un rischio attivo. Questo
    script fotografa la policy del tenant e lo stato di condivisione di ogni
    sito, per avere un punto di partenza misurato invece che un'impressione.

    IL DOPPIO PASSAGGIO NON E' UNA SVISTA. Get-SPOSite -Limit ALL popola VALORI
    DI DEFAULT sulle proprieta' di sharing: un Where-Object su SharingCapability
    applicato a quell'elenco produce risultati falsi ma perfettamente plausibili
    - il tipo di errore che finisce in un report e non viene mai scoperto. Per
    leggere i valori reali serve una chiamata per sito con -Identity. Quindi:
    primo passaggio per ENUMERARE, secondo per LEGGERE.

    Costo: su un tenant con centinaia di siti sono centinaia di chiamate, ed e'
    lento. Non esiste un'alternativa senza SharePoint Advanced Management: il
    -Filter di Get-SPOSite accetta solo Owner, Template, LockState, Url e
    IsAuthoritative, non le proprieta' di condivisione.

    Sola lettura.
.PARAMETER Url
    URL admin di SharePoint (es. https://contoso-admin.sharepoint.com).
.PARAMETER IncludiOneDrive
    Include i siti personali (OneDrive). Su tenant grandi allunga molto.
.PARAMETER MaxSiti
    Limite di sicurezza sul secondo passaggio. Default 500: oltre, lo script
    avvisa invece di girare per ore.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\AI-SharePointOversharing-<data>.csv
.EXAMPLE
    .\07-Get-SharePointOversharingBaseline.ps1 -Url https://contoso-admin.sharepoint.com
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Cmdlet verificati su learn.microsoft.com il 19 agosto 2026.
    Le superfici di governance degli agenti AI cambiano ogni mese: prima di un
    uso in produzione esegui 00-Test-Prerequisiti.ps1, che controlla che i
    cmdlet esistano davvero nella versione di modulo installata.
#>
#Requires -Modules Microsoft.Online.SharePoint.PowerShell
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [switch]$IncludiOneDrive,
    [int]$MaxSiti = 500,
    [string]$OutputCsv = (".\AI-SharePointOversharing-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

# Connect-SPOService NON supporta -Credential: un runbook non presidiato va
# ripensato, non forzato.
try { Get-SPOTenant -ErrorAction Stop | Out-Null }
catch {
    Write-Host 'Connessione a SharePoint Online...' -ForegroundColor Cyan
    Connect-SPOService -Url $Url
}

Write-Host ''
Write-Host ('=' * 74)
Write-Host ' POLICY DEL TENANT'
Write-Host ('=' * 74)
$t = Get-SPOTenant
$campiTenant = @(
    'SharingCapability', 'DefaultSharingLinkType', 'DefaultLinkPermission',
    'RequireAnonymousLinksExpireInDays', 'FileAnonymousLinkType',
    'FolderAnonymousLinkType', 'PreventExternalUsersFromResharing',
    'DisableAddToOneDrive', 'DelegateRestrictedContentDiscoverabilityManagement'
)
foreach ($c in $campiTenant) {
    if ($t.PSObject.Properties.Name -contains $c) {
        Write-Host ("  {0,-52} {1}" -f $c, $t.$c)
    }
}

# ── passaggio 1: enumerare ────────────────────────────────────────────────
Write-Host ''
Write-Host 'Passaggio 1 di 2 - enumerazione dei siti...' -ForegroundColor Cyan
$elenco = if ($IncludiOneDrive) {
    Get-SPOSite -Limit ALL -IncludePersonalSite $true
} else {
    Get-SPOSite -Limit ALL
}
Write-Host ("  {0} siti" -f @($elenco).Count) -ForegroundColor Green

if (@($elenco).Count -gt $MaxSiti) {
    Write-Host ''
    Write-Host ("ATTENZIONE: {0} siti, oltre il limite di {1}." -f @($elenco).Count, $MaxSiti) -ForegroundColor Yellow
    Write-Host 'Il secondo passaggio fa una chiamata per sito. Rilancia con'
    Write-Host ("  -MaxSiti {0}" -f @($elenco).Count)
    Write-Host 'se accetti il tempo, oppure valuta i report DAG (richiedono SharePoint'
    Write-Host 'Advanced Management). Interrompo qui per non farti aspettare a vuoto.'
    return
}

# ── passaggio 2: leggere i valori reali ───────────────────────────────────
Write-Host 'Passaggio 2 di 2 - lettura sito per sito (i valori del passaggio 1 sono default)...' -ForegroundColor Cyan
$righe = @()
$i = 0
foreach ($s in $elenco) {
    $i++
    Write-Progress -Activity 'Lettura siti' -Status $s.Url `
                   -PercentComplete (($i / @($elenco).Count) * 100)
    try {
        $d = Get-SPOSite -Identity $s.Url -ErrorAction Stop
    }
    catch {
        $righe += [pscustomobject]@{
            Url = $s.Url; Titolo = $s.Title; Errore = $_.Exception.Message
        }
        continue
    }

    function P { param($o, [string]$n)
        if ($o.PSObject.Properties.Name -contains $n) { return $o.$n } else { return '' } }

    $righe += [pscustomobject]@{
        Url                            = $d.Url
        Titolo                         = $d.Title
        Template                       = $d.Template
        SharingCapability              = P $d 'SharingCapability'
        AnonymousLinkExpirationInDays  = P $d 'AnonymousLinkExpirationInDays'
        DefaultLinkPermission          = P $d 'DefaultLinkPermission'
        DefaultSharingLinkType         = P $d 'DefaultSharingLinkType'
        DisableCompanyWideSharingLinks = P $d 'DisableCompanyWideSharingLinks'
        SensitivityLabel               = P $d 'SensitivityLabel'
        RestrictContentOrgWideSearch   = P $d 'RestrictContentOrgWideSearch'
        IsAuthoritative                = P $d 'IsAuthoritative'
        Owner                          = P $d 'Owner'
        StorageUsedGB                  = [math]::Round((P $d 'StorageUsageCurrent') / 1024, 2)
        Errore                         = ''
    }
}
Write-Progress -Activity 'Lettura siti' -Completed

$righe | Sort-Object SharingCapability, Url |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$chiunque = @($righe | Where-Object { $_.SharingCapability -eq 'ExternalUserAndGuestSharing' }).Count
Write-Host ''
Write-Host ("Esportato: {0}  ({1} siti)" -f $OutputCsv, $righe.Count) -ForegroundColor Green
Write-Host ("Rilevato il {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm')) -ForegroundColor Cyan
if ($chiunque -gt 0) {
    Write-Host ("  {0} siti consentono link anonimi ('chiunque')." -f $chiunque) -ForegroundColor Red
    Write-Host '  Sono i primi da guardare in una revisione pre-Copilot.'
}
