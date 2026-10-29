#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Assegnazioni di ruolo ORFANE: assegnate a identità ormai eliminate.
.DESCRIPTION
    Quando un utente/SP/gruppo viene cancellato, le sue assegnazioni di ruolo restano
    (mostrate come "Identity not found", senza DisplayName). Sono rumore e vanno rimosse.
    Lo script le elenca. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-OrphanedRoleAssignments-<data>.csv
.EXAMPLE
    .\04-Get-AzOrphanedRoleAssignments.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Reader + lettura roleAssignments. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-OrphanedRoleAssignments-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = Get-AzRoleAssignment | Where-Object {
    [string]::IsNullOrEmpty($_.DisplayName) -and [string]::IsNullOrEmpty($_.ObjectType)
} | ForEach-Object {
    [pscustomobject]@{
        ObjectId     = $_.ObjectId
        Ruolo        = $_.RoleDefinitionName
        Scope        = $_.Scope
        AssignmentId = $_.RoleAssignmentId
    }
}
if ($report) {
    $report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host ("{0} assegnazioni ORFANE → {1}. Rimuovile con Remove-AzRoleAssignment." -f $report.Count, $OutputCsv) -ForegroundColor Yellow
} else {
    Write-Host "Nessuna assegnazione orfana." -ForegroundColor Green
}
