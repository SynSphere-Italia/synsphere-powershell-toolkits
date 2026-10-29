#Requires -Modules Az.Accounts, Az.Compute
<#
.SYNOPSIS
    Dischi gestiti NON collegati (orfani): spreco di storage in fattura.
.DESCRIPTION
    I dischi "Unattached" continuano a essere fatturati pur non servendo a nessuna VM.
    Lo script li elenca con dimensione e SKU per valutarne lo snapshot+eliminazione. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-UnattachedDisks-<data>.csv
.EXAMPLE
    .\06-Get-AzUnattachedDisks.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-UnattachedDisks-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzDisk | Where-Object { $_.DiskState -eq 'Unattached' -or -not $_.ManagedBy } | ForEach-Object {
    [pscustomobject]@{
        Disco         = $_.Name
        ResourceGroup = $_.ResourceGroupName
        Location      = $_.Location
        SizeGB        = $_.DiskSizeGB
        Sku           = $_.Sku.Name
        Creato        = $_.TimeCreated
    }
}
$report | Sort-Object SizeGB -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$tot = ($report | Measure-Object SizeGB -Sum).Sum
Write-Host ("{0} dischi orfani ({1} GB totali in fattura) → {2}" -f @($report).Count, $tot, $OutputCsv) -ForegroundColor Yellow
