#Requires -Modules Az.Accounts, Az.Monitor
<#
.SYNOPSIS
    Inventario delle impostazioni di autoscale.
.DESCRIPTION
    L'autoscale adatta la capacità al carico (scale set, App Service). Lo script elenca le
    impostazioni con risorsa target, stato e numero di profili: utile per verificare cosa
    scala e cosa no. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-Autoscale-<data>.csv
.EXAMPLE
    .\07-Get-AzAutoscaleSettings.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-Autoscale-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzAutoscaleSetting | ForEach-Object {
    [pscustomobject]@{
        Autoscale     = $_.Name
        ResourceGroup = $_.ResourceGroupName
        Abilitato     = $_.Enabled
        TargetRisorsa = if ($_.TargetResourceUri) { ($_.TargetResourceUri -split '/')[-1] } else { '' }
        Profili       = @($_.Profile).Count
    }
}
$report | Sort-Object Autoscale | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} impostazioni di autoscale → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Green
