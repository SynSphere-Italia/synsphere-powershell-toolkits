<#
.SYNOPSIS
    Report di idoneità a Windows 11 per un elenco di PC (intera flotta).
.DESCRIPTION
    Esegue i controlli di idoneità (TPM 2.0, Secure Boot, RAM, disco, CPU) su piu
    computer via WinRM (Invoke-Command) ed esporta un CSV riepilogativo con IDONEO/
    NON IDONEO e i requisiti mancanti per ciascun PC. Sola lettura.
.PARAMETER ComputerName
    Elenco di nomi computer. In alternativa usare -CsvPath.
.PARAMETER CsvPath
    CSV con una colonna "ComputerName".
.PARAMETER OutputCsv
    Percorso CSV di output. Default: .\Win11-Readiness-<data>.csv
.EXAMPLE
    .\02-Get-Windows11ReadinessReport.ps1 -ComputerName PC01,PC02,PC03
.EXAMPLE
    .\02-Get-Windows11ReadinessReport.ps1 -CsvPath .\pc.csv
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Richiede WinRM abilitato sui target (Enable-PSRemoting) e permessi amministrativi.
#>
[CmdletBinding()]
param(
    [string[]]$ComputerName,
    [string]$CsvPath,
    [string]$OutputCsv = (".\Win11-Readiness-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if ($CsvPath) { $ComputerName = (Import-Csv $CsvPath).ComputerName }
if (-not $ComputerName) { throw 'Specificare -ComputerName oppure -CsvPath.' }

$check = {
    $fail = @()
    $tpm = Get-CimInstance -Namespace 'root/cimv2/security/microsofttpm' -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    if (-not ($tpm -and $tpm.IsEnabled_InitialValue -and $tpm.SpecVersion -match '2\.0')) { $fail += 'TPM2.0' }
    $sb = $false; try { $sb = Confirm-SecureBootUEFI } catch { $sb = $false }
    if (-not $sb) { $fail += 'SecureBoot/UEFI' }
    $cs = Get-CimInstance Win32_ComputerSystem
    if (($cs.TotalPhysicalMemory / 1GB) -lt 4) { $fail += 'RAM<4GB' }
    $sys = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    if (($sys.Size / 1GB) -lt 64) { $fail += 'Disco<64GB' }
    if (($sys.FreeSpace / 1GB) -lt 25) { $fail += 'Libero<25GB' }
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    if ($cpu.AddressWidth -ne 64 -or $cpu.NumberOfCores -lt 2 -or $cpu.MaxClockSpeed -lt 1000) { $fail += 'CPU' }
    [pscustomobject]@{ RAM_GB = [math]::Round($cs.TotalPhysicalMemory/1GB,1); Libero_GB = [math]::Round($sys.FreeSpace/1GB,1); Mancanti = ($fail -join ',') }
}

$report = foreach ($c in $ComputerName) {
    try {
        $r = if ($c -in @($env:COMPUTERNAME, 'localhost', '.')) { & $check } else { Invoke-Command -ComputerName $c -ScriptBlock $check -ErrorAction Stop }
        [pscustomobject]@{ Computer = $c; Idoneo = ($r.Mancanti -eq ''); RAM_GB = $r.RAM_GB; Libero_GB = $r.Libero_GB; RequisitiMancanti = $r.Mancanti }
    } catch {
        [pscustomobject]@{ Computer = $c; Idoneo = 'ERRORE'; RAM_GB = ''; Libero_GB = ''; RequisitiMancanti = $_.Exception.Message }
    }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$report | Format-Table -AutoSize
$idonei = ($report | Where-Object { $_.Idoneo -eq $true }).Count
Write-Host ("Idonei {0}/{1} → {2}" -f $idonei, $report.Count, $OutputCsv) -ForegroundColor Green
