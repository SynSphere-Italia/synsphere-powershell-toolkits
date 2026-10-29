#Requires -Modules Az.Accounts, Az.Monitor
<#
.SYNOPSIS
    Export dell'Activity Log: chi ha fatto cosa e quando sulla subscription.
.DESCRIPTION
    L'Activity Log registra tutte le operazioni di gestione (create/update/delete, azioni
    amministrative). Lo script lo esporta filtrando le operazioni riuscite: utile per audit
    e analisi post-incidente. Sola lettura. NB: l'Activity Log copre ~90 giorni.
.PARAMETER Days
    Finestra in giorni (max 90). Default: 7.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-ActivityLog-<data>.csv
.EXAMPLE
    .\01-Export-AzActivityLog.ps1 -Days 30
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 90)][int]$Days = 7,
    [string]$OutputCsv = (".\Az-ActivityLog-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzActivityLog -StartTime (Get-Date).AddDays(-$Days) -WarningAction SilentlyContinue | ForEach-Object {
    [pscustomobject]@{
        Data       = $_.EventTimestamp
        Caller     = $_.Caller
        Operazione = $_.OperationName.LocalizedValue
        Stato      = $_.Status.Value
        Risorsa    = ($_.ResourceId -split '/')[-1]
        ResourceGroup = $_.ResourceGroupName
    }
}
$report | Sort-Object Data -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} eventi Activity Log ({1} giorni) → {2}" -f @($report).Count, $Days, $OutputCsv) -ForegroundColor Green
