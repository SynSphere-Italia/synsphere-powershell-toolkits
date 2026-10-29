#Requires -Modules Az.Accounts, Az.Network
<#
.SYNOPSIS
    Audit NSG: regole inbound che espongono porte a Internet (0.0.0.0/0 o "Internet").
.DESCRIPTION
    Le regole NSG che permettono traffico in ingresso da qualsiasi IP sono il rischio di
    sicurezza più comune (soprattutto su RDP 3389 e SSH 22). Lo script le elenca con un
    livello di rischio. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-NsgOpenPorts-<data>.csv
.EXAMPLE
    .\03-Get-AzNsgOpenPorts.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-NsgOpenPorts-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$risky = '22', '3389', '1433', '3306', '5432', '445', '*'
$report = foreach ($nsg in Get-AzNetworkSecurityGroup) {
    foreach ($r in $nsg.SecurityRules) {
        if ($r.Direction -ne 'Inbound' -or $r.Access -ne 'Allow') { continue }
        $src = @($r.SourceAddressPrefix) + @($r.SourceAddressPrefixes)
        if ($src -contains '*' -or $src -contains '0.0.0.0/0' -or $src -contains 'Internet') {
            $ports = @($r.DestinationPortRange) + @($r.DestinationPortRanges)
            $isRisky = ($ports | Where-Object { $_ -in $risky -or $_ -match '^(0-65535|0\.\.65535)$' }).Count -gt 0
            [pscustomobject]@{
                NSG       = $nsg.Name
                Regola    = $r.Name
                Priorita  = $r.Priority
                Porte     = ($ports -join ',')
                Sorgente  = ($src -join ',')
                Rischio   = if ($isRisky) { 'ALTO' } else { 'Da valutare' }
            }
        }
    }
}
$report | Sort-Object Rischio, NSG | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} regole inbound aperte a Internet → {1}. Priorità alle porte di gestione (RDP/SSH)." -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
