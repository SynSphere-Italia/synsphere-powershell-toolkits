#Requires -Modules Az.Accounts, Az.Monitor, Az.Resources
<#
.SYNOPSIS
    Report delle diagnostic settings configurate e delle loro destinazioni.
.DESCRIPTION
    Mostra, per le risorse che le hanno, DOVE vengono inviati i log (Log Analytics, Storage,
    Event Hub): utile per verificare che la telemetria converga dove serve. Sola lettura.
    NB: su tenant grandi l'esecuzione può richiedere tempo (una chiamata per risorsa).
.PARAMETER ResourceTypeLike
    Filtro opzionale sul tipo risorsa (wildcard). Default: tutte.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-DiagnosticSettings-<data>.csv
.EXAMPLE
    .\08-Get-AzDiagnosticSettingsReport.ps1 -ResourceTypeLike '*Microsoft.Network*'
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [string]$ResourceTypeLike = '*',
    [string]$OutputCsv = (".\Az-DiagnosticSettings-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$resources = Get-AzResource | Where-Object { $_.ResourceType -like $ResourceTypeLike }
$report = [System.Collections.Generic.List[object]]::new()
$i = 0
foreach ($r in $resources) {
    $i++; Write-Progress -Activity "Lettura diagnostic settings" -Status "$i / $($resources.Count)" -PercentComplete ($i / [math]::Max($resources.Count,1) * 100)
    try {
        foreach ($ds in Get-AzDiagnosticSetting -ResourceId $r.ResourceId -ErrorAction Stop) {
            $dest = @()
            if ($ds.WorkspaceId) { $dest += 'LogAnalytics' }
            if ($ds.StorageAccountId) { $dest += 'Storage' }
            if ($ds.EventHubAuthorizationRuleId -or $ds.EventHubName) { $dest += 'EventHub' }
            $report.Add([pscustomobject]@{
                Risorsa = $r.Name; Tipo = $r.ResourceType; Setting = $ds.Name
                Destinazioni = ($dest -join ', ')
            })
        }
    } catch { }
}
Write-Progress -Activity "Lettura diagnostic settings" -Completed
$report | Sort-Object Tipo, Risorsa | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} diagnostic settings configurate → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
