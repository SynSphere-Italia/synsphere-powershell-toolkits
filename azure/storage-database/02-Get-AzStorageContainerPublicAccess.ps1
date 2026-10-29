#Requires -Modules Az.Accounts, Az.Storage
<#
.SYNOPSIS
    Container blob con accesso pubblico (Blob/Container): rischio di data leak.
.DESCRIPTION
    Verifica a livello di singolo container quali consentono accesso anonimo (PublicAccess
    Blob o Container). È una delle cause più comuni di esposizione dati su Azure. Sola lettura.
    NB: richiede accesso DATA-PLANE (chiave dell'account o ruolo Storage Blob Data Reader).
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-ContainerPublicAccess-<data>.csv
.EXAMPLE
    .\02-Get-AzStorageContainerPublicAccess.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Reader + accesso data-plane. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-ContainerPublicAccess-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = [System.Collections.Generic.List[object]]::new()
foreach ($sa in Get-AzStorageAccount) {
    try {
        $ctx = $sa.Context
        foreach ($c in Get-AzStorageContainer -Context $ctx -ErrorAction Stop) {
            if ($c.PublicAccess -and $c.PublicAccess -ne 'Off') {
                $report.Add([pscustomobject]@{
                    StorageAccount = $sa.StorageAccountName; ResourceGroup = $sa.ResourceGroupName
                    Container = $c.Name; AccessoPubblico = $c.PublicAccess
                })
            }
        }
    } catch { Write-Warning "Accesso negato su $($sa.StorageAccountName): serve la chiave o un ruolo data-plane." }
}
$report | Sort-Object StorageAccount, Container | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} container con accesso pubblico → {1}. Valuta di chiuderli." -f $report.Count, $OutputCsv) -ForegroundColor Yellow
