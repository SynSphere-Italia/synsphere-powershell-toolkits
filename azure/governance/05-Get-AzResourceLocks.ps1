#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Report di tutti i resource lock (CanNotDelete / ReadOnly) della subscription.
.DESCRIPTION
    I lock proteggono le risorse da cancellazioni o modifiche accidentali. Conoscere dove
    sono (e dove MANCANO sulle risorse critiche) è parte della governance. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-ResourceLocks-<data>.csv
.EXAMPLE
    .\05-Get-AzResourceLocks.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-ResourceLocks-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($l in Get-AzResourceLock) {
    [pscustomobject]@{
        LockName  = $l.Name
        Level     = $l.Properties.level     # CanNotDelete / ReadOnly
        Notes     = $l.Properties.notes
        Scope     = $l.ResourceId -replace '/providers/Microsoft.Authorization/locks/.*$', ''
    }
}
$report | Sort-Object Scope | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} resource lock in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
