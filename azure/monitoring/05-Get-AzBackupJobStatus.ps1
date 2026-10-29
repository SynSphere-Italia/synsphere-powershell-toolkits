#Requires -Modules Az.Accounts, Az.RecoveryServices
<#
.SYNOPSIS
    Stato dei job di backup recenti (Recovery Services vault).
.DESCRIPTION
    Un backup configurato ma fallito è peggio di nessun backup, perché dà falsa sicurezza.
    Lo script elenca i job di backup recenti per ogni vault con esito e durata. Sola lettura.
.PARAMETER Days
    Finestra in giorni. Default: 7.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-BackupJobs-<data>.csv
.EXAMPLE
    .\05-Get-AzBackupJobStatus.ps1 -Days 14
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Backup Reader. Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\Az-BackupJobs-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = [System.Collections.Generic.List[object]]::new()
foreach ($vault in Get-AzRecoveryServicesVault) {
    try {
        $jobs = Get-AzRecoveryServicesBackupJob -VaultId $vault.ID -From (Get-Date).AddDays(-$Days).ToUniversalTime() -ErrorAction Stop
        foreach ($j in $jobs) {
            $report.Add([pscustomobject]@{
                Vault = $vault.Name; Risorsa = $j.WorkloadName; Operazione = $j.Operation
                Stato = $j.Status; Inizio = $j.StartTime; Durata = $j.Duration
            })
        }
    } catch { Write-Warning "Vault $($vault.Name): $($_.Exception.Message)" }
}
$report | Sort-Object Stato, Inizio -Descending | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$failed = @($report | Where-Object { $_.Stato -eq 'Failed' }).Count
Write-Host ("{0} job di backup ({1} falliti) → {2}" -f $report.Count, $failed, $OutputCsv) -ForegroundColor $(if ($failed) { 'Yellow' } else { 'Green' })
