#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Gruppi: distribution list, gruppi di sicurezza mail-enabled, gruppi Microsoft 365 e dinamici.
.DESCRIPTION
    Esporta i gruppi con membri e owner, cioe' quello che va ricostruito sul tenant di
    destinazione. Tre avvertenze, tutte verificate:

      - Get-UnifiedGroupLinks vuole -Identity E -LinkType, e -LinkType accetta un valore alla
        volta: per ogni gruppo Microsoft 365 servono DUE chiamate, una per i membri e una per
        gli owner.
      - ResultSize vale 1000 su Get-DistributionGroup, Get-DistributionGroupMember e
        Get-UnifiedGroupLinks: un gruppo con piu' di mille membri viene esportato monco senza
        alcun errore, e la migrazione partirebbe con un gruppo incompleto.
      - Copertura: qui ci sono solo i gruppi MAIL-ENABLED. I gruppi di sicurezza non abilitati
        alla posta non li vede Exchange: stanno in Entra ID e li elenca lo script 09.

    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\T2T-Groups-<data>.csv
.PARAMETER SkipMembers
    Esporta solo l'anagrafica dei gruppi, senza espandere membri e owner.
.EXAMPLE
    .\04-Get-T2TGroups.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Ruolo minimo: View-Only Organization Management
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\T2T-Groups-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')),
    [switch]$SkipMembers
)
$ErrorActionPreference = 'Stop'

if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
    Connect-ExchangeOnline -ShowBanner:$false
}

$report = New-Object System.Collections.Generic.List[object]

# --- Distribution list e gruppi di sicurezza mail-enabled -----------------------------
Write-Host "Distribution list e security mail-enabled..." -ForegroundColor Cyan
foreach ($g in Get-DistributionGroup -ResultSize Unlimited) {
    $membri = @()
    if (-not $SkipMembers) {
        try { $membri = Get-DistributionGroupMember -Identity $g.Identity -ResultSize Unlimited } catch { }
    }
    $report.Add([pscustomobject]@{
        Nome            = $g.DisplayName
        SmtpPrimario    = $g.PrimarySmtpAddress
        Tipo            = $g.RecipientTypeDetails      # MailUniversalDistributionGroup / MailUniversalSecurityGroup
        NumeroMembri    = @($membri).Count
        Membri          = (($membri | Select-Object -ExpandProperty PrimarySmtpAddress -ErrorAction SilentlyContinue) -join ';')
        Owner           = (($g.ManagedBy) -join ';')
        RichiedeApprova = $g.RequireSenderAuthenticationEnabled
        Nascosto        = $g.HiddenFromAddressListsEnabled
    })
}

# --- Gruppi Microsoft 365 -------------------------------------------------------------
Write-Host "Gruppi Microsoft 365..." -ForegroundColor Cyan
foreach ($g in Get-UnifiedGroup -ResultSize Unlimited) {
    $membri = @(); $owner = @()
    if (-not $SkipMembers) {
        # Due chiamate distinte: -LinkType accetta un valore alla volta.
        try { $membri = Get-UnifiedGroupLinks -Identity $g.Identity -LinkType Members -ResultSize Unlimited } catch { }
        try { $owner  = Get-UnifiedGroupLinks -Identity $g.Identity -LinkType Owners  -ResultSize Unlimited } catch { }
    }
    $report.Add([pscustomobject]@{
        Nome            = $g.DisplayName
        SmtpPrimario    = $g.PrimarySmtpAddress
        Tipo            = 'Microsoft365Group'
        NumeroMembri    = @($membri).Count
        Membri          = (($membri | Select-Object -ExpandProperty PrimarySmtpAddress -ErrorAction SilentlyContinue) -join ';')
        Owner           = (($owner | Select-Object -ExpandProperty PrimarySmtpAddress -ErrorAction SilentlyContinue) -join ';')
        RichiedeApprova = $g.RequireSenderAuthenticationEnabled
        Nascosto        = $g.HiddenFromExchangeClientsEnabled
    })
}

# --- Gruppi dinamici: il filtro va riscritto sul target, i membri non si copiano -------
Write-Host "Gruppi di distribuzione dinamici..." -ForegroundColor Cyan
foreach ($g in Get-DynamicDistributionGroup -ResultSize Unlimited) {
    $report.Add([pscustomobject]@{
        Nome            = $g.DisplayName
        SmtpPrimario    = $g.PrimarySmtpAddress
        Tipo            = 'DynamicDistributionGroup'
        NumeroMembri    = '(calcolato dal filtro)'
        Membri          = ("FILTRO: " + $g.RecipientFilter)
        Owner           = (($g.ManagedBy) -join ';')
        RichiedeApprova = $g.RequireSenderAuthenticationEnabled
        Nascosto        = $g.HiddenFromAddressListsEnabled
    })
}

$report | Sort-Object Tipo, Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ("Gruppi totali: {0}" -f $report.Count)
$report | Group-Object Tipo | ForEach-Object { Write-Host ("  {0,-30} {1}" -f $_.Name, $_.Count) }
Write-Host ("Esportato in {0}" -f $OutputCsv)
Write-Host ""
Write-Host "Nota: i gruppi di sicurezza NON mail-enabled non compaiono qui. Vedi lo script 09." -ForegroundColor Yellow
