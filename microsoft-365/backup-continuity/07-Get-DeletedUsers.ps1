#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Utenti eliminati recuperabili (cestino directory, finestra 30 giorni).
.DESCRIPTION
    Elenca gli utenti eliminati ancora recuperabili dal cestino della directory di Entra ID,
    con la data di eliminazione e i giorni residui stimati prima della cancellazione
    definitiva (30 giorni). Utile per accorgersi in tempo di eliminazioni errate. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-DeletedUsers-<data>.csv
.EXAMPLE
    .\07-Get-DeletedUsers.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-DeletedUsers-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'User.Read.All' -NoWelcome

$report = foreach ($u in Get-MgDirectoryDeletedItemAsUser -All -Property 'id', 'displayName', 'userPrincipalName', 'deletedDateTime') {
    $giorni = if ($u.DeletedDateTime) { [int](30 - ((Get-Date).ToUniversalTime() - $u.DeletedDateTime).TotalDays) } else { $null }
    [pscustomobject]@{
        Utente        = $u.DisplayName
        UPN           = $u.UserPrincipalName
        Eliminato     = $u.DeletedDateTime
        GiorniResidui = $giorni
    }
}

$report | Sort-Object Eliminato | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovati {0} utenti eliminati recuperabili -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
