#Requires -Modules Az.Accounts, Az.Sql
<#
.SYNOPSIS
    Sicurezza dei database SQL: cifratura trasparente (TDE) e auditing.
.DESCRIPTION
    Verifica per ogni database lo stato della Transparent Data Encryption e, a livello server,
    se l'auditing è attivo. Sono requisiti tipici di compliance (GDPR, ISO 27001). Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-SqlSecurity-<data>.csv
.EXAMPLE
    .\07-Get-AzSqlSecurity.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader/SQL Security Manager. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-SqlSecurity-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($srv in Get-AzSqlServer) {
    $audit = try { (Get-AzSqlServerAudit -ServerName $srv.ServerName -ResourceGroupName $srv.ResourceGroupName).BlobStorageTargetState } catch { 'n/d' }
    Get-AzSqlDatabase -ServerName $srv.ServerName -ResourceGroupName $srv.ResourceGroupName |
        Where-Object { $_.DatabaseName -ne 'master' } | ForEach-Object {
            $tde = try { (Get-AzSqlDatabaseTransparentDataEncryption -ServerName $srv.ServerName -ResourceGroupName $srv.ResourceGroupName -DatabaseName $_.DatabaseName).State } catch { 'n/d' }
            [pscustomobject]@{
                Server = $srv.ServerName; Database = $_.DatabaseName
                TDE = $tde; AuditingServer = $audit
            }
        }
}
$report | Sort-Object Server, Database | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Sicurezza di {0} database SQL → {1}. Verifica TDE/Audit 'Disabled'." -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
