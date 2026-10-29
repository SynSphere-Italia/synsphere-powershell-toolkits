#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Trova i resource group VUOTI (senza alcuna risorsa): candidati alla dismissione.
.DESCRIPTION
    I resource group vuoti sono residui di progetti chiusi o deploy falliti. Elencarli
    aiuta a tenere pulita la subscription. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-EmptyResourceGroups-<data>.csv
.EXAMPLE
    .\04-Get-AzEmptyResourceGroups.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-EmptyResourceGroups-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($rg in Get-AzResourceGroup) {
    $count = (Get-AzResource -ResourceGroupName $rg.ResourceGroupName).Count
    if ($count -eq 0) {
        [pscustomobject]@{
            ResourceGroup = $rg.ResourceGroupName
            Location      = $rg.Location
            ProvisioningState = $rg.ProvisioningState
        }
    }
}
if ($report) {
    $report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host ("{0} resource group VUOTI → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
} else {
    Write-Host "Nessun resource group vuoto." -ForegroundColor Green
}
