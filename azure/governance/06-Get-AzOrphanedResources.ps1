#Requires -Modules Az.Accounts, Az.Compute, Az.Network
<#
.SYNOPSIS
    Trova le risorse ORFANE: dischi non collegati, IP pubblici/NIC/NSG non associati.
.DESCRIPTION
    Le risorse orfane restano in fattura senza dare valore. Lo script individua:
    dischi managed "Unattached", IP pubblici senza associazione, schede di rete (NIC)
    non collegate a una VM, e NSG non associati a subnet/NIC. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-OrphanedResources-<data>.csv
.EXAMPLE
    .\06-Get-AzOrphanedResources.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-OrphanedResources-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = [System.Collections.Generic.List[object]]::new()
$add = { param($type, $name, $rg, $loc) $report.Add([pscustomobject]@{ Tipo = $type; Name = $name; ResourceGroup = $rg; Location = $loc }) }

# Dischi managed non collegati
Get-AzDisk | Where-Object { $_.DiskState -eq 'Unattached' -or -not $_.ManagedBy } |
    ForEach-Object { & $add 'Disco non collegato' $_.Name $_.ResourceGroupName $_.Location }
# IP pubblici senza associazione
Get-AzPublicIpAddress | Where-Object { -not $_.IpConfiguration } |
    ForEach-Object { & $add 'IP pubblico inutilizzato' $_.Name $_.ResourceGroupName $_.Location }
# NIC non collegate a VM
Get-AzNetworkInterface | Where-Object { -not $_.VirtualMachine } |
    ForEach-Object { & $add 'NIC non collegata' $_.Name $_.ResourceGroupName $_.Location }
# NSG non associati
Get-AzNetworkSecurityGroup | Where-Object { -not $_.Subnets -and -not $_.NetworkInterfaces } |
    ForEach-Object { & $add 'NSG non associato' $_.Name $_.ResourceGroupName $_.Location }

$report | Sort-Object Tipo, ResourceGroup | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} risorse orfane (potenziale risparmio) → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
