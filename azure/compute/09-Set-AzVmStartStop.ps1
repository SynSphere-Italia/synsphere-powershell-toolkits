#Requires -Modules Az.Accounts, Az.Compute
<#
.SYNOPSIS
    Avvia o spegne (deallocate) in blocco le VM di un resource group o per tag.
.DESCRIPTION
    Operazione di gestione per accendere/spegnere gruppi di VM (es. ambienti dev/test fuori
    orario). Lo Stop esegue il deallocate (smette di pagare il compute). Operazione di
    SCRITTURA: supporta -WhatIf — usalo SEMPRE la prima volta.
.PARAMETER Action
    'Start' o 'Stop' (obbligatorio).
.PARAMETER ResourceGroupName
    Limita al resource group indicato (opzionale).
.PARAMETER TagName / TagValue
    Limita alle VM con il tag indicato (opzionale).
.EXAMPLE
    .\09-Set-AzVmStartStop.ps1 -Action Stop -ResourceGroupName rg-devtest -WhatIf
.EXAMPLE
    .\09-Set-AzVmStartStop.ps1 -Action Start -TagName Environment -TagValue Dev
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Testare con -WhatIf.
    Permessi: Virtual Machine Contributor. Prima esegui: Connect-AzAccount
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][ValidateSet('Start', 'Stop')][string]$Action,
    [string]$ResourceGroupName,
    [string]$TagName,
    [string]$TagValue
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$vms = if ($ResourceGroupName) { Get-AzVM -ResourceGroupName $ResourceGroupName } else { Get-AzVM }
if ($TagName) { $vms = $vms | Where-Object { $_.Tags[$TagName] -eq $TagValue } }
Write-Host ("{0} VM selezionate per: {1}" -f $vms.Count, $Action) -ForegroundColor Cyan

foreach ($vm in $vms) {
    if ($PSCmdlet.ShouldProcess($vm.Name, $Action)) {
        if ($Action -eq 'Start') { Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name | Out-Null }
        else { Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force | Out-Null }
        Write-Host ("  {0}: {1}" -f $Action, $vm.Name) -ForegroundColor Green
    }
}
Write-Host "Completato (usa -WhatIf per simulare)." -ForegroundColor Yellow
