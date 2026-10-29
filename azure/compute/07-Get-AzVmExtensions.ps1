#Requires -Modules Az.Accounts, Az.Compute
<#
.SYNOPSIS
    Estensioni installate su ogni VM (antimalware, monitoring agent, custom script…).
.DESCRIPTION
    Le estensioni VM sono spesso invisibili ma importanti per sicurezza e gestione. Lo
    script elenca tutte le estensioni per VM con publisher, tipo, versione e stato. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-VmExtensions-<data>.csv
.EXAMPLE
    .\07-Get-AzVmExtensions.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-VmExtensions-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = [System.Collections.Generic.List[object]]::new()
foreach ($vm in Get-AzVM) {
    $ext = Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name -ErrorAction SilentlyContinue
    if (-not $ext) {
        $report.Add([pscustomobject]@{ VM = $vm.Name; ResourceGroup = $vm.ResourceGroupName; Estensione = '(nessuna)'; Publisher = ''; Tipo = ''; Versione = '' })
        continue
    }
    foreach ($e in $ext) {
        $report.Add([pscustomobject]@{
            VM = $vm.Name; ResourceGroup = $vm.ResourceGroupName
            Estensione = $e.Name; Publisher = $e.Publisher; Tipo = $e.ExtensionType; Versione = $e.TypeHandlerVersion
        })
    }
}
$report | Sort-Object VM, Estensione | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Estensioni VM esportate → {0}" -f $OutputCsv) -ForegroundColor Green
