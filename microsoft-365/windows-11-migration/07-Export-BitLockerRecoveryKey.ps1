<#
.SYNOPSIS
    Esporta le chiavi di ripristino BitLocker PRIMA dell'upgrade (rete di sicurezza).
.DESCRIPTION
    Prima di un upgrade o di modifiche a firmware/Secure Boot è essenziale avere le chiavi
    di ripristino BitLocker: un cambio di stato del TPM può far scattare la richiesta della
    chiave al riavvio. Lo script esporta ID e chiave numerica dei volumi protetti in un CSV.
    Sola lettura sui protettori. ATTENZIONE: il CSV contiene segreti — conservarlo in luogo
    sicuro e cifrato, non lasciarlo sul disco.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\BitLocker-RecoveryKeys-<computer>-<data>.csv
.EXAMPLE
    .\07-Export-BitLockerRecoveryKey.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Eseguire come amministratore.
    In ambienti gestiti le chiavi dovrebbero essere salvate in Entra ID / Active Directory.
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\BitLocker-RecoveryKeys-{0}-{1}.csv" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'

$rows = foreach ($v in (Get-BitLockerVolume | Where-Object { $_.VolumeStatus -ne 'FullyDecrypted' })) {
    $rp = $v.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
    foreach ($p in $rp) {
        [pscustomobject]@{
            Computer      = $env:COMPUTERNAME
            Volume        = $v.MountPoint
            Stato         = $v.VolumeStatus
            KeyProtectorId = $p.KeyProtectorId
            RecoveryKey   = $p.RecoveryPassword
        }
    }
}
if (-not $rows) { Write-Host 'Nessun volume BitLocker con chiave di ripristino trovato.' -ForegroundColor Yellow; return }
$rows | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$rows | Format-Table Computer, Volume, KeyProtectorId -AutoSize
Write-Host ("Esportate {0} chiavi → {1}  (CONTIENE SEGRETI: proteggi e sposta in luogo sicuro)" -f $rows.Count, $OutputCsv) -ForegroundColor Green
