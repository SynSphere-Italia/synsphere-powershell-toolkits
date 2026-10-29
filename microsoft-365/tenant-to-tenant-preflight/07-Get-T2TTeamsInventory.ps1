#Requires -Modules Microsoft.Graph.Groups, Microsoft.Graph.Teams
<#
.SYNOPSIS
    Inventario dei team con canali standard, privati e condivisi, e relativi owner.
.DESCRIPTION
    Perche' Microsoft Graph e non il modulo MicrosoftTeams: il parametro -MembershipType di
    Get-TeamChannel documenta i soli valori Standard e Private. SHARED non e' un valore
    documentato, quindi con quel modulo i canali condivisi non si leggono. Get-MgTeamChannel
    restituisce membershipType con tutti e tre i valori.

    I canali condivisi contano piu' degli altri in una migrazione tenant-to-tenant: sono quelli
    che possono ospitare membri di un'altra organizzazione, e vanno ricensiti uno per uno.

    Prerequisito da non sottovalutare: senza il ruolo Teams Administrator i canali privati e
    condivisi vengono restituiti in modo incompleto, e il conteggio esce piu' basso del vero
    senza alcun errore.

    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV dei canali. Default: .\T2T-TeamsChannels-<data>.csv
.PARAMETER TeamsCsv
    Percorso del CSV dei team. Default: .\T2T-Teams-<data>.csv
.EXAMPLE
    .\07-Get-T2TTeamsInventory.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Group.Read.All, Channel.ReadBasic.All, ChannelMember.Read.All
    Ruolo consigliato: Teams Administrator
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\T2T-TeamsChannels-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')),
    [string]$TeamsCsv  = (".\T2T-Teams-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Group.Read.All', 'Channel.ReadBasic.All', 'ChannelMember.Read.All' -NoWelcome

# Un team e' un gruppo Microsoft 365 con l'opzione di provisioning "Team": e' la via
# documentata per enumerarli tutti senza conoscere un solo ID in anticipo.
Write-Host "Ricerca dei team..." -ForegroundColor Cyan
$team = Get-MgGroup -All -ConsistencyLevel eventual -CountVariable conteggio `
    -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" `
    -Property Id, DisplayName, Mail, Visibility, CreatedDateTime, Description

$totale = @($team).Count
Write-Host ("Team trovati: {0}" -f $totale)

$righeTeam   = New-Object System.Collections.Generic.List[object]
$righeCanali = New-Object System.Collections.Generic.List[object]
$i = 0

foreach ($t in $team) {
    $i++
    if ($totale -gt 20 -and ($i % 10) -eq 0) {
        Write-Progress -Activity "Canali" -Status ("{0} di {1}" -f $i, $totale) -PercentComplete (100 * $i / $totale)
    }

    $owner = @()
    try { $owner = Get-MgGroupOwner -GroupId $t.Id -All } catch { }

    $canali = @()
    try { $canali = Get-MgTeamChannel -TeamId $t.Id -All } catch {
        Write-Warning ("Canali non leggibili per '{0}': {1}" -f $t.DisplayName, $_.Exception.Message)
    }

    $perTipo = $canali | Group-Object membershipType -AsHashTable -AsString

    $righeTeam.Add([pscustomobject]@{
        Team              = $t.DisplayName
        Mail              = $t.Mail
        Visibilita        = $t.Visibility
        TeamId            = $t.Id
        NumeroOwner       = @($owner).Count
        Owner             = (($owner | ForEach-Object { $_.AdditionalProperties['userPrincipalName'] }) -join ';')
        SenzaOwner        = (@($owner).Count -eq 0)
        CanaliTotali      = @($canali).Count
        CanaliStandard    = @($perTipo['standard']).Count
        CanaliPrivati     = @($perTipo['private']).Count
        CanaliCondivisi   = @($perTipo['shared']).Count
        CreatoIl          = $t.CreatedDateTime
    })

    foreach ($c in $canali) {
        $righeCanali.Add([pscustomobject]@{
            Team           = $t.DisplayName
            Canale         = $c.DisplayName
            TipoAppartenenza = $c.MembershipType
            CanaleId       = $c.Id
            Email          = $c.Email
            CreatoIl       = $c.CreatedDateTime
        })
    }
}

Write-Progress -Activity "Canali" -Completed

$righeTeam   | Sort-Object Team | Export-Csv -Path $TeamsCsv  -NoTypeInformation -Encoding UTF8
$righeCanali | Sort-Object Team, Canale | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$senzaOwner = @($righeTeam | Where-Object SenzaOwner).Count
$condivisi  = ($righeTeam.CanaliCondivisi | Measure-Object -Sum).Sum
Write-Host ""
Write-Host ("Team: {0} | canali: {1}" -f $totale, $righeCanali.Count)
Write-Host ("  standard  {0}" -f ($righeTeam.CanaliStandard  | Measure-Object -Sum).Sum)
Write-Host ("  privati   {0}" -f ($righeTeam.CanaliPrivati   | Measure-Object -Sum).Sum)
Write-Host ("  condivisi {0}" -f $condivisi) -ForegroundColor $(if ($condivisi) { 'Yellow' } else { 'Gray' })
if ($senzaOwner) { Write-Host ("Team senza owner: {0}" -f $senzaOwner) -ForegroundColor Yellow }
Write-Host ("Esportati: {0} e {1}" -f $TeamsCsv, $OutputCsv)
