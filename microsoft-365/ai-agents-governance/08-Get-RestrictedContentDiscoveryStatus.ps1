<#
.SYNOPSIS
    Stato di Restricted Content Discovery (RCD) sui siti SharePoint.
.DESCRIPTION
    RCD esclude il contenuto di un sito dalla ricerca a livello di
    organizzazione e da Copilot, senza toccare i permessi: e' la leva da usare
    quando un sito ha permessi troppo larghi e non si puo' sistemarli subito.
    Questo script fotografa dove e' attivo e dove no.

    TRE COSE VERIFICATE CHE CAMBIANO IL PIANO:
    1. RCD richiede almeno una licenza Microsoft 365 Copilot nel tenant (che
       sblocca SharePoint Advanced Management). Su Business Premium puro non c'e'.
    2. RCD NON e' supportato su OneDrive: i siti personali restano fuori, per
       progetto. Chi conta di usarlo per contenere l'oversharing su OneDrive sta
       pianificando su un presupposto falso.
    3. Restricted SharePoint Search - la misura piu' grossolana che spegneva la
       ricerca org-wide su tutto - non e' piu' abilitabile: dal 31 luglio 2026 le
       nuove attivazioni sono bloccate. I cmdlet restano solo come via d'uscita
       per chi l'aveva gia' attiva.
    La propagazione su siti oltre 500.000 elementi puo' superare la settimana: un
    controllo fatto il giorno dopo non dimostra che non abbia funzionato.

    Sola lettura: lo script NON attiva RCD. Il comando per farlo e' stampato in
    fondo, da eseguire consapevolmente.
.PARAMETER Url
    URL admin di SharePoint.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\AI-RcdStatus-<data>.csv
.EXAMPLE
    .\08-Get-RestrictedContentDiscoveryStatus.ps1 -Url https://contoso-admin.sharepoint.com
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
    [string]$OutputCsv = (".\AI-RcdStatus-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

try { Get-SPOTenant -ErrorAction Stop | Out-Null }
catch { Connect-SPOService -Url $Url }

$t = Get-SPOTenant
Write-Host ''
Write-Host ('=' * 74)
Write-Host ' CONTESTO DEL TENANT'
Write-Host ('=' * 74)
foreach ($c in @('DelegateRestrictedContentDiscoverabilityManagement', 'RestrictedSearchModeForSitesEnabled')) {
    if ($t.PSObject.Properties.Name -contains $c) {
        Write-Host ("  {0,-52} {1}" -f $c, $t.$c)
    }
}

Write-Host ''
Write-Host 'Lettura dello stato RCD sito per sito...' -ForegroundColor Cyan
$siti = Get-SPOSite -Limit ALL
$righe = @()
$i = 0
foreach ($s in $siti) {
    $i++
    Write-Progress -Activity 'Stato RCD' -Status $s.Url -PercentComplete (($i / @($siti).Count) * 100)
    try {
        $d = Get-SPOSite -Identity $s.Url -ErrorAction Stop
        $rcd = if ($d.PSObject.Properties.Name -contains 'RestrictContentOrgWideSearch') {
            $d.RestrictContentOrgWideSearch
        } else { 'proprieta assente in questa versione del modulo' }
        $righe += [pscustomobject]@{
            Url                          = $d.Url
            Titolo                       = $d.Title
            Template                     = $d.Template
            RestrictContentOrgWideSearch = $rcd
            SharingCapability            = if ($d.PSObject.Properties.Name -contains 'SharingCapability') { $d.SharingCapability } else { '' }
            SensitivityLabel             = if ($d.PSObject.Properties.Name -contains 'SensitivityLabel') { $d.SensitivityLabel } else { '' }
        }
    }
    catch {
        $righe += [pscustomobject]@{
            Url = $s.Url; Titolo = $s.Title; Template = ''
            RestrictContentOrgWideSearch = 'errore: ' + $_.Exception.Message
            SharingCapability = ''; SensitivityLabel = ''
        }
    }
}
Write-Progress -Activity 'Stato RCD' -Completed

$righe | Sort-Object RestrictContentOrgWideSearch, Url |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$attivi = @($righe | Where-Object { $_.RestrictContentOrgWideSearch -eq $true }).Count
Write-Host ''
Write-Host ("Esportato: {0}  ({1} siti, RCD attivo su {2})" -f $OutputCsv, $righe.Count, $attivi) -ForegroundColor Green
Write-Host ''
Write-Host 'Per attivare RCD su un sito (azione con effetti, da decidere):' -ForegroundColor Yellow
Write-Host '  Set-SPOSite -Identity <url> -RestrictContentOrgWideSearch $true'
Write-Host 'Ricorda: non si applica a OneDrive, e la propagazione su siti molto'
Write-Host 'grandi puo richiedere oltre una settimana.'
