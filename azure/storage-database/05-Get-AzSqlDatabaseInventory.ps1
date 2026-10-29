#Requires -Modules Az.Accounts, Az.Sql
<#
.SYNOPSIS
    Inventario dei database SQL di Azure (edizione, tier di servizio, dimensione).
.DESCRIPTION
    Elenca i SQL Server logici e i relativi database con edizione, service objective (tier di
    performance), dimensione massima e stato. Base per ottimizzazione e capacity planning.
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-SqlInventory-<data>.csv
.EXAMPLE
    .\05-Get-AzSqlDatabaseInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-SqlInventory-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($srv in Get-AzSqlServer) {
    Get-AzSqlDatabase -ServerName $srv.ServerName -ResourceGroupName $srv.ResourceGroupName |
        Where-Object { $_.DatabaseName -ne 'master' } |
        ForEach-Object {
            [pscustomobject]@{
                Server        = $srv.ServerName
                Database      = $_.DatabaseName
                ResourceGroup = $srv.ResourceGroupName
                Edizione      = $_.Edition
                Tier          = $_.CurrentServiceObjectiveName
                MaxGB         = [math]::Round($_.MaxSizeBytes / 1GB, 1)
                Stato         = $_.Status
            }
        }
}
$report | Sort-Object Server, Database | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} database SQL → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Green
