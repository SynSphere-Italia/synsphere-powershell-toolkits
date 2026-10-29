<#
.SYNOPSIS
    Stato dettagliato del TPM (Trusted Platform Module) del PC.
.DESCRIPTION
    Riporta presenza, versione (SpecVersion), stato di abilitazione e readiness del TPM,
    requisito chiave per Windows 11. Utile a distinguere "TPM assente" da "TPM presente
    ma disabilitato nel BIOS/UEFI" (spesso basta abilitarlo). Sola lettura.
.EXAMPLE
    .\03-Get-TpmStatus.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Eseguire come amministratore.
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\TPM-Status-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'

$wmi = Get-CimInstance -Namespace 'root/cimv2/security/microsofttpm' -ClassName Win32_Tpm -ErrorAction SilentlyContinue
$g = try { Get-Tpm } catch { $null }

$result = [pscustomobject]@{
    Computer   = $env:COMPUTERNAME
    Presente   = [bool]$wmi
    Versione   = if ($wmi) { ($wmi.SpecVersion -split ',')[0] } else { 'N/D' }
    Abilitato  = if ($g) { $g.TpmEnabled } else { $wmi.IsEnabled_InitialValue }
    Attivato   = if ($g) { $g.TpmActivated } else { $wmi.IsActivated_InitialValue }
    Pronto     = if ($g) { $g.TpmReady } else { 'N/D' }
    Produttore = if ($wmi) { $wmi.ManufacturerIdTxt } else { 'N/D' }
    Idoneo_Win11 = ([bool]$wmi -and ($wmi.SpecVersion -match '2\.0') -and $wmi.IsEnabled_InitialValue)
}
$result | Format-List
$result | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
if ($result.Idoneo_Win11) { Write-Host 'TPM 2.0 OK per Windows 11.' -ForegroundColor Green }
elseif ($result.Presente) { Write-Host 'TPM presente ma non conforme/abilitato: controllare BIOS/UEFI (PTT/fTPM).' -ForegroundColor Yellow }
else { Write-Host 'TPM non rilevato.' -ForegroundColor Red }
