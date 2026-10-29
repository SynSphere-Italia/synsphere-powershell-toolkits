#Requires -Modules Az.Accounts, Az.Monitor
<#
.SYNOPSIS
    Inventario degli Action Group (destinatari delle notifiche di alert).
.DESCRIPTION
    Gli Action Group definiscono CHI viene avvisato quando scatta un alert (email, SMS,
    webhook, ITSM…). Verificare che esistano e siano aggiornati è parte della readiness
    operativa. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-ActionGroups-<data>.csv
.EXAMPLE
    .\03-Get-AzActionGroups.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-ActionGroups-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzActionGroup | ForEach-Object {
    [pscustomobject]@{
        ActionGroup   = $_.Name
        ResourceGroup = $_.ResourceGroupName
        ShortName     = $_.GroupShortName
        Abilitato     = $_.Enabled
        Email         = @($_.EmailReceiver).Count
        SMS           = @($_.SmsReceiver).Count
        Webhook       = @($_.WebhookReceiver).Count
    }
}
$report | Sort-Object ActionGroup | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
if (-not $report) { Write-Host "Nessun Action Group: gli alert non notificano nessuno!" -ForegroundColor Yellow }
Write-Host ("{0} Action Group → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Green
