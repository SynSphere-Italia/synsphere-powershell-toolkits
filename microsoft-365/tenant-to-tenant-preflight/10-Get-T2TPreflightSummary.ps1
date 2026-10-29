#Requires -Modules ExchangeOnlineManagement, Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement
<#
.SYNOPSIS
    Cruscotto di sintesi del pre-flight: i numeri che servono a dimensionare la migrazione.
.DESCRIPTION
    Raccoglie in una sola pagina i conteggi principali del tenant. Tutte le grandezze di volume
    sono normalizzate in BYTE alla raccolta: Exchange risponde con stringhe formattate,
    SharePoint in megabyte e i report di Graph in byte, e sommarle cosi' come arrivano sbaglia
    di un fattore un milione.

    Cosa questo cruscotto NON fa, deliberatamente: nessun semaforo su Organization Relationship,
    MailboxMoveCapability o Test-MigrationServerAvailability. In un pre-flight quegli oggetti
    non esistono ancora, quindi un semaforo rosso non significherebbe nulla. Si verificano dopo
    aver stabilito la relazione fra i due tenant, non prima.

    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\T2T-Summary-<data>.csv
.PARAMETER SharePointCsv
    CSV prodotto dallo script 06. Se indicato, il volume SharePoint/OneDrive entra nel totale.
.EXAMPLE
    .\10-Get-T2TPreflightSummary.ps1
.EXAMPLE
    .\10-Get-T2TPreflightSummary.ps1 -SharePointCsv .\T2T-SharePoint-20260824.csv
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: View-Only Organization Management (EXO) + Directory.Read.All, Organization.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\T2T-Summary-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')),
    [string]$SharePointCsv
)
$ErrorActionPreference = 'Stop'

function ConvertTo-Bytes {
    param($Size)
    if ($null -eq $Size) { return 0 }
    if ($Size.PSObject.Methods.Name -contains 'ToBytes') { return [int64]$Size.ToBytes() }
    if ($Size.Value -and $Size.Value.PSObject.Methods.Name -contains 'ToBytes') { return [int64]$Size.Value.ToBytes() }
    $m = [regex]::Match([string]$Size, '\(([\d\.,\s]+)\s*bytes\)')
    if ($m.Success) { return [int64](($m.Groups[1].Value -replace '[^\d]', '')) }
    return 0
}

if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
    Connect-ExchangeOnline -ShowBanner:$false
}
Connect-MgGraph -Scopes 'User.Read.All', 'Directory.Read.All', 'Organization.Read.All' -NoWelcome

$voci = New-Object System.Collections.Generic.List[object]
function Aggiungi([string]$Area, [string]$Voce, $Valore, [string]$Nota = '') {
    $voci.Add([pscustomobject]@{ Area = $Area; Voce = $Voce; Valore = $Valore; Nota = $Nota })
}

# --- Identita' ------------------------------------------------------------------------
Write-Host "Identita'..." -ForegroundColor Cyan
$org = Get-MgOrganization
$utenti = Get-MgUser -All -Property Id, UserType, AccountEnabled, OnPremisesSyncEnabled, UsageLocation, AssignedLicenses
$sync = @($utenti | Where-Object { $_.OnPremisesSyncEnabled -eq $true }).Count

Aggiungi 'Tenant'   'Nome organizzazione'      $org.DisplayName
Aggiungi 'Tenant'   'Tenant ID'                $org.Id
Aggiungi 'Identita' 'Utenti totali'            @($utenti).Count
Aggiungi 'Identita' 'Guest'                    @($utenti | Where-Object UserType -eq 'Guest').Count
Aggiungi 'Identita' 'Sincronizzati da on-prem' $sync ($(if ($sync) { 'Tenant ibrido: serve una decisione sulla sincronizzazione' } else { 'Tenant interamente cloud' }))
Aggiungi 'Identita' 'Senza usageLocation'      @($utenti | Where-Object { $_.AssignedLicenses.Count -gt 0 -and -not $_.UsageLocation }).Count 'Bloccano l assegnazione licenza sul target'

