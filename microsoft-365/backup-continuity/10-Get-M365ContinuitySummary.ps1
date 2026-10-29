#Requires -Modules ExchangeOnlineManagement, Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Cruscotto sintetico della continuità e recuperabilità di Microsoft 365.
.DESCRIPTION
    Riunisce in un'unica vista gli indicatori chiave di recuperabilità nativa: cassette con
    hold, cassette a rischio (nessun hold + SIR off), cassette soft-deleted, cassette inactive,
    retention policy di Purview e utenti eliminati recuperabili. Interroga tre fonti (Exchange
    Online, Security & Compliance, Microsoft Graph) in modo indipendente: se una non è
    disponibile, la sua metrica risulta "n/d" e le altre proseguono. Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-ContinuitySummary-<data>.csv
.EXAMPLE
    .\10-Get-M365ContinuitySummary.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Fonti: Connect-ExchangeOnline + Connect-IPPSSession + Connect-MgGraph (User.Read.All).
    NOTA: Microsoft 365 NON include un backup nativo. Questo cruscotto misura la
    RECUPERABILITÀ nativa (retention/hold/cestini), non un backup. Per un vero backup serve
    l'add-on Microsoft 365 Backup (a pagamento) o una soluzione di backup di terze parti.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-ContinuitySummary-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

$mbxHold = $mbxRisk = $softDel = $inactive = $retention = $delUsers = 'n/d'

# --- Exchange Online ---
try {
    if (-not (Get-ConnectionInformation | Where-Object { $_.ConnectionUri -like '*outlook.office365.com*' })) {
        Connect-ExchangeOnline -ShowBanner:$false
    }
    $mbx = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox -PropertySets Hold -Properties SingleItemRecoveryEnabled
    $mbxHold = @($mbx | Where-Object { $_.LitigationHoldEnabled -or (@($_.InPlaceHolds).Count -gt 0) }).Count
    $mbxRisk = @($mbx | Where-Object { -not $_.LitigationHoldEnabled -and (@($_.InPlaceHolds).Count -eq 0) -and -not $_.SingleItemRecoveryEnabled }).Count
    $softDel = @(Get-EXOMailbox -SoftDeletedMailbox -ResultSize Unlimited).Count
    $inactive = @(Get-EXOMailbox -InactiveMailboxOnly -ResultSize Unlimited).Count
}
catch {
    Write-Host ("Exchange Online non disponibile: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
}

# --- Security & Compliance (retention) ---
try {
    if (-not (Get-ConnectionInformation | Where-Object { $_.ConnectionUri -like '*compliance.protection.outlook.com*' })) {
        Connect-IPPSSession
    }
    $retention = @(Get-RetentionCompliancePolicy).Count
}
catch {
    Write-Host ("Security & Compliance (retention) non disponibile: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
}

# --- Microsoft Graph (utenti eliminati) ---
try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All' -NoWelcome }
    $delUsers = @(Get-MgDirectoryDeletedItemAsUser -All -Property 'id').Count
}
catch {
    Write-Host ("Microsoft Graph (utenti eliminati) non disponibile: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
}

Write-Host ''
Write-Host '=== Continuità Microsoft 365 — sintesi (recuperabilità nativa) ===' -ForegroundColor Cyan
Write-Host ("Cassette con hold attivo          : {0}" -f $mbxHold)
Write-Host ("Cassette a rischio (no hold + SIR off): {0}" -f $mbxRisk)
Write-Host ("Cassette soft-deleted recuperabili: {0}" -f $softDel)
Write-Host ("Cassette inactive (conservate)    : {0}" -f $inactive)
Write-Host ("Retention policy Purview          : {0}" -f $retention)
Write-Host ("Utenti eliminati recuperabili     : {0}" -f $delUsers)
Write-Host ''
Write-Host 'Nota: Microsoft 365 non include un backup nativo — questi sono meccanismi di conservazione/recupero.' -ForegroundColor DarkGray

$row = [pscustomobject]@{
    Data                = (Get-Date -Format 'yyyy-MM-dd')
    CassetteConHold     = $mbxHold
    CassetteARischio    = $mbxRisk
    CassetteSoftDeleted = $softDel
    CassetteInactive    = $inactive
    RetentionPolicy     = $retention
    UtentiEliminati     = $delUsers
}
$row | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Sintesi esportata in {0}" -f $OutputCsv) -ForegroundColor Green
