#Requires -Modules Az.Accounts, Az.KeyVault
<#
.SYNOPSIS
    Postura di sicurezza dei Key Vault: soft-delete, purge protection, modello di accesso.
.DESCRIPTION
    Controlla le impostazioni critiche di ogni Key Vault: soft-delete e purge protection
    (anti-cancellazione), modello di autorizzazione (RBAC vs access policy) e accesso di
    rete pubblico. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-KeyVaultSecurity-<data>.csv
.EXAMPLE
    .\06-Get-AzKeyVaultSecurity.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: ruolo Reader (control plane). Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-KeyVaultSecurity-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = foreach ($kvRef in Get-AzKeyVault) {
    $kv = Get-AzKeyVault -VaultName $kvRef.VaultName
    [pscustomobject]@{
        KeyVault         = $kv.VaultName
        ResourceGroup    = $kv.ResourceGroupName
        SoftDelete       = if ($kv.EnableSoftDelete) { 'ON' } else { 'OFF !' }
        PurgeProtection  = if ($kv.EnablePurgeProtection) { 'ON' } else { 'OFF !' }
        Autorizzazione   = if ($kv.EnableRbacAuthorization) { 'RBAC' } else { 'Access Policy' }
        RetePubblica     = $kv.PublicNetworkAccess
    }
}
$report | Sort-Object KeyVault | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
$report | Format-Table -AutoSize
Write-Host ("{0} Key Vault analizzati → {1}. Verifica i 'OFF !'." -f @($report).Count, $OutputCsv) -ForegroundColor Yellow
