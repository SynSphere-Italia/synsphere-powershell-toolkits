<#
.SYNOPSIS
    Inventario di app, flow, connessioni e impostazioni AI in Power Platform.
.DESCRIPTION
    E' il censimento della shadow AI: cosa hanno costruito le persone senza
    passare dall'IT, in quali ambienti, con quali connessioni verso quali dati.

    ATTENZIONE ALL'AMBIENTE DI ESECUZIONE. Il modulo
    Microsoft.PowerApps.Administration.PowerShell gira SOLO su Windows PowerShell
    5.x (powershell.exe), non su PowerShell 7. Per questo e' l'unico script del
    toolkit che va lanciato separatamente: gli altri vogliono pwsh.exe. Le
    credenziali di Add-PowerAppsAccount valgono circa 8 ore.

    QUATTRO BUCHI DELL'INVENTARIO, da dichiarare invece di scoprirli dopo:
    - Get-AdminPowerAppConnector restituisce solo i connettori CUSTOM, e nemmeno
      quelli contenuti in una solution: i connettori standard usati da app e flow
      non compaiono.
    - I chatbot classici della prima generazione di Power Virtual Agents non sono
      tracciati: sono esattamente i piu' vecchi e meno presidiati.
    - Il draft non pubblicato di un agente non e' visibile: un agente puo' usare
      in bozza connessioni che l'inventario non riporta.
    - I workflow dell'agente Workflows di Microsoft 365 Copilot vivono in un
      ambiente nascosto: un ciclo su Get-AdminPowerAppEnvironment li perde per
      costruzione.
    Inoltre Get-AdminPowerAppLicenses riflette le assegnazioni con fino a 7
    giorni di ritardo e include solo chi ha effettivamente aperto un servizio.

    Nessun requisito di licenza aggiuntivo: l'accesso e' basato sui ruoli Entra.

    Sola lettura.
.PARAMETER CartellaOutput
    Cartella dei CSV. Default: la cartella corrente.
.EXAMPLE
    powershell.exe -File .\09-Get-ShadowAIPowerPlatform.ps1
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Cmdlet verificati su learn.microsoft.com il 19 agosto 2026.
    Le superfici di governance degli agenti AI cambiano ogni mese: prima di un
    uso in produzione esegui 00-Test-Prerequisiti.ps1, che controlla che i
    cmdlet esistano davvero nella versione di modulo installata.
#>
#Requires -Modules Microsoft.PowerApps.Administration.PowerShell
[CmdletBinding()]
param(
    [string]$CartellaOutput = '.'
)
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -eq 'Core') {
    throw 'Questo script gira solo su Windows PowerShell 5.x (powershell.exe), non su PowerShell 7. Il modulo Power Apps non e compatibile con .NET Core.'
}

$stamp = Get-Date -Format 'yyyyMMdd'
function Salva { param($Dati, [string]$Nome)
    $p = Join-Path $CartellaOutput ("AI-PP-{0}-{1}.csv" -f $Nome, $stamp)
    $Dati | Export-Csv -Path $p -NoTypeInformation -Encoding UTF8
    Write-Host ("  {0,-26} {1,5} righe  ->  {2}" -f $Nome, @($Dati).Count, $p) -ForegroundColor Green
}

Write-Host 'Autenticazione a Power Platform...' -ForegroundColor Cyan
Add-PowerAppsAccount

Write-Host ''
Write-Host 'Raccolta inventario...' -ForegroundColor Cyan

# Ambienti, con le impostazioni di AI generativa: e' la riga che dice se in un
# ambiente le funzioni AI sono accese.
try {
    $amb = Get-AdminPowerAppEnvironment -GetGenerativeAiSettings -ErrorAction Stop
}
catch {
    Write-Warning 'GetGenerativeAiSettings non disponibile in questa versione del modulo: rileggo senza.'
    $amb = Get-AdminPowerAppEnvironment
}
Salva ($amb | Select-Object DisplayName, EnvironmentName, EnvironmentType, Location,
        @{n='CreatoDa';e={$_.CreatedBy.displayName}}, CreatedTime,
        @{n='AiGenerativa';e={ if ($_.PSObject.Properties.Name -contains 'GenerativeAiSettings') { ($_.GenerativeAiSettings | ConvertTo-Json -Compress -Depth 3) } else { '' } }}) 'Ambienti'

Salva (Get-AdminPowerApp | Select-Object DisplayName, AppName, EnvironmentName,
        @{n='Proprietario';e={$_.Owner.displayName}}, CreatedTime, LastModifiedTime) 'App'

Salva (Get-AdminFlow | Select-Object DisplayName, FlowName, EnvironmentName,
        @{n='Proprietario';e={$_.CreatedBy.displayName}}, Enabled, CreatedTime) 'Flow'

Salva (Get-AdminPowerAppConnection | Select-Object ConnectionName, DisplayName,
        ConnectorName, EnvironmentName, @{n='Proprietario';e={$_.CreatedBy.displayName}},
        CreatedTime, Statuses) 'Connessioni'

Salva (Get-AdminPowerAppConnector | Select-Object DisplayName, ConnectorName,
        EnvironmentName, @{n='Proprietario';e={$_.CreatedBy.displayName}}, CreatedTime) 'ConnettoriCustom'

try { Salva (Get-DlpPolicy | Select-Object DisplayName, PolicyName, Type, CreatedTime, LastModifiedTime) 'PolicyDLP' }
catch { Write-Warning ("Get-DlpPolicy: {0}" -f $_.Exception.Message) }

try {
    $ts = Get-TenantSettings
    Salva ($ts.PSObject.Properties | Select-Object Name, Value) 'ImpostazioniTenant'
}
catch { Write-Warning ("Get-TenantSettings: {0}" -f $_.Exception.Message) }

Write-Host ''
Write-Host 'Fatto.' -ForegroundColor Green
Write-Host ''
Write-Host 'DA DICHIARARE NEL REPORT:' -ForegroundColor Yellow
Write-Host '  - i connettori STANDARD non sono in questo inventario'
Write-Host '  - i chatbot PVA di prima generazione non sono tracciati'
Write-Host '  - le bozze non pubblicate non sono visibili'
Write-Host '  - gli agenti di Copilot Studio NON hanno un cmdlet: usa lo script 10'
Write-Host ("  - rilevato il {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
