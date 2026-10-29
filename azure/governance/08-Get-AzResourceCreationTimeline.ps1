#Requires -Modules Az.Accounts, Az.Monitor
<#
.SYNOPSIS
    Timeline delle risorse create/modificate (dall'Activity Log): chi, cosa, quando.
.DESCRIPTION
    Interroga l'Activity Log per le operazioni di scrittura riuscite e mostra chi ha
    creato/modificato risorse e quando. Utile per audit e per capire la crescita
    dell'ambiente. Sola lettura. NB: l'Activity Log copre ~90 giorni.
.PARAMETER Days
    Finestra in giorni (max 90). Default: 30.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-ResourceTimeline-<data>.csv
.EXAMPLE
    .\08-Get-AzResourceCreationTimeline.ps1 -Days 60
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 90)][int]$Days = 30,
    [string]$OutputCsv = (".\Az-ResourceTimeline-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$events = Get-AzActivityLog -StartTime (Get-Date).AddDays(-$Days) -WarningAction SilentlyContinue |
    Where-Object { $_.OperationName.Value -match '/write$' -and $_.Status.Value -eq 'Succeeded' -and $_.ResourceId }

$report = $events | ForEach-Object {
    [pscustomobject]@{
        Data      = $_.EventTimestamp
        Caller    = $_.Caller
        Operation = $_.OperationName.Value
        ResourceId = $_.ResourceId
    }
} | Sort-Object Data -Descending | Get-Unique -AsString
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} eventi di scrittura ({1} giorni) → {2}" -f @($report).Count, $Days, $OutputCsv) -ForegroundColor Green
