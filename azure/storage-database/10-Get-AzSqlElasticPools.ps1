#Requires -Modules Az.Accounts, Az.Sql
<#
.SYNOPSIS
    Inventario degli elastic pool SQL (capacità e database contenuti).
.DESCRIPTION
    Gli elastic pool condividono le risorse tra più database: ottimi per il risparmio se ben
    dimensionati. Lo script elenca i pool con edizione, capacità e numero di database, per
    valutarne il riempimento. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-SqlElasticPools-<data>.csv
.EXAMPLE
    .\10-Get-AzSqlElasticPools.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-SqlElasticPools-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($srv in Get-AzSqlServer) {
    Get-AzSqlElasticPool -ServerName $srv.ServerName -ResourceGroupName $srv.ResourceGroupName -ErrorAction SilentlyContinue | ForEach-Object {
        $dbCount = try { (Get-AzSqlElasticPoolDatabase -ServerName $srv.ServerName -ResourceGroupName $srv.ResourceGroupName -ElasticPoolName $_.ElasticPoolName).Count } catch { 'n/d' }
        [pscustomobject]@{
            Server = $srv.ServerName; ResourceGroup = $srv.ResourceGroupName
            ElasticPool = $_.ElasticPoolName; Edizione = $_.Edition
            Capacita = $_.Capacity; Database = $dbCount
        }
    }
}
if ($report) {
    $report | Sort-Object Server, ElasticPool | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host ("{0} elastic pool → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Green
} else {
    Write-Host "Nessun elastic pool nella subscription." -ForegroundColor Green
}
