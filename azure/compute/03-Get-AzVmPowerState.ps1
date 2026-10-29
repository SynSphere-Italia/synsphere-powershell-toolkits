#Requires -Modules Az.Accounts, Az.Compute
<#
.SYNOPSIS
    VM non in esecuzione (deallocate/stopped): quali e da quanto.
.DESCRIPTION
    Distingue le VM "stopped" (spente ma allocate, pagano ancora il compute!) dalle
    "deallocated" (rilasciate, pagano solo i dischi). Evidenzia anche le stopped, che spesso
    sono un costo dimenticato. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-VmPowerState-<data>.csv
.EXAMPLE
    .\03-Get-AzVmPowerState.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-VmPowerState-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzVM -Status | Where-Object { $_.PowerState -ne 'VM running' } | ForEach-Object {
    $nota = switch -Wildcard ($_.PowerState) {
        '*deallocated*' { 'Deallocata: paga solo i dischi' }
        '*stopped*'     { 'STOPPED ma allocata: paga ancora il compute!' }
        default         { $_.PowerState }
    }
    [pscustomobject]@{
        VM            = $_.Name
        ResourceGroup = $_.ResourceGroupName
        PowerState    = $_.PowerState
        Nota          = $nota
    }
}
$report | Sort-Object PowerState, VM | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} VM non in esecuzione → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
