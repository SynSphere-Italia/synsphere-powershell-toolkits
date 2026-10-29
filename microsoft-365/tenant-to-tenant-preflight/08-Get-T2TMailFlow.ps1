#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Mail flow: connettori, domini accettati, domini remoti e regole di trasporto.
.DESCRIPTION
    E' la configurazione che va ricostruita sul tenant di destinazione e che, se dimenticata,
    si manifesta come posta che smette di arrivare il giorno del cutover.

    Due default da conoscere:
      - Get-TransportRule senza -State restituisce insieme le regole ABILITATE e quelle
        DISABILITATE. Un report che non riporta lo stato fa ricostruire sul target regole che
        sul sorgente erano spente, e nasconde che una regola creduta attiva non lo era.
      - ResultSize vale 1000 su tutti i Get-* di Exchange Online: sui tenant grandi o in CSP
        anche l'elenco dei domini accettati puo' troncare senza avvisare.

    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\T2T-MailFlow-<data>.csv
.EXAMPLE
    .\08-Get-T2TMailFlow.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Ruolo minimo: View-Only Organization Management
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\T2T-MailFlow-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
    Connect-ExchangeOnline -ShowBanner:$false
}

$report = New-Object System.Collections.Generic.List[object]

Write-Host "Domini accettati..." -ForegroundColor Cyan
foreach ($d in Get-AcceptedDomain -ResultSize Unlimited) {
    $report.Add([pscustomobject]@{
        Categoria = 'DominioAccettato'
        Nome      = $d.DomainName
        Stato     = if ($d.Default) { 'Predefinito' } else { '' }
        Dettaglio = $d.DomainType          # Authoritative / InternalRelay / ExternalRelay
        Note      = ("MatchSubDomains={0}" -f $d.MatchSubDomains)
    })
}

Write-Host "Connettori in ingresso..." -ForegroundColor Cyan
foreach ($c in Get-InboundConnector -ResultSize Unlimited) {
    $report.Add([pscustomobject]@{
        Categoria = 'ConnettoreIngresso'
        Nome      = $c.Name
        Stato     = if ($c.Enabled) { 'Abilitato' } else { 'DISABILITATO' }
        Dettaglio = $c.ConnectorType
        Note      = ("SenderDomains={0} | SenderIPAddresses={1} | RequireTls={2}" -f `
                     ($c.SenderDomains -join ','), ($c.SenderIPAddresses -join ','), $c.RequireTls)
    })
}

Write-Host "Connettori in uscita..." -ForegroundColor Cyan
foreach ($c in Get-OutboundConnector -ResultSize Unlimited) {
    $report.Add([pscustomobject]@{
        Categoria = 'ConnettoreUscita'
        Nome      = $c.Name
        Stato     = if ($c.Enabled) { 'Abilitato' } else { 'DISABILITATO' }
        Dettaglio = $c.ConnectorType
        Note      = ("RecipientDomains={0} | SmartHosts={1} | TlsSettings={2}" -f `
                     ($c.RecipientDomains -join ','), ($c.SmartHosts -join ','), $c.TlsSettings)
    })
}

Write-Host "Domini remoti..." -ForegroundColor Cyan
foreach ($d in Get-RemoteDomain -ResultSize Unlimited) {
    $report.Add([pscustomobject]@{
        Categoria = 'DominioRemoto'
        Nome      = $d.DomainName
        Stato     = ''
        Dettaglio = $d.Identity
        Note      = ("AutoReplyEnabled={0} | AutoForwardEnabled={1}" -f $d.AutoReplyEnabled, $d.AutoForwardEnabled)
    })
}

Write-Host "Regole di trasporto..." -ForegroundColor Cyan
foreach ($r in Get-TransportRule -ResultSize Unlimited) {
    $report.Add([pscustomobject]@{
        Categoria = 'RegolaTrasporto'
        Nome      = $r.Name
        # Senza questo campo il report e' fuorviante: le regole spente sembrerebbero attive.
        Stato     = $r.State
        Dettaglio = ("Priorita={0} | Mode={1}" -f $r.Priority, $r.Mode)
        # Le parentesi non sono estetiche: dentro una hashtable la virgola di -replace
        # verrebbe letta come separatore fra due voci e il file non compila.
        Note      = ($r.Description -replace '\s+', ' ')
    })
}

$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ""
$report | Group-Object Categoria | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0,-20} {1}" -f $_.Name, $_.Count)
}
$spente = @($report | Where-Object { $_.Categoria -eq 'RegolaTrasporto' -and $_.Stato -ne 'Enabled' }).Count
if ($spente) { Write-Host ("Regole di trasporto NON abilitate: {0} (non ricrearle sul target)" -f $spente) -ForegroundColor Yellow }
$disab = @($report | Where-Object { $_.Stato -eq 'DISABILITATO' }).Count
if ($disab) { Write-Host ("Connettori disabilitati: {0}" -f $disab) -ForegroundColor Yellow }
Write-Host ("Esportato in {0}" -f $OutputCsv)
