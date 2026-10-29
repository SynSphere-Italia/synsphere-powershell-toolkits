<#
.SYNOPSIS
    Censimento delle licenze Microsoft 365 Copilot assegnate nel tenant.
.DESCRIPTION
    Elenca chi ha una licenza Copilot, quante ne sono state acquistate e quante
    restano libere. Serve a rispondere alla domanda che apre ogni discussione sul
    rinnovo: quante ne stiamo pagando e a chi sono in mano.

    DUE SCELTE TECNICHE CHE VALE LA PENA SPIEGARE:
    1. Lo SkuId di Copilot viene RISOLTO A RUNTIME da Get-MgSubscribedSku, non
       cablato come GUID. I GUID degli SKU cambiano fra tenant e nel tempo: un
       GUID scritto dentro uno script e' una bomba a orologeria che un giorno
       restituisce zero utenti senza dare errore.
    2. Non usa Get-MgUserLicenseDetail per il censimento di massa, perche' la
       REST dichiara quel percorso "Application | Not supported": in uno script
       non presidiato (app-only) non funziona. Si usa Get-MgUser con il filtro
       sulle assignedLicenses, che regge anche app-only.

    LIMITE: la semantica delle licenze EREDITATE DA GRUPPO non e' la stessa e non
    e' verificata da questo script. Se il tenant assegna Copilot via gruppo, il
    conteggio per utente resta valido ma la colonna sulla provenienza no.

    Sola lettura.
.PARAMETER FiltroSku
    Testo da cercare nello SkuPartNumber. Default 'COPILOT', che intercetta
    Microsoft_365_Copilot e le varianti.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\AI-CopilotLicenses-<data>.csv
.EXAMPLE
    .\06-Get-CopilotLicenseInventory.ps1
.NOTES
    SynSphere Italia - https://synsphere.it - Fornito "as is".
    Cmdlet verificati su learn.microsoft.com il 19 agosto 2026.
    Le superfici di governance degli agenti AI cambiano ogni mese: prima di un
    uso in produzione esegui 00-Test-Prerequisiti.ps1, che controlla che i
    cmdlet esistano davvero nella versione di modulo installata.
#>
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement
[CmdletBinding()]
param(
    [string]$FiltroSku = 'COPILOT',
    [string]$OutputCsv = (".\AI-CopilotLicenses-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes 'Organization.Read.All', 'User.Read.All', 'Directory.Read.All' -NoWelcome
}

Write-Host 'Risoluzione degli SKU sottoscritti...' -ForegroundColor Cyan
$sku = Get-MgSubscribedSku -All | Where-Object { $_.SkuPartNumber -like "*$FiltroSku*" }

if (-not $sku) {
    Write-Host ''
    Write-Host ("Nessuno SKU con '{0}' nel nome. SKU presenti nel tenant:" -f $FiltroSku) -ForegroundColor Yellow
    Get-MgSubscribedSku -All | Sort-Object SkuPartNumber |
        Format-Table SkuPartNumber, @{n='Acquistate';e={$_.PrepaidUnits.Enabled}}, ConsumedUnits -AutoSize
    Write-Host 'Rilancia con -FiltroSku sul nome giusto.' -ForegroundColor Yellow
    return
}

Write-Host ''
Write-Host ('=' * 74)
Write-Host ' SKU COPILOT NEL TENANT'
Write-Host ('=' * 74)
foreach ($s in $sku) {
    $tot = $s.PrepaidUnits.Enabled
    $usate = $s.ConsumedUnits
    Write-Host ("  {0,-38} acquistate {1,5}   assegnate {2,5}   libere {3,5}" `
        -f $s.SkuPartNumber, $tot, $usate, ($tot - $usate))
}
Write-Host ''

$righe = @()
foreach ($s in $sku) {
    Write-Host ("Utenti con {0}..." -f $s.SkuPartNumber) -ForegroundColor Cyan
    $filtro = "assignedLicenses/any(u:u/skuId eq {0})" -f $s.SkuId
    try {
        $utenti = Get-MgUser -Filter $filtro -All `
                    -Property 'Id,DisplayName,UserPrincipalName,AccountEnabled,Department,JobTitle,UsageLocation,AssignedLicenses,SignInActivity' `
                    -ErrorAction Stop
    }
    catch {
        # SignInActivity richiede un permesso in piu' (AuditLog.Read.All) e su
        # alcuni tenant non e' disponibile: si riprova senza, invece di morire.
        Write-Warning 'Ritento senza SignInActivity (richiede AuditLog.Read.All).'
        $utenti = Get-MgUser -Filter $filtro -All `
                    -Property 'Id,DisplayName,UserPrincipalName,AccountEnabled,Department,JobTitle,UsageLocation,AssignedLicenses'
    }

    foreach ($u in $utenti) {
        $ultimo = ''
        if ($u.PSObject.Properties.Name -contains 'SignInActivity' -and $u.SignInActivity) {
            $ultimo = $u.SignInActivity.LastSignInDateTime
        }
        $righe += [pscustomobject]@{
            Sku               = $s.SkuPartNumber
            DisplayName       = $u.DisplayName
            UserPrincipalName = $u.UserPrincipalName
            AccountEnabled    = $u.AccountEnabled
            Reparto           = $u.Department
            Ruolo             = $u.JobTitle
            UsageLocation     = $u.UsageLocation
            UltimoAccesso     = $ultimo
            LicenzeTotali     = @($u.AssignedLicenses).Count
        }
    }
    Write-Host ("  {0} utenti" -f @($utenti).Count) -ForegroundColor Green
}

$righe | Sort-Object Sku, DisplayName |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$disattivi = @($righe | Where-Object { $_.AccountEnabled -eq $false }).Count
Write-Host ''
Write-Host ("Esportato: {0}  ({1} assegnazioni)" -f $OutputCsv, $righe.Count) -ForegroundColor Green
if ($disattivi -gt 0) {
    Write-Host ("ATTENZIONE: {0} licenze Copilot sono su account DISATTIVATI." -f $disattivi) -ForegroundColor Red
    Write-Host 'Sono le prime da recuperare: si pagano e non le usa nessuno.'
}
Write-Host ''
Write-Host 'NOTA sulla lettura: gli agent user creati per gli agenti AI non sono' -ForegroundColor Yellow
Write-Host 'utenti umani. Se compaiono qui, vanno esclusi dai KPI di adozione'
Write-Host '(usa lo script 02 per identificarli) altrimenti il denominatore e sbagliato.'
