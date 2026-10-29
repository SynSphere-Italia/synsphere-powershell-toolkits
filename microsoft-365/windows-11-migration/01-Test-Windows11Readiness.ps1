<#
.SYNOPSIS
    Verifica se il PC locale soddisfa i requisiti hardware minimi di Windows 11.
.DESCRIPTION
    Controlla i requisiti verificabili localmente: TPM 2.0, Secure Boot, firmware UEFI,
    RAM >= 4 GB, disco di sistema >= 64 GB con spazio libero sufficiente, CPU 64-bit
    con >= 2 core e >= 1 GHz. Restituisce un oggetto con esito PASS/FAIL e la lista dei
    requisiti non soddisfatti. Sola lettura.
    NB: NON verifica il modello esatto di CPU rispetto alla lista di compatibilità
    Microsoft (usare PC Health Check per la conferma definitiva del processore).
.EXAMPLE
    .\01-Test-Windows11Readiness.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Eseguire come amministratore. Windows 10 22H2 consigliato prima dell'upgrade.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$fail = [System.Collections.Generic.List[string]]::new()

# TPM 2.0
$tpm = Get-CimInstance -Namespace 'root/cimv2/security/microsofttpm' -ClassName Win32_Tpm -ErrorAction SilentlyContinue
$tpmOk = $tpm -and $tpm.IsEnabled_InitialValue -and ($tpm.SpecVersion -match '2\.0')
if (-not $tpmOk) { $fail.Add('TPM 2.0 assente/non abilitato') }

# Secure Boot (Confirm-SecureBootUEFI genera errore su BIOS legacy)
$sb = $false
try { $sb = Confirm-SecureBootUEFI } catch { $sb = $false }
if (-not $sb) { $fail.Add('Secure Boot non attivo o firmware non UEFI') }

# RAM >= 4 GB
$cs = Get-CimInstance Win32_ComputerSystem
$ramGb = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
if ($ramGb -lt 4) { $fail.Add("RAM insufficiente ($ramGb GB, min 4)") }

# Disco di sistema >= 64 GB totali, >= 25 GB liberi per l'upgrade
$sys = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
$sizeGb = [math]::Round($sys.Size / 1GB, 1); $freeGb = [math]::Round($sys.FreeSpace / 1GB, 1)
if ($sizeGb -lt 64) { $fail.Add("Disco di sistema < 64 GB ($sizeGb GB)") }
if ($freeGb -lt 25) { $fail.Add("Spazio libero < 25 GB per l'upgrade ($freeGb GB)") }

# CPU: 64-bit, >= 2 core, >= 1 GHz
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
if ($cpu.AddressWidth -ne 64) { $fail.Add('CPU non a 64 bit') }
if ($cpu.NumberOfCores -lt 2) { $fail.Add('CPU con meno di 2 core') }
if ($cpu.MaxClockSpeed -lt 1000) { $fail.Add('CPU sotto 1 GHz') }

$result = [pscustomobject]@{
    Computer     = $env:COMPUTERNAME
    Windows11Ready = ($fail.Count -eq 0)
    RAM_GB       = $ramGb
    Disco_GB     = $sizeGb
    Libero_GB    = $freeGb
    TPM          = if ($tpmOk) { 'OK 2.0' } else { 'NO' }
    SecureBoot   = if ($sb) { 'OK' } else { 'NO' }
    CPU          = $cpu.Name.Trim()
    RequisitiMancanti = if ($fail.Count) { $fail -join '; ' } else { '' }
}
$result | Format-List
if ($result.Windows11Ready) {
    Write-Host 'PC IDONEO a Windows 11 (verificare comunque il modello CPU con PC Health Check).' -ForegroundColor Green
} else {
    Write-Host ("PC NON idoneo: {0}" -f $result.RequisitiMancanti) -ForegroundColor Yellow
}
