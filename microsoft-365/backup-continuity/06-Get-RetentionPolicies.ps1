#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Policy di conservazione di Microsoft Purview (retention).
.DESCRIPTION
    Elenca le retention policy di Microsoft Purview (Compliance) con stato, modalità e
    workload dichiarato. Le retention policy definiscono per quanto tempo i contenuti (email,
    file SharePoint/OneDrive, Teams) vengono conservati o eliminati: sono il pilastro della
    conservazione a livello di organizzazione. Sola lettura.
    NOTA: il campo "Workload" del cmdlet elenca sempre tutti i workload possibili, non
    l'ambito effettivo su cui la policy è applicata (usare -DistributionDetail per quello).
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\M365-RetentionPolicies-<data>.csv
.EXAMPLE
    .\06-Get-RetentionPolicies.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Modulo: ExchangeOnlineManagement, ma via Connect-IPPSSession (Security & Compliance).
    Serve modulo v3.2.0+. Il cmdlet NON esiste con Connect-ExchangeOnline.
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\M365-RetentionPolicies-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

# Connette a Security & Compliance solo se non già connesso
try {
    $policies = Get-RetentionCompliancePolicy -ErrorAction Stop
}
catch {
    Connect-IPPSSession
    $policies = Get-RetentionCompliancePolicy
}

$report = foreach ($p in $policies) {
    [pscustomobject]@{
        Nome     = $p.Name
        Abilitata = $p.Enabled
        Modalita = $p.Mode
        # NB: 'Workload' del cmdlet elenca SEMPRE tutti i workload possibili, non l'ambito
        # effettivo della policy. Per le posizioni reali applicate usare -DistributionDetail.
        WorkloadDichiarato = $p.Workload
    }
}

$report | Sort-Object Nome | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Trovate {0} retention policy Purview -> {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
