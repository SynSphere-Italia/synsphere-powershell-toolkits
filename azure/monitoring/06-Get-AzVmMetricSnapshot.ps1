#Requires -Modules Az.Accounts, Az.Compute, Az.Monitor
<#
.SYNOPSIS
    Snapshot delle metriche CPU delle VM (media e picco su N giorni).
.DESCRIPTION
    Estrae l'utilizzo CPU medio e massimo di ogni VM nel periodo: base oggettiva per
    decidere rightsizing (CPU sempre bassa = VM troppo grande). Sola lettura.
    NB: solo le VM in esecuzione producono metriche.
.PARAMETER Days
    Finestra in giorni. Default: 7.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-VmMetrics-<data>.csv
.EXAMPLE
    .\06-Get-AzVmMetricSnapshot.ps1 -Days 14
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader (Monitoring Reader). Prima esegui: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$OutputCsv = (".\Az-VmMetrics-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$start = (Get-Date).AddDays(-$Days)
$report = foreach ($vm in Get-AzVM) {
    $avg = $null; $max = $null
    try {
        $m = Get-AzMetric -ResourceId $vm.Id -MetricName 'Percentage CPU' -StartTime $start -EndTime (Get-Date) -TimeGrain 01:00:00 -AggregationType Average -WarningAction SilentlyContinue -ErrorAction Stop
        $vals = $m.Data.Average | Where-Object { $_ -ne $null }
        if ($vals) { $avg = [math]::Round(($vals | Measure-Object -Average).Average, 1); $max = [math]::Round(($vals | Measure-Object -Maximum).Maximum, 1) }
    } catch { }
    [pscustomobject]@{
        VM            = $vm.Name
        ResourceGroup = $vm.ResourceGroupName
        Size          = $vm.HardwareProfile.VmSize
        CPUMediaPct   = if ($null -ne $avg) { $avg } else { 'n/d' }
        CPUPiccoPct   = if ($null -ne $max) { $max } else { 'n/d' }
    }
}
$report | Sort-Object CPUMediaPct | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Snapshot metriche CPU di {0} VM ({1}gg) → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Green
