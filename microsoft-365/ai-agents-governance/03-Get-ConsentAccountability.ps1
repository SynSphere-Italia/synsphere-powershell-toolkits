<#
.SYNOPSIS
    Chi ha concesso quali permessi ad agenti e applicazioni, e quando.
.DESCRIPTION
    L'app role assignment conserva la data del consenso ma NON l'attore: chi ha
    premuto "accetta" vive solo nell'audit di directory. Questo script legge gli
    eventi di consenso dall'audit e li rende leggibili: attore, applicazione,
    permessi, esito.

    LIMITE STRUTTURALE, da dichiarare prima di promettere il report: passata la
    retention dell'audit (180 giorni; 1 anno per Entra/Exchange/SharePoint solo
    con E5) l'informazione su CHI ha consentito non esiste piu' da nessuna
    parte. Il "quando" resta sull'assignment, il "chi" no. Per questo il report
    va eseguito periodicamente e conservato, non ricostruito a posteriori.

    Sola lettura.
.PARAMETER GiorniIndietro
    Finestra da interrogare. Default 90. Oltre la retention non c'e' nulla da
    trovare: lo script avvisa se chiedi piu' di 180 giorni.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\AI-ConsentAccountability-<data>.csv
.EXAMPLE
    .\03-Get-ConsentAccountability.ps1 -GiorniIndietro 30
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Cmdlet verificati su learn.microsoft.com il 19 agosto 2026.
    Le superfici di governance degli agenti AI cambiano ogni mese: prima di un
    uso in produzione esegui 00-Test-Prerequisiti.ps1, che controlla che i
    cmdlet esistano davvero nella versione di modulo installata.
#>
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Reports
[CmdletBinding()]
param(
    [int]$GiorniIndietro = 90,
    [string]$OutputCsv = (".\AI-ConsentAccountability-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if ($GiorniIndietro -gt 180) {
    Write-Warning 'Oltre 180 giorni la retention standard dell audit non conserva nulla.'
    Write-Warning 'Con E5 arrivano a 1 anno solo Entra, Exchange e SharePoint.'
}

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes 'AuditLog.Read.All', 'Directory.Read.All' -NoWelcome
}

$da = (Get-Date).AddDays(-$GiorniIndietro).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

# Le attivita' di consenso hanno nomi diversi a seconda del percorso usato:
# consenso amministrativo, consenso utente, assegnazione di app role.
$Attivita = @(
    'Consent to application',
    'Add app role assignment to service principal',
    'Add delegated permission grant',
    'Add OAuth2PermissionGrant'
)

Write-Host ("Audit di directory, ultimi {0} giorni..." -f $GiorniIndietro) -ForegroundColor Cyan

$righe = @()
foreach ($att in $Attivita) {
    try {
        $ev = Get-MgAuditLogDirectoryAudit `
                -Filter ("activityDisplayName eq '{0}' and activityDateTime ge {1}" -f $att, $da) `
                -All -ErrorAction Stop
    }
    catch {
        Write-Warning ("Attivita '{0}' non interrogabile: {1}" -f $att, $_.Exception.Message)
        continue
    }

    foreach ($e in $ev) {
        # L'attore puo' essere un utente o un'app: si guardano entrambi i rami,
        # altrimenti i consensi dati da un servizio risultano senza attore.
        $attore = ''
        if ($e.InitiatedBy.User)        { $attore = $e.InitiatedBy.User.UserPrincipalName }
        elseif ($e.InitiatedBy.App)     { $attore = $e.InitiatedBy.App.DisplayName + ' (app)' }

        $bersaglio = ($e.TargetResources | ForEach-Object { $_.DisplayName }) -join '; '
        $dettaglio = ($e.TargetResources | ForEach-Object {
                        $_.ModifiedProperties | ForEach-Object { $_.NewValue }
                     }) -join ' | '

        $righe += [pscustomobject]@{
            Quando        = $e.ActivityDateTime
            Attivita      = $e.ActivityDisplayName
            Attore        = $attore
            Applicazione  = $bersaglio
            Esito         = $e.Result
            Dettaglio     = if ($dettaglio.Length -gt 900) { $dettaglio.Substring(0, 900) + '...' } else { $dettaglio }
        }
    }
    Write-Host ("  {0,-46} {1} eventi" -f $att, $ev.Count) -ForegroundColor Green
}

$righe | Sort-Object Quando -Descending |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host ("Esportato: {0}  ({1} eventi)" -f $OutputCsv, $righe.Count) -ForegroundColor Green
Write-Host ("Finestra interrogata: dal {0} a oggi." -f $da) -ForegroundColor Cyan
Write-Host 'Conserva questo CSV: fuori dalla retention il CHI non e piu recuperabile.' -ForegroundColor Yellow
