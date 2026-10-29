<#
.SYNOPSIS
    Inventario tenant-wide delle agent identity presenti in Microsoft Entra.
.DESCRIPTION
    Elenca le identita' non-umane di tipo agente registrate nel tenant, con
    proprietario, data di creazione, stato e appId. E' il punto di partenza di
    tutto il resto: gli altri script del toolkit si alimentano da questo CSV.

    PERCHE' NON USA I CMDLET DEDICATI. Esistono Get-EntraAgentIdentity e
    Get-EntraAgentIdentityBlueprint (modulo Microsoft.Entra v1.3+), ma non
    permettono un inventario: accettano solo un AgentId o un BlueprintId, e non
    esiste alcun cmdlet che elenchi i blueprint. Senza conoscere gia' gli ID non
    si parte. Microsoft stessa posiziona quei cmdlet come strumenti "for testing
    purposes" e indica Graph come via di produzione. L'inventario si fa quindi
    con il cmdlet generico, filtrando servicePrincipalType.

    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\AI-AgentIdentityInventory-<data>.csv
.PARAMETER IncludiTutteLeIdentitaNonUmane
    Estende l'inventario a tutti i service principal non-umani (Application e
    ManagedIdentity oltre a ServiceIdentity). Utile come rete: un agente
    registrato come normale app registration NON compare fra le ServiceIdentity.
.EXAMPLE
    .\01-Get-AgentIdentityInventory.ps1
.EXAMPLE
    .\01-Get-AgentIdentityInventory.ps1 -IncludiTutteLeIdentitaNonUmane
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
    [string]$OutputCsv = (".\AI-AgentIdentityInventory-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')),
    [switch]$IncludiTutteLeIdentitaNonUmane
)
$ErrorActionPreference = 'Stop'

# Scope: le pagine dei cmdlet Entra dichiarano Application.Read.All, mentre la
# reference REST v1.0 delle agent identity richiede AgentIdentity.Read.All piu'
# il ruolo Agent ID Administrator per chi non e' owner. Chiediamo entrambi:
# se il tenant non conosce il secondo, il consenso ignora quello che non serve.
$ScopeRichiesti = @('Application.Read.All', 'Directory.Read.All')

if (-not (Get-MgContext)) {
    Write-Host 'Connessione a Microsoft Graph...' -ForegroundColor Cyan
    Connect-MgGraph -Scopes $ScopeRichiesti -NoWelcome
}

# Legge una proprieta' solo se esiste: evita il crash e la colonna che sembra
# vuota per errore quando il modulo cambia versione.
function Get-Prop {
    param($Oggetto, [string]$Nome)
    if ($null -ne $Oggetto -and ($Oggetto.PSObject.Properties.Name -contains $Nome)) {
        return $Oggetto.$Nome
    }
    return ''
}

$tipi = if ($IncludiTutteLeIdentitaNonUmane) {
    @('ServiceIdentity', 'Application', 'ManagedIdentity')
} else {
    @('ServiceIdentity')
}

$risultati = @()
foreach ($tipo in $tipi) {
    Write-Host ("Interrogazione servicePrincipalType eq '{0}'..." -f $tipo) -ForegroundColor Cyan
    try {
        # -All segue la paginazione da se'. ATTENZIONE: interrogando l'endpoint
        # tipizzato agentIdentity a mano via Invoke-MgGraphRequest il page size
        # MASSIMO e' 100 (non solo di default): senza seguire @odata.nextLink lo
        # script si fermerebbe in silenzio al centesimo agente.
        $sp = Get-MgServicePrincipal -Filter ("servicePrincipalType eq '{0}'" -f $tipo) `
                                     -All -ConsistencyLevel eventual -ErrorAction Stop
    }
    catch {
        Write-Warning ("Filtro su '{0}' non riuscito: {1}" -f $tipo, $_.Exception.Message)
        Write-Warning 'Se il tenant non conosce questo tipo, la lista sara vuota: non e un errore.'
        continue
    }

    foreach ($s in $sp) {
        $risultati += [pscustomobject]@{
            Tipo                = $tipo
            DisplayName         = Get-Prop $s 'DisplayName'
            Id                  = Get-Prop $s 'Id'
            AppId               = Get-Prop $s 'AppId'
            AccountEnabled      = Get-Prop $s 'AccountEnabled'
            CreatedDateTime     = Get-Prop $s 'AdditionalProperties.createdDateTime'
            AppOwnerTenantId    = Get-Prop $s 'AppOwnerOrganizationId'
            SignInAudience      = Get-Prop $s 'SignInAudience'
            Homepage            = Get-Prop $s 'Homepage'
            Tags                = ((Get-Prop $s 'Tags') -join '; ')
            Note                = Get-Prop $s 'Notes'
        }
    }
    Write-Host ("  trovate {0} identita" -f $sp.Count) -ForegroundColor Green
}

$risultati | Sort-Object Tipo, DisplayName |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host ("Esportato: {0}  ({1} identita)" -f $OutputCsv, $risultati.Count) -ForegroundColor Green
Write-Host ''
Write-Host 'LIMITE DA DICHIARARE AL CLIENTE:' -ForegroundColor Yellow
Write-Host 'questo e l inventario delle IDENTITA, non di cosa ciascun agente'
Write-Host 'puo vedere. Nessun cmdlet unisce una agent identity ai permessi'
Write-Host 'effettivi su SharePoint o OneDrive: quella giunzione resta analisi'
Write-Host 'manuale. Lo script 02 elenca i permessi CONCESSI, che e cosa diversa.'
if ($risultati.Count -ge 100) {
    Write-Host ''
    Write-Host 'NOTA: risultati >= 100. Verifica che la paginazione sia stata' -ForegroundColor Yellow
    Write-Host 'completata: su questa superficie il troncamento e silenzioso.' -ForegroundColor Yellow
}
