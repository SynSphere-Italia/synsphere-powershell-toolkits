#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Inventario delle policy di accesso condizionale (Conditional Access).
.DESCRIPTION
    Elenca ogni policy di accesso condizionale con stato (attiva / solo report / disattivata),
    controlli di concessione richiesti (MFA, dispositivo conforme, ecc.) e date di creazione
    e modifica. Documenta le regole che proteggono gli accessi: evidenza chiave per gli audit.
    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\ConditionalAccess-Policies-<data>.csv
.EXAMPLE
    .\09-Get-ConditionalAccessPolicies.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Policy.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\ConditionalAccess-Policies-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Policy.Read.All' -NoWelcome

$report = foreach ($p in Get-MgIdentityConditionalAccessPolicy -All) {
    [pscustomobject]@{
        Nome           = $p.DisplayName
        Stato          = $p.State
        Controlli      = ($p.GrantControls.BuiltInControls -join '; ')
        Operatore      = $p.GrantControls.Operator
        Creata         = $p.CreatedDateTime
        UltimaModifica = $p.ModifiedDateTime
    }
}

$report | Sort-Object Stato, Nome | Format-Table Nome, Stato, Controlli -AutoSize
$report | Sort-Object Stato, Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportate {0} policy di accesso condizionale -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
