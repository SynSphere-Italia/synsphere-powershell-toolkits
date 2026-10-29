#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Gruppi eliminati recuperabili (cestino directory, finestra 30 giorni).
.DESCRIPTION
    Elenca i gruppi Microsoft 365 eliminati ancora recuperabili dal cestino della directory,
    con la data di eliminazione e i giorni residui stimati (30 giorni). Un gruppo M365
    eliminato porta con sé mailbox, sito e file: recuperarlo in tempo evita perdite. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-DeletedGroups-<data>.csv
.EXAMPLE
    .\08-Get-DeletedGroups.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All
    NOTA: solo i gruppi Microsoft 365 sono recuperabili; i gruppi di sicurezza no.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-DeletedGroups-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Group.Read.All' -NoWelcome

$report = foreach ($g in Get-MgDirectoryDeletedItemAsGroup -All -Property 'id', 'displayName', 'deletedDateTime', 'groupTypes') {
    $giorni = if ($g.DeletedDateTime) { [int](30 - ((Get-Date).ToUniversalTime() - $g.DeletedDateTime).TotalDays) } else { $null }
    [pscustomobject]@{
        Gruppo        = $g.DisplayName
        Tipo          = if ($g.GroupTypes -contains 'Unified') { 'Microsoft 365' } else { 'Sicurezza/Altro' }
        Eliminato     = $g.DeletedDateTime
        GiorniResidui = $giorni
    }
}

$report | Sort-Object Eliminato | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovati {0} gruppi eliminati recuperabili -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
