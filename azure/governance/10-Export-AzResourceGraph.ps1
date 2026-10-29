#Requires -Modules Az.Accounts, Az.ResourceGraph
<#
.SYNOPSIS
    Export completo delle risorse via Azure Resource Graph (veloce e cross-subscription).
.DESCRIPTION
    Azure Resource Graph interroga TUTTE le subscription in una query KQL, molto più
    velocemente di Get-AzResource su tenant grandi. Esporta nome, tipo, region, resource
    group, subscription e tag, con paginazione automatica. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-ResourceGraph-<data>.csv
.EXAMPLE
    .\10-Export-AzResourceGraph.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Modulo: Install-Module Az.ResourceGraph. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-ResourceGraph-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$query = "Resources | project name, type, location, resourceGroup, subscriptionId, tags | order by type asc"
$rows = [System.Collections.Generic.List[object]]::new()
$skip = $null
do {
    $batch = if ($skip) { Search-AzGraph -Query $query -First 1000 -SkipToken $skip } else { Search-AzGraph -Query $query -First 1000 }
    foreach ($r in $batch) {
        $rows.Add([pscustomobject]@{
            Name = $r.name; Type = $r.type; Location = $r.location
            ResourceGroup = $r.resourceGroup; SubscriptionId = $r.subscriptionId
            Tags = if ($r.tags) { ($r.tags.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '; ' } else { '' }
        })
    }
    $skip = $batch.SkipToken
} while ($skip)

$rows | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} risorse via Resource Graph → {1}" -f $rows.Count, $OutputCsv) -ForegroundColor Green
