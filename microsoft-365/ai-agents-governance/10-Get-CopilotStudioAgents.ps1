<#
.SYNOPSIS
    Inventario degli agenti di Copilot Studio via Azure Resource Graph.
.DESCRIPTION
    PERCHE' PASSA DA AZURE RESOURCE GRAPH E NON DA UN CMDLET DEDICATO: perche'
    un cmdlet dedicato non esiste. Il modulo di amministrazione di Power Platform
    ha circa 170 cmdlet e nessuno di essi contiene bot, chatbot, copilot o agent
    nel nome. L'unica via PowerShell all'inventario degli agenti e' la query su
    Resource Graph; le alternative sono la REST API di Power Platform o la CLI
    pac. Chi promette "un cmdlet per inventariare gli agenti" sta descrivendo
    qualcosa che ad agosto 2026 non c'e'.

    Corollario operativo: NON esiste un modo PowerShell per mettere in quarantena
    un agente. Set-AppAsQuarantined riguarda le app, non gli agenti; la
    quarantena passa da REST o da 'pac copilot quarantine'.

    DUE LIMITI DELL'INVENTARIO: la latenza e' di circa 20 minuti, e oltre 200
    risorse per tipo la risposta mostra 200 elementi CASUALI - non i primi 200.
    I campi che servono alla governance (connettori, canali, condivisione,
    isQuarantined) sono in preview e possono cambiare forma.

    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\AI-CopilotStudioAgents-<data>.csv
.PARAMETER OutputConnettoriCsv
    CSV del mapping agente -> connettori. Default: .\AI-CopilotStudioConnettori-<data>.csv
.EXAMPLE
    .\10-Get-CopilotStudioAgents.ps1
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Cmdlet verificati su learn.microsoft.com il 19 agosto 2026.
    Le superfici di governance degli agenti AI cambiano ogni mese: prima di un
    uso in produzione esegui 00-Test-Prerequisiti.ps1, che controlla che i
    cmdlet esistano davvero nella versione di modulo installata.
#>
#Requires -Modules Az.ResourceGraph
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\AI-CopilotStudioAgents-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')),
    [string]$OutputConnettoriCsv = (".\AI-CopilotStudioConnettori-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    Write-Host 'Connessione ad Azure...' -ForegroundColor Cyan
    Connect-AzAccount | Out-Null
}

$queryAgenti = @'
PowerPlatformResources
| where type == "microsoft.copilotstudio/agents"
| project name,
          agentId = id,
          environment = tostring(properties.environmentName),
          owner = tostring(properties.ownerId),
          state = tostring(properties.state),
          createdOn = tostring(properties.createdOn),
          modifiedOn = tostring(properties.modifiedOn),
          isQuarantined = tostring(properties.isQuarantined),
          channels = tostring(properties.channels),
          sharing = tostring(properties.sharing)
| order by name asc
'@

Write-Host 'Interrogazione di Azure Resource Graph...' -ForegroundColor Cyan
try {
    $agenti = Search-AzGraph -Query $queryAgenti -First 1000 -ErrorAction Stop
}
catch {
    Write-Warning ("Query non riuscita: {0}" -f $_.Exception.Message)
    Write-Warning 'Se il tipo di risorsa non e ancora esposto nel tuo tenant, la tabella PowerPlatformResources puo essere vuota: non e un errore dello script.'
    return
}

if (-not $agenti) {
    Write-Host ''
    Write-Host 'Nessun agente restituito. Due spiegazioni possibili, entrambe normali:' -ForegroundColor Yellow
    Write-Host '  1. nel tenant non ci sono agenti di Copilot Studio;'
    Write-Host '  2. la tabella PowerPlatformResources non e popolata per questo tenant.'
    Write-Host 'In entrambi i casi NON concludere che non esiste shadow AI: incrocia'
    Write-Host 'con lo script 09 e con il portale di amministrazione.'
    return
}

$agenti | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("  {0} agenti  ->  {1}" -f @($agenti).Count, $OutputCsv) -ForegroundColor Green

# Mapping agente -> connettori: e' la parte che dice a quali dati un agente
# arriva. mv-expand perche' i connettori sono un array annidato.
$queryConnettori = @'
PowerPlatformResources
| where type == "microsoft.copilotstudio/agents"
| mv-expand connettore = properties.powerPlatformConnectors
| project agente = name,
          environment = tostring(properties.environmentName),
          owner = tostring(properties.ownerId),
          connettore = tostring(connettore.name),
          tipoConnettore = tostring(connettore.type)
| order by agente asc, connettore asc
'@

try {
    $conn = Search-AzGraph -Query $queryConnettori -First 1000 -ErrorAction Stop
    if ($conn) {
        $conn | Export-Csv -Path $OutputConnettoriCsv -NoTypeInformation -Encoding UTF8
        Write-Host ("  {0} associazioni agente-connettore  ->  {1}" -f @($conn).Count, $OutputConnettoriCsv) -ForegroundColor Green
    }
    else {
        Write-Host '  nessun connettore associato restituito (campo in preview)' -ForegroundColor Yellow
    }
}
catch { Write-Warning ("Query connettori non riuscita: {0}" -f $_.Exception.Message) }

Write-Host ''
if (@($agenti).Count -ge 200) {
    Write-Host 'ATTENZIONE: 200 o piu risultati. Oltre 200 risorse per tipo, Resource' -ForegroundColor Red
    Write-Host 'Graph restituisce 200 elementi CASUALI: questo elenco NON e completo'
    Write-Host 'e non e nemmeno "i primi 200". Segmenta la query per ambiente.'
}
Write-Host ("Rilevato il {0}. Latenza dell inventario: ~20 minuti." -f (Get-Date -Format 'yyyy-MM-dd HH:mm')) -ForegroundColor Cyan
Write-Host 'La quarantena di un agente NON e possibile in PowerShell: serve REST o pac.' -ForegroundColor Yellow