# --- Licenze --------------------------------------------------------------------------
$sku = Get-MgSubscribedSku -All
foreach ($s in $sku | Sort-Object -Property @{ Expression = { $_.ConsumedUnits } } -Descending | Select-Object -First 8) {
    Aggiungi 'Licenze' $s.SkuPartNumber ("{0} di {1}" -f $s.ConsumedUnits, $s.PrepaidUnits.Enabled) 'assegnate di acquistate'
}
$ctudm = @($sku | Where-Object { $_.SkuPartNumber -like '*CROSS*TENANT*' -or $_.SkuPartNumber -like '*USER_DATA_MIGRATION*' })
Aggiungi 'Licenze' 'Cross-tenant User Data Migration' $(if ($ctudm) { 'presente' } else { 'non presente' }) 'Serve alla migrazione vera, non a questo pre-flight'

# --- Exchange -------------------------------------------------------------------------
Write-Host "Exchange..." -ForegroundColor Cyan
$mbx = Get-EXOMailbox -ResultSize Unlimited -PropertySets Minimum -Properties RecipientTypeDetails, ExchangeGuid
$volume = 0
foreach ($m in $mbx) {
    try { $volume += ConvertTo-Bytes (Get-MailboxStatistics -Identity $m.ExchangeGuid.ToString()).TotalItemSize } catch { }
}
foreach ($g in ($mbx | Group-Object RecipientTypeDetails | Sort-Object Name)) {
    Aggiungi 'Exchange' ("Cassette: {0}" -f $g.Name) $g.Count
}
Aggiungi 'Exchange' 'Volume cassette (GB)' ([math]::Round($volume / 1GB, 2)) 'Normalizzato in byte alla raccolta'
Aggiungi 'Exchange' 'Domini accettati'     @(Get-AcceptedDomain -ResultSize Unlimited).Count
Aggiungi 'Exchange' 'Regole di trasporto'  @(Get-TransportRule -ResultSize Unlimited).Count
Aggiungi 'Exchange' 'Gruppi mail-enabled'  (@(Get-DistributionGroup -ResultSize Unlimited).Count + @(Get-UnifiedGroup -ResultSize Unlimited).Count)

# --- SharePoint: solo se fornito il CSV dello script 06 --------------------------------
$volSpo = 0
if ($SharePointCsv -and (Test-Path $SharePointCsv)) {
    $righe = Import-Csv $SharePointCsv
    $volSpo = ($righe.UsatoByte | Measure-Object -Sum).Sum
    Aggiungi 'SharePoint' 'Siti e OneDrive'        @($righe).Count
    Aggiungi 'SharePoint' 'Volume (GB)'            ([math]::Round($volSpo / 1GB, 2)) 'Convertito da megabyte alla raccolta'
} else {
    Aggiungi 'SharePoint' 'Volume (GB)' 'n/d' 'Esegui lo script 06 e ripassa il CSV con -SharePointCsv'
}

Aggiungi 'TOTALE' 'Volume complessivo (GB)' ([math]::Round(($volume + $volSpo) / 1GB, 2)) 'Exchange + SharePoint/OneDrive, in byte'

$voci | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "════════ PRE-FLIGHT TENANT-TO-TENANT ════════" -ForegroundColor Cyan
$voci | Group-Object Area | ForEach-Object {
    Write-Host ("`n[{0}]" -f $_.Name) -ForegroundColor White
    $_.Group | ForEach-Object { Write-Host ("  {0,-34} {1}" -f $_.Voce, $_.Valore) }
}
Write-Host ""
Write-Host ("Esportato in {0}" -f $OutputCsv)
Write-Host "Per il confronto sorgente/destinazione: eseguire il toolkit su ciascun tenant in un" -ForegroundColor Yellow
Write-Host "processo PowerShell SEPARATO e confrontare i CSV offline. Connect-MgGraph sostituisce" -ForegroundColor Yellow
Write-Host "la sessione del processo: due tenant nello stesso processo producono due volte lo" -ForegroundColor Yellow
Write-Host "stesso tenant, senza dare errore." -ForegroundColor Yellow
