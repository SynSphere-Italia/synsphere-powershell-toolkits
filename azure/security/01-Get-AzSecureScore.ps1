#Requires -Modules Az.Accounts, Az.Security
<#
.SYNOPSIS
    Secure Score di Microsoft Defender for Cloud (punteggio di sicurezza complessivo).
.DESCRIPTION
    Il Secure Score sintetizza la postura di sicurezza della subscription. Lo script
    esporta il punteggio complessivo e per singolo control (corrente/massimo/percentuale).
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-SecureScore-<data>.csv
.EXAMPLE
    .\01-Get-AzSecureScore.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Richiede Defender for Cloud attivo. Permessi: Security Reader. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-SecureScore-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzSecuritySecureScore | ForEach-Object {
    $pct = if ($_.Max -gt 0) { [math]::Round(100 * $_.Current / $_.Max, 1) } else { 0 }
    [pscustomobject]@{
        SecureScore = $_.DisplayName
        Corrente    = [math]::Round($_.Current, 2)
        Massimo     = $_.Max
        Percentuale = "$pct%"
    }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$report | Format-Table -AutoSize
Write-Host ("Secure Score → {0}" -f $OutputCsv) -ForegroundColor Green
