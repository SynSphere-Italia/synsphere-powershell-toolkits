#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Ruoli directory attivati e relativi membri (accessi privilegiati).
.DESCRIPTION
    Elenca ogni ruolo directory attivato nel tenant (Global Administrator, ecc.) con i suoi
    membri (utenti, gruppi o service principal). È la base per l'audit degli accessi
    privilegiati: sapere chi ha i poteri di amministrazione. Sola lettura.
    NOTA: mostra le assegnazioni ATTIVE/permanenti, non i ruoli idonei PIM (vedi script 02).
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-PrivilegedRoleMembers-<data>.csv
.EXAMPLE
    .\01-Get-EntraPrivilegedRoleMembers.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: RoleManagement.Read.Directory
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Entra-PrivilegedRoleMembers-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'RoleManagement.Read.Directory' -NoWelcome

$report = foreach ($role in Get-MgDirectoryRole -All) {
    foreach ($m in Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All) {
        $ap = $m.AdditionalProperties
        [pscustomobject]@{
            Ruolo = $role.DisplayName
            Tipo  = (($ap['@odata.type']) -replace '#microsoft.graph.', '')
            Nome  = $ap['displayName']
            UPN   = $ap['userPrincipalName']   # valorizzato solo per gli utenti
            Id    = $m.Id
        }
    }
}

$report | Sort-Object Ruolo, Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} assegnazioni di ruolo privilegiato -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
