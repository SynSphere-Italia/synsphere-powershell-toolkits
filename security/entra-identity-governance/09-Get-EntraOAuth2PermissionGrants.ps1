#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Consensi OAuth2 delegati concessi alle applicazioni (igiene dei consensi).
.DESCRIPTION
    Elenca i grant di permessi delegati (chi ha concesso quali permessi a quali app, per
    conto di tutti o del singolo utente), risolvendo i nomi delle app e delle risorse. Serve
    a individuare consensi eccessivi o app sospette che hanno ottenuto accesso ai dati. Sola
    lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-OAuth2Grants-<data>.csv
.EXAMPLE
    .\09-Get-EntraOAuth2PermissionGrants.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Directory.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Entra-OAuth2Grants-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Directory.Read.All' -NoWelcome

# Cache di risoluzione servicePrincipalId -> displayName
$spCache = @{}
$report = foreach ($grant in Get-MgOauth2PermissionGrant -All) {
    foreach ($id in @($grant.ClientId, $grant.ResourceId)) {
        if ($id -and -not $spCache.ContainsKey($id)) {
            try { $spCache[$id] = (Get-MgServicePrincipal -ServicePrincipalId $id -Property DisplayName -ErrorAction Stop).DisplayName }
            catch { $spCache[$id] = $id }
        }
    }
    [pscustomobject]@{
        App          = $spCache[$grant.ClientId]
        Risorsa      = $spCache[$grant.ResourceId]
        TipoConsenso = $grant.ConsentType   # AllPrincipals = tutto il tenant
        Permessi     = ([string]$grant.Scope).Trim()   # Scope può essere null: forziamo a stringa
        PrincipalId  = $grant.PrincipalId    # valorizzato solo per consensi per-utente
    }
}

$report | Sort-Object App | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} consensi OAuth2 delegati -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
