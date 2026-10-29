#Requires -Modules Az.Accounts, Az.Compute, Az.Resources
<#
.SYNOPSIS
    VM senza auto-shutdown configurato (potenziale risparmio sul compute).
.DESCRIPTION
    L'auto-shutdown spegne le VM fuori orario (tipico per ambienti dev/test): un risparmio
    facile. Lo script segnala le VM prive della pianificazione di spegnimento automatico.
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-VmsNoAutoShutdown-<data>.csv
.EXAMPLE
    .\08-Get-AzVmsWithoutAutoShutdown.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-VmsNoAutoShutdown-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

# Schedule di auto-shutdown: risorse Microsoft.DevTestLab/schedules con nome shutdown-computevm-<vm>
$withShutdown = New-Object System.Collections.Generic.HashSet[string]
Get-AzResource -ResourceType 'Microsoft.DevTestLab/schedules' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'shutdown-computevm-*' } |
    ForEach-Object { [void]$withShutdown.Add(($_.Name -replace '^shutdown-computevm-', '').ToLower()) }

$report = Get-AzVM | Where-Object { -not $withShutdown.Contains($_.Name.ToLower()) } | ForEach-Object {
    [pscustomobject]@{ VM = $_.Name; ResourceGroup = $_.ResourceGroupName; Size = $_.HardwareProfile.VmSize; AutoShutdown = 'ASSENTE' }
}
$report | Sort-Object ResourceGroup, VM | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} VM senza auto-shutdown → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
