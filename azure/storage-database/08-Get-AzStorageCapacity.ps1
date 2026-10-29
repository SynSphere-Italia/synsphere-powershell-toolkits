#Requires -Modules Az.Accounts, Az.Storage, Az.Monitor
<#
.SYNOPSIS
    Capacità utilizzata da ogni storage account (metrica UsedCapacity).
.DESCRIPTION
    Mostra lo spazio occupato da ogni storage account leggendo la metrica UsedCapacity:
    utile per capacity planning e controllo costi. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-StorageCapacity-<data>.csv
.EXAMPLE
    .\08-Get-AzStorageCapacity.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    La metrica UsedCapacity è aggiornata ~ogni giorno. Permessi: Monitoring Reader.
    Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-StorageCapacity-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($sa in Get-AzStorageAccount) {
    $gb = 'n/d'
    try {
        $m = Get-AzMetric -ResourceId $sa.Id -MetricName 'UsedCapacity' -StartTime (Get-Date).AddDays(-2) -EndTime (Get-Date) -TimeGrain 1.00:00:00 -AggregationType Average -WarningAction SilentlyContinue -ErrorAction Stop
        $last = ($m.Data | Where-Object { $_.Average -ne $null } | Select-Object -Last 1).Average
        if ($last) { $gb = [math]::Round($last / 1GB, 2) }
    } catch { }
    [pscustomobject]@{
        StorageAccount = $sa.StorageAccountName
        ResourceGroup  = $sa.ResourceGroupName
        Replica        = $sa.Sku.Name
        UsataGB        = $gb
    }
}
$report | Sort-Object UsataGB -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Capacità di {0} storage account → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
