#Requires -Modules Az.Accounts, Az.Storage
<#
.SYNOPSIS
    Regole di rete (firewall) degli storage account.
.DESCRIPTION
    Mostra per ogni storage account l'azione di default (Allow/Deny), l'accesso di rete
    pubblico e quante regole IP/VNet sono configurate: chi non ha un firewall è esposto.
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-StorageNetworkRules-<data>.csv
.EXAMPLE
    .\03-Get-AzStorageNetworkRules.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-StorageNetworkRules-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzStorageAccount | ForEach-Object {
    $nr = $_.NetworkRuleSet
    [pscustomobject]@{
        StorageAccount = $_.StorageAccountName
        ResourceGroup  = $_.ResourceGroupName
        RetePubblica   = $_.PublicNetworkAccess
        DefaultAction  = $nr.DefaultAction
        RegoleIP       = @($nr.IpRules).Count
        RegoleVNet     = @($nr.VirtualNetworkRules).Count
        Stato          = if ($nr.DefaultAction -eq 'Allow') { 'APERTO (default Allow)' } else { 'Filtrato' }
    }
}
$report | Sort-Object Stato, StorageAccount | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Regole di rete di {0} storage account → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
