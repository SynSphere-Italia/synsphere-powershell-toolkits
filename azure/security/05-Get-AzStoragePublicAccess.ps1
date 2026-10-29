#Requires -Modules Az.Accounts, Az.Storage
<#
.SYNOPSIS
    Storage account a rischio: accesso pubblico ai blob, HTTPS non forzato, rete aperta.
.DESCRIPTION
    Controlla le impostazioni di sicurezza degli storage account: accesso pubblico ai blob
    consentito, traffico HTTP non cifrato permesso, accesso di rete pubblico. Sono le tre
    cause più comuni di data leak su Azure Storage. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-StoragePublicAccess-<data>.csv
.EXAMPLE
    .\05-Get-AzStoragePublicAccess.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-StoragePublicAccess-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzStorageAccount | ForEach-Object {
    $rischi = @()
    if ($_.AllowBlobPublicAccess) { $rischi += 'Blob pubblici consentiti' }
    if (-not $_.EnableHttpsTrafficOnly) { $rischi += 'HTTP non cifrato permesso' }
    if ($_.PublicNetworkAccess -eq 'Enabled' -and $_.NetworkRuleSet.DefaultAction -eq 'Allow') { $rischi += 'Rete pubblica aperta' }
    [pscustomobject]@{
        StorageAccount = $_.StorageAccountName
        ResourceGroup  = $_.ResourceGroupName
        Rischi         = if ($rischi) { $rischi -join '; ' } else { 'OK' }
    }
}
$report | Where-Object { $_.Rischi -ne 'OK' } | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$n = @($report | Where-Object { $_.Rischi -ne 'OK' }).Count
Write-Host ("{0} storage account con impostazioni a rischio → {1}" -f $n, $OutputCsv) -ForegroundColor Yellow
