<#
.SYNOPSIS
    Verifica l'esito dell'upgrade a Windows 11 e lo stato di salute del PC.
.DESCRIPTION
    Dopo l'upgrade controlla: che il sistema sia effettivamente Windows 11, versione/build,
    spazio recuperabile dai file della vecchia installazione (Windows.old), e la finestra
    di rollback residua (~10 giorni). Segnala se il rollback a Windows 10 è ancora possibile.
    Sola lettura.
.EXAMPLE
    .\10-Test-Windows11PostUpgrade.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Eseguire come amministratore.
    Rollback: Impostazioni > Sistema > Ripristino (disponibile ~10 giorni dopo l'upgrade).
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Win11-PostUpgrade-{0}-{1}.csv" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'

$os = Get-CimInstance Win32_OperatingSystem
$isWin11 = $os.Caption -match 'Windows 11'
$ver = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion

$winOld = Test-Path "$env:SystemDrive\Windows.old"
$rollbackDays = ''
if ($winOld) {
    $created = (Get-Item "$env:SystemDrive\Windows.old").CreationTime
    $rollbackDays = [math]::Max(0, 10 - (New-TimeSpan -Start $created -End (Get-Date)).Days)
}

$result = [pscustomobject]@{
    Computer          = $env:COMPUTERNAME
    Edizione          = $os.Caption
    Versione          = $ver
    Build             = $os.BuildNumber
    Windows11         = $isWin11
    WindowsOldPresente = $winOld
    RollbackGiorniResidui = $rollbackDays
}
$result | Format-List
$result | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
if ($isWin11) {
    Write-Host ("Upgrade a Windows 11 riuscito (build {0}, {1})." -f $os.BuildNumber, $ver) -ForegroundColor Green
    if ($winOld) { Write-Host ("Rollback ancora possibile per ~{0} giorni; poi liberare spazio eliminando Windows.old (Pulizia disco)." -f $rollbackDays) -ForegroundColor Cyan }
} else {
    Write-Host 'Il sistema NON risulta Windows 11: verificare i log dell''upgrade.' -ForegroundColor Yellow
}
