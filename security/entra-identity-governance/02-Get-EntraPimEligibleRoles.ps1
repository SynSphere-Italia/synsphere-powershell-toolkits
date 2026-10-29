#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Assegnazioni di ruolo ELEGGIBILI in PIM (Privileged Identity Management).
.DESCRIPTION
    Elenca le assegnazioni di ruolo idonee (eligible) di Microsoft Entra PIM: chi PUÒ
    attivare un ruolo privilegiato senza averlo permanentemente. Completa lo script 01
    (assegnazioni attive) per il quadro completo degli accessi privilegiati. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-PimEligibleRoles-<data>.csv
.EXAMPLE
    .\02-Get-EntraPimEligibleRoles.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: RoleEligibilitySchedule.Read.Directory
    Richiede Microsoft Entra ID P2 (PIM). Senza P2/PIM la lista è vuota o non accessibile.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Entra-PimEligibleRoles-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'RoleEligibilitySchedule.Read.Directory' -NoWelcome

try {
    $items = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All -ExpandProperty Principal, RoleDefinition
}
catch {
    Write-Host ("Impossibile leggere le assegnazioni PIM eleggibili — verifica la licenza Microsoft Entra ID P2 e i permessi. Dettaglio: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    return
}

$report = foreach ($i in $items) {
    [pscustomobject]@{
        Ruolo      = $i.RoleDefinition.DisplayName
        Principal  = $i.Principal.AdditionalProperties['displayName']
        UPN        = $i.Principal.AdditionalProperties['userPrincipalName']
        Stato      = $i.Status
        MemberType = $i.MemberType
        Inizio     = $i.ScheduleInfo.StartDateTime
        Fine       = $i.ScheduleInfo.Expiration.EndDateTime   # null = permanente
    }
}

$report | Sort-Object Ruolo, Principal | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} assegnazioni eleggibili PIM -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
