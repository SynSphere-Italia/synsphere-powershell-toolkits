#Requires -Modules Az.Accounts, Az.Monitor
<#
.SYNOPSIS
    Inventario delle regole di alert (metric alert + scheduled query alert).
.DESCRIPTION
    Mostra quali alert sono configurati, su quali risorse, con severità e stato: per capire
    cosa è monitorato e cosa NO. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-AlertRules-<data>.csv
.EXAMPLE
    .\02-Get-AzAlertRules.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-AlertRules-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = [System.Collections.Generic.List[object]]::new()
try {
    Get-AzMetricAlertRuleV2 | ForEach-Object {
        $report.Add([pscustomobject]@{
            Alert = $_.Name; Tipo = 'Metric'; ResourceGroup = $_.ResourceGroupName
            Severita = $_.Severity; Abilitato = $_.Enabled; Scope = (($_.Scopes | ForEach-Object { ($_ -split '/')[-1] }) -join ', ')
        })
    }
} catch { Write-Warning "Metric alert: $($_.Exception.Message)" }
try {
    Get-AzScheduledQueryRule | ForEach-Object {
        $report.Add([pscustomobject]@{
            Alert = $_.Name; Tipo = 'Scheduled Query'; ResourceGroup = $_.ResourceGroupName
            Severita = $_.Severity; Abilitato = $_.Enabled; Scope = (($_.Scope | ForEach-Object { ($_ -split '/')[-1] }) -join ', ')
        })
    }
} catch { Write-Warning "Scheduled query: $($_.Exception.Message)" }
$report | Sort-Object Tipo, Alert | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} regole di alert → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
