#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Report manager: per ogni utente il responsabile diretto.
.DESCRIPTION
    Esporta l'attributo manager di ciascun utente. Evidenzia gli utenti SENZA manager
    (spesso un gap nei processi HR/onboarding e nelle approvazioni). Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-ManagerReport-<data>.csv
.EXAMPLE
    .\06-Get-M365ManagerReport.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, Directory.Read.All
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-ManagerReport-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.Read.All', 'Directory.Read.All' -NoWelcome

$report = foreach ($u in Get-MgUser -All -Property DisplayName, UserPrincipalName, Department, JobTitle, Id) {
    $mgr = $null
    try { $mgr = Get-MgUserManager -UserId $u.Id -ErrorAction Stop } catch { $mgr = $null }
    [pscustomobject]@{
        DisplayName       = $u.DisplayName
        UserPrincipalName = $u.UserPrincipalName
        Department        = $u.Department
        JobTitle          = $u.JobTitle
        Manager           = if ($mgr) { $mgr.AdditionalProperties.displayName } else { 'NESSUN MANAGER' }
        ManagerUPN        = if ($mgr) { $mgr.AdditionalProperties.userPrincipalName } else { '' }
    }
}
$report | Sort-Object Department, DisplayName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$senza = ($report | Where-Object { $_.Manager -eq 'NESSUN MANAGER' }).Count
Write-Host ("Esportati {0} utenti. Senza manager: {1} → {2}" -f $report.Count, $senza, $OutputCsv) -ForegroundColor Green
