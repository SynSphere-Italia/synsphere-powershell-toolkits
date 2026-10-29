#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Gruppi senza owner (gap di governance).
.DESCRIPTION
    Elenca i gruppi (Microsoft 365 e di sicurezza) che non hanno alcun owner assegnato: un
    gruppo senza proprietario rischia di restare senza manutenzione e senza responsabile.
    Esclude i gruppi sincronizzati da on-premises (i cui owner non sono gestiti in Entra).
    Sola lettura.
    NOTA: le liste di distribuzione create in Exchange possono risultare "senza owner" qui
    perché l'owner è gestito in Exchange, non in Entra — vanno verificate lato Exchange.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\Entra-GroupsWithoutOwners-<data>.csv
.EXAMPLE
    .\07-Get-EntraGroupsWithoutOwners.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\Entra-GroupsWithoutOwners-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Group.Read.All' -NoWelcome

$report = foreach ($g in Get-MgGroup -All -Property Id, DisplayName, GroupTypes, MailEnabled, SecurityEnabled, OnPremisesSyncEnabled) {
    if ($g.OnPremisesSyncEnabled) { continue }   # owner non gestito in Entra
    $ownerCount = @(Get-MgGroupOwner -GroupId $g.Id -All).Count
    if ($ownerCount -eq 0) {
        $tipo = if ($g.GroupTypes -contains 'Unified') { 'Microsoft 365' }
        elseif ($g.SecurityEnabled -and -not $g.MailEnabled) { 'Sicurezza' }
        elseif ($g.SecurityEnabled -and $g.MailEnabled) { 'Sicurezza mail-enabled' }
        else { 'Distribuzione' }
        [pscustomobject]@{
            Gruppo = $g.DisplayName
            Tipo   = $tipo
            Id     = $g.Id
        }
    }
}

$report | Sort-Object Tipo, Gruppo | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovati {0} gruppi senza owner -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
