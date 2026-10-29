#Requires -Modules Az.Accounts, Az.Sql
<#
.SYNOPSIS
    Politiche di retention dei backup SQL (short-term e long-term) per database.
.DESCRIPTION
    Verifica per ogni database i giorni di retention dei backup a breve termine e le policy
    di long-term retention (settimanale/mensile/annuale): essenziale per la conformità ai
    requisiti di DR e compliance. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-SqlBackupRetention-<data>.csv
.EXAMPLE
    .\09-Get-AzSqlBackupRetention.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-SqlBackupRetention-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($srv in Get-AzSqlServer) {
    Get-AzSqlDatabase -ServerName $srv.ServerName -ResourceGroupName $srv.ResourceGroupName |
        Where-Object { $_.DatabaseName -ne 'master' } | ForEach-Object {
            $p = @{ s = $srv.ServerName; r = $srv.ResourceGroupName; d = $_.DatabaseName }
            $short = try { (Get-AzSqlDatabaseBackupShortTermRetentionPolicy -ServerName $p.s -ResourceGroupName $p.r -DatabaseName $p.d).RetentionDays } catch { 'n/d' }
            $ltr = try { Get-AzSqlDatabaseLongTermRetentionPolicy -ServerName $p.s -ResourceGroupName $p.r -DatabaseName $p.d } catch { $null }
            [pscustomobject]@{
                Server = $p.s; Database = $p.d
                ShortTermGiorni = $short
                LTR_Settimanale = if ($ltr) { $ltr.WeeklyRetention } else { '' }
                LTR_Mensile     = if ($ltr) { $ltr.MonthlyRetention } else { '' }
                LTR_Annuale     = if ($ltr) { $ltr.YearlyRetention } else { '' }
            }
        }
}
$report | Sort-Object Server, Database | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Retention backup di {0} database SQL → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Green
