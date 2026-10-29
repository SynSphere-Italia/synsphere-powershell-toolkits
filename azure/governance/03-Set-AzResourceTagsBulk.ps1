#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Applica tag in BULK a tutte le risorse di un resource group (merge, non sovrascrive).
.DESCRIPTION
    Propaga un set di tag (es. CostCenter, Owner, Environment) a tutte le risorse di un
    resource group, in modalità merge (mantiene i tag esistenti). Operazione di SCRITTURA:
    supporta -WhatIf — usalo SEMPRE la prima volta.
.PARAMETER ResourceGroupName
    Resource group target (obbligatorio).
.PARAMETER Tags
    Hashtable dei tag da applicare, es. @{ CostCenter='IT'; Environment='Prod' } (obbligatorio).
.EXAMPLE
    .\03-Set-AzResourceTagsBulk.ps1 -ResourceGroupName rg-prod -Tags @{CostCenter='IT';Environment='Prod'} -WhatIf
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Testare con -WhatIf.
    Permessi: Contributor sul resource group. Prima esegui: Connect-AzAccount
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][string]$ResourceGroupName,
    [Parameter(Mandatory)][hashtable]$Tags
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$resources = Get-AzResource -ResourceGroupName $ResourceGroupName
Write-Host ("{0} risorse in {1}" -f $resources.Count, $ResourceGroupName) -ForegroundColor Cyan
foreach ($r in $resources) {
    if ($PSCmdlet.ShouldProcess($r.Name, "Merge tag $($Tags.Keys -join ',')")) {
        Update-AzTag -ResourceId $r.ResourceId -Tag $Tags -Operation Merge | Out-Null
        Write-Host "  taggata: $($r.Name)" -ForegroundColor Green
    }
}
Write-Host "Completato (usa -WhatIf per simulare senza applicare)." -ForegroundColor Yellow
