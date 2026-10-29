#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report amministratori Microsoft 365 e ruoli assegnati.
.DESCRIPTION
    Elenca tutti gli account con ruoli amministrativi (directory roles) e il ruolo
    di ciascuno. Fondamentale per audit di sicurezza (principio del privilegio minimo):
    troppi Global Administrator sono un rischio. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-AdminReport-<data>.csv
.EXAMPLE
    .\05-Get-M365AdminReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: RoleManagement.Read.Directory, Directory.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-AdminReport-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'RoleManagement.Read.Directory', 'Directory.Read.All' -NoWelcome

$report = foreach ($role in Get-MgDirectoryRole -All) {
    foreach ($m in Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All) {
        # Il membro può essere utente, gruppo o service principal: leggiamo le proprietà comuni
        $p = $m.AdditionalProperties
        [pscustomobject]@{
            Role              = $role.DisplayName
            MemberType        = ($p.'@odata.type' -replace '#microsoft.graph.', '')
            DisplayName       = $p.displayName
            UserPrincipalName = $p.userPrincipalName
        }
    }
}
$report | Sort-Object Role, DisplayName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$ga = ($report | Where-Object { $_.Role -eq 'Global Administrator' -or $_.Role -eq 'Amministratore globale' }).Count
Write-Host ("Esportate {0} assegnazioni di ruolo. Global Administrator: {1} (tienili al minimo) → {2}" -f $report.Count, $ga, $OutputCsv) -ForegroundColor Yellow
