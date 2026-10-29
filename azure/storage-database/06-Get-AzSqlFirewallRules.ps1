#Requires -Modules Az.Accounts, Az.Sql
<#
.SYNOPSIS
    Regole firewall dei SQL Server logici (evidenzia le regole troppo aperte).
.DESCRIPTION
    Le regole firewall a livello server controllano chi può raggiungere i database SQL.
    Lo script le elenca e segnala quelle rischiose: "Allow Azure services" (0.0.0.0) e
    intervalli molto ampi. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-SqlFirewall-<data>.csv
.EXAMPLE
    .\06-Get-AzSqlFirewallRules.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-SqlFirewall-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($srv in Get-AzSqlServer) {
    foreach ($r in Get-AzSqlServerFirewallRule -ServerName $srv.ServerName -ResourceGroupName $srv.ResourceGroupName) {
        $rischio = if ($r.StartIpAddress -eq '0.0.0.0' -and $r.EndIpAddress -eq '0.0.0.0') { 'Allow Azure services' }
                   elseif ($r.StartIpAddress -eq '0.0.0.0' -and $r.EndIpAddress -eq '255.255.255.255') { 'APERTO A TUTTI!' }
                   else { 'specifico' }
        [pscustomobject]@{
            Server = $srv.ServerName; ResourceGroup = $srv.ResourceGroupName
            Regola = $r.FirewallRuleName; DaIP = $r.StartIpAddress; AIP = $r.EndIpAddress; Rischio = $rischio
        }
    }
}
$report | Sort-Object Rischio, Server | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} regole firewall SQL → {1}. Verifica le regole 'APERTO A TUTTI'." -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
