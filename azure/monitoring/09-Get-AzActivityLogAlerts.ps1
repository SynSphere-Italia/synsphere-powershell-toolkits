#Requires -Modules Az.Accounts, Az.Monitor
<#
.SYNOPSIS
    Inventario degli Activity Log alert (incluse le notifiche di Service Health).
.DESCRIPTION
    Gli Activity Log alert avvisano su eventi amministrativi e di Service Health (incident
    Azure, manutenzioni). Verificare che esistano è parte della readiness operativa. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-ActivityLogAlerts-<data>.csv
.EXAMPLE
    .\09-Get-AzActivityLogAlerts.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-ActivityLogAlerts-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzActivityLogAlert | ForEach-Object {
    [pscustomobject]@{
        Alert         = $_.Name
        ResourceGroup = $_.ResourceGroupName
        Abilitato     = $_.Enabled
        Scope         = (($_.Scope) -join ', ')
    }
}
$report | Sort-Object Alert | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
if (-not $report) { Write-Host "Nessun Activity Log alert: valuta almeno un alert di Service Health." -ForegroundColor Yellow }
Write-Host ("{0} Activity Log alert → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Green
