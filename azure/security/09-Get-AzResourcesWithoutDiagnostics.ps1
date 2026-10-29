#Requires -Modules Az.Accounts, Az.Monitor, Az.Resources
<#
.SYNOPSIS
    Risorse SENZA impostazioni di diagnostica (gap di logging).
.DESCRIPTION
    Senza diagnostic settings i log non vengono inviati a un workspace/Storage e in caso di
    incidente non hai evidenze. Lo script verifica le risorse e segnala quelle senza alcuna
    impostazione di diagnostica. Sola lettura.
    NB: su tenant grandi l'esecuzione può richiedere tempo (una chiamata per risorsa).
.PARAMETER ResourceTypeLike
    Filtro opzionale sul tipo risorsa (wildcard), es. '*Microsoft.Storage*'. Default: tutte.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-NoDiagnostics-<data>.csv
.EXAMPLE
    .\09-Get-AzResourcesWithoutDiagnostics.ps1 -ResourceTypeLike '*Microsoft.KeyVault*'
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [string]$ResourceTypeLike = '*',
    [string]$OutputCsv = (".\Az-NoDiagnostics-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$resources = Get-AzResource | Where-Object { $_.ResourceType -like $ResourceTypeLike }
$report = [System.Collections.Generic.List[object]]::new()
$i = 0
foreach ($r in $resources) {
    $i++; Write-Progress -Activity "Verifica diagnostica" -Status "$i / $($resources.Count)" -PercentComplete ($i / [math]::Max($resources.Count,1) * 100)
    try {
        $ds = Get-AzDiagnosticSetting -ResourceId $r.ResourceId -ErrorAction Stop
        if (-not $ds) {
            $report.Add([pscustomobject]@{ Name = $r.Name; Tipo = $r.ResourceType; ResourceGroup = $r.ResourceGroupName })
        }
    } catch {
        # tipo non supporta diagnostica oppure accesso negato: ignora
    }
}
Write-Progress -Activity "Verifica diagnostica" -Completed
$report | Sort-Object Tipo, Name | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} risorse senza diagnostica → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
