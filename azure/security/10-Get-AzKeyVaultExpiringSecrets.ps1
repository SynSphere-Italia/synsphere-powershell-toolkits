#Requires -Modules Az.Accounts, Az.KeyVault
<#
.SYNOPSIS
    Segreti e certificati nei Key Vault in scadenza entro N giorni.
.DESCRIPTION
    Un certificato o un segreto scaduto può mandare offline un servizio. Lo script elenca
    segreti e certificati con scadenza imminente in tutti i Key Vault accessibili. Sola lettura.
    NB: richiede permessi DATA-PLANE (access policy o ruolo "Key Vault Reader"/"Secrets User").
.PARAMETER Days
    Finestra di scadenza in giorni. Default: 30.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-KeyVaultExpiring-<data>.csv
.EXAMPLE
    .\10-Get-AzKeyVaultExpiringSecrets.ps1 -Days 60
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Prima: Connect-AzAccount
#>
[CmdletBinding()]
param(
    [int]$Days = 30,
    [string]$OutputCsv = (".\Az-KeyVaultExpiring-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$limit = (Get-Date).AddDays($Days)
$report = [System.Collections.Generic.List[object]]::new()
foreach ($kv in Get-AzKeyVault) {
    $name = $kv.VaultName
    try {
        foreach ($s in Get-AzKeyVaultSecret -VaultName $name -ErrorAction Stop) {
            if ($s.Expires -and $s.Expires -le $limit) {
                $report.Add([pscustomobject]@{ KeyVault = $name; Tipo = 'Secret'; Nome = $s.Name; Scadenza = $s.Expires })
            }
        }
        foreach ($c in Get-AzKeyVaultCertificate -VaultName $name -ErrorAction Stop) {
            if ($c.Expires -and $c.Expires -le $limit) {
                $report.Add([pscustomobject]@{ KeyVault = $name; Tipo = 'Certificato'; Nome = $c.Name; Scadenza = $c.Expires })
            }
        }
    } catch {
        Write-Warning "Accesso data-plane negato su $name (serve un access policy/ruolo per secrets/certificates)."
    }
}
$report | Sort-Object Scadenza | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} segreti/certificati in scadenza entro {1} giorni → {2}" -f $report.Count, $Days, $OutputCsv) -ForegroundColor Yellow
