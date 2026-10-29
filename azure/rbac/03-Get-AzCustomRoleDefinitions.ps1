#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Report delle definizioni di ruolo CUSTOM (non built-in) del tenant.
.DESCRIPTION
    I ruoli custom vanno mantenuti e verificati: questo report elenca ogni ruolo
    personalizzato con le azioni consentite/negate e gli scope assegnabili. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-CustomRoles-<data>.csv
.EXAMPLE
    .\03-Get-AzCustomRoleDefinitions.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Reader + lettura roleDefinitions. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-CustomRoles-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzRoleDefinition | Where-Object { $_.IsCustom } | ForEach-Object {
    [pscustomobject]@{
        Ruolo            = $_.Name
        Descrizione      = $_.Description
        Actions          = ($_.Actions -join '; ')
        NotActions       = ($_.NotActions -join '; ')
        AssignableScopes = ($_.AssignableScopes -join '; ')
    }
}
$report | Sort-Object Ruolo | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} ruoli custom → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Green
