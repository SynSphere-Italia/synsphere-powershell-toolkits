<#
.SYNOPSIS
    Inventario dei PC Windows 10 con edizione, versione/build e stato.
.DESCRIPTION
    Elenca i dispositivi Windows 10 (locale o remoti) con edizione, versione (es. 22H2),
    build, data di installazione e ultimo avvio. Serve a fotografare l'esposizione alla
    fine supporto (14/10/2025) e a pianificare le wave di migrazione. Sola lettura.
.PARAMETER ComputerName
    Elenco di computer (default: locale). In alternativa -CsvPath (colonna ComputerName).
.PARAMETER CsvPath
    CSV con colonna "ComputerName".
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Win10-Inventory-<data>.csv
.EXAMPLE
    .\05-Get-Windows10Inventory.ps1 -ComputerName PC01,PC02
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Per i target remoti serve WinRM abilitato e permessi amministrativi.
#>
[CmdletBinding()]
param(
    [string[]]$ComputerName = @($env:COMPUTERNAME),
    [string]$CsvPath,
    [string]$OutputCsv = (".\Win10-Inventory-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if ($CsvPath) { $ComputerName = (Import-Csv $CsvPath).ComputerName }

$grab = {
    $os = Get-CimInstance Win32_OperatingSystem
    $ver = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
    [pscustomobject]@{
        Edizione   = $os.Caption
        Versione   = $ver
        Build      = $os.BuildNumber
        Installato = $os.InstallDate
        UltimoAvvio = $os.LastBootUpTime
    }
}

$report = foreach ($c in $ComputerName) {
    try {
        $r = if ($c -in @($env:COMPUTERNAME, 'localhost', '.')) { & $grab } else { Invoke-Command -ComputerName $c -ScriptBlock $grab -ErrorAction Stop }
        [pscustomobject]@{ Computer = $c; Edizione = $r.Edizione; Versione = $r.Versione; Build = $r.Build; Installato = $r.Installato; UltimoAvvio = $r.UltimoAvvio; Windows10 = ($r.Edizione -match 'Windows 10') }
    } catch {
        [pscustomobject]@{ Computer = $c; Edizione = 'ERRORE'; Versione = ''; Build = ''; Installato = ''; UltimoAvvio = ''; Windows10 = '' ; Nota = $_.Exception.Message }
    }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$report | Format-Table -AutoSize
$win10 = ($report | Where-Object { $_.Windows10 -eq $true }).Count
Write-Host ("PC Windows 10 rilevati: {0}/{1} → {2}" -f $win10, $report.Count, $OutputCsv) -ForegroundColor Green
