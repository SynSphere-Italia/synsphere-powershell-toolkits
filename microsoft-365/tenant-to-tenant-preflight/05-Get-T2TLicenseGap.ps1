#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement
<#
.SYNOPSIS
    Licenze assegnate per utente, usageLocation e conteggio per SKU.
.DESCRIPTION
    Serve a due cose: sapere quante licenze acquistare sul tenant di destinazione, e scoprire
    prima della migrazione chi non ha usageLocation valorizzata (senza quel campo l'assegnazione
    della licenza sul target fallisce).

    Il default che rovina il report: Get-MgUser restituisce solo undici proprieta', e
    assignedLicenses, usageLocation e licenseAssignmentStates NON sono fra quelle. Senza
    -Property esplicito usageLocation esce vuota per tutti e lo script conclude che nessuno
    l'ha impostata: e' il falso positivo perfetto, perche' e' esattamente il controllo che deve
    fare. Serve anche -All, perche' la pagina di default e' 100 utenti.

    Distingue inoltre le licenze assegnate DIRETTAMENTE da quelle che arrivano da un gruppo
    (group-based licensing): sul target il gruppo va ricreato prima, altrimenti quelle licenze
    non si riassegnano da sole.

    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV per utente. Default: .\T2T-Licenses-<data>.csv
.PARAMETER SkuCsv
    Percorso del CSV di riepilogo per SKU. Default: .\T2T-LicenseSkus-<data>.csv
.EXAMPLE
    .\05-Get-T2TLicenseGap.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: User.Read.All, Organization.Read.All, Directory.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\T2T-Licenses-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')),
    [string]$SkuCsv    = (".\T2T-LicenseSkus-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'User.Read.All', 'Organization.Read.All', 'Directory.Read.All' -NoWelcome

# --- SKU del tenant: mappa GUID -> nome, e unita' acquistate/assegnate -----------------
$sku = Get-MgSubscribedSku -All
$mappaSku = @{}
foreach ($s in $sku) { $mappaSku[$s.SkuId] = $s.SkuPartNumber }

$riepilogo = foreach ($s in $sku) {
    [pscustomobject]@{
        SkuPartNumber = $s.SkuPartNumber
        SkuId         = $s.SkuId
        # PrepaidUnits e' un oggetto complesso: esportato senza espanderlo il CSV mostrerebbe
        # il nome del tipo .NET al posto dei numeri.
        Acquistate    = $s.PrepaidUnits.Enabled
        InSospensione = $s.PrepaidUnits.Suspended
        InAvviso      = $s.PrepaidUnits.Warning
        Assegnate     = $s.ConsumedUnits
        Disponibili   = ($s.PrepaidUnits.Enabled - $s.ConsumedUnits)
    }
}
$riepilogo | Sort-Object SkuPartNumber | Export-Csv -Path $SkuCsv -NoTypeInformation -Encoding UTF8

# --- Utenti: le proprieta' vanno chieste esplicitamente --------------------------------
$utenti = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, UserType, AccountEnabled,
    UsageLocation, AssignedLicenses, LicenseAssignmentStates, Mail

$report = foreach ($u in $utenti) {
    $lic = @($u.AssignedLicenses)
    if ($lic.Count -eq 0) { continue }

    $nomi = foreach ($l in $lic) {
        if ($mappaSku.ContainsKey($l.SkuId)) { $mappaSku[$l.SkuId] } else { $l.SkuId }
    }

    # licenseAssignmentStates dice DA DOVE arriva la licenza: assignedByGroup valorizzato
    # significa group-based licensing, e sul target va ricreato prima il gruppo.
    $daGruppo = @($u.LicenseAssignmentStates | Where-Object { $_.AssignedByGroup })
    $dirette  = @($u.LicenseAssignmentStates | Where-Object { -not $_.AssignedByGroup })
    $errori   = @($u.LicenseAssignmentStates | Where-Object { $_.State -eq 'Error' })

    [pscustomobject]@{
        DisplayName        = $u.DisplayName
        UserPrincipalName  = $u.UserPrincipalName
        Tipo               = $u.UserType
        Abilitato          = $u.AccountEnabled
        UsageLocation      = $u.UsageLocation
        UsageLocationOk    = [bool]$u.UsageLocation
        Licenze            = ($nomi -join ';')
        NumeroLicenze      = $lic.Count
        AssegnateDaGruppo  = $daGruppo.Count
        AssegnateDirette   = $dirette.Count
        LicenzeInErrore    = $errori.Count
    }
}

$report | Sort-Object UserPrincipalName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$senzaLoc = @($report | Where-Object { -not $_.UsageLocationOk }).Count
Write-Host ("Utenti con licenza: {0} | SKU distinti nel tenant: {1}" -f @($report).Count, @($sku).Count)
Write-Host ("Senza usageLocation: {0}" -f $senzaLoc) -ForegroundColor $(if ($senzaLoc) { 'Yellow' } else { 'Green' })
Write-Host ("Con licenze da gruppo: {0}" -f @($report | Where-Object { $_.AssegnateDaGruppo -gt 0 }).Count)
Write-Host ("Esportati: {0} e {1}" -f $OutputCsv, $SkuCsv)
