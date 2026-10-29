#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Trova le risorse Azure SENZA tag (o con tag mancanti rispetto a un set richiesto).
.DESCRIPTION
    I tag sono la base di cost allocation, ownership e automazione. Questo report elenca
    le risorse prive di tag o a cui mancano i tag obbligatori indicati. Sola lettura.
.PARAMETER RequiredTags
    Opzionale: elenco di tag obbligatori (es. 'CostCenter','Owner','Environment').
    Se omesso, segnala le risorse senza ALCUN tag.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-UntaggedResources-<data>.csv
.EXAMPLE
    .\02-Get-AzUntaggedResources.ps1 -RequiredTags CostCenter,Owner,Environment
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [string[]]$RequiredTags,
    [string]$OutputCsv = (".\Az-UntaggedResources-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($r in Get-AzResource) {
    $tags = $r.Tags
    $missing = if ($RequiredTags) {
        @($RequiredTags | Where-Object { -not $tags -or -not $tags.ContainsKey($_) })
    } elseif (-not $tags -or $tags.Count -eq 0) {
        @('(nessun tag)')
    } else { @() }
    if ($missing.Count -gt 0) {
        [pscustomobject]@{
            Name          = $r.Name
            Type          = $r.ResourceType
            ResourceGroup = $r.ResourceGroupName
            Location      = $r.Location
            TagMancanti   = $missing -join ', '
        }
    }
}
$report | Sort-Object ResourceGroup, Name | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} risorse con tag mancanti → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Yellow
