#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Assegnazioni di ruolo a livello di MANAGEMENT GROUP (ereditate da tutte le subscription).
.DESCRIPTION
    I ruoli assegnati su un management group si ereditano su TUTTE le subscription sotto di
    esso: sono i più impattanti e i più trascurati. Lo script li elenca per ogni MG. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-MgRoleAssignments-<data>.csv
.EXAMPLE
    .\08-Get-AzManagementGroupRoleAssignments.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Reader sui management group. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-MgRoleAssignments-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

try { $mgs = Get-AzManagementGroup -ErrorAction Stop } catch { Write-Host "Management group non accessibili o non configurati." -ForegroundColor Yellow; return }
$report = foreach ($mg in $mgs) {
    $scope = "/providers/Microsoft.Management/managementGroups/$($mg.Name)"
    Get-AzRoleAssignment -Scope $scope -ErrorAction SilentlyContinue |
        Where-Object { $_.Scope -eq $scope } |
        ForEach-Object {
            [pscustomobject]@{ ManagementGroup = $mg.DisplayName; Principal = $_.DisplayName; Tipo = $_.ObjectType; Ruolo = $_.RoleDefinitionName }
        }
}
$report | Sort-Object ManagementGroup, Ruolo | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} assegnazioni a livello management group → {1}" -f @($report).Count, $OutputCsv) -ForegroundColor Green
