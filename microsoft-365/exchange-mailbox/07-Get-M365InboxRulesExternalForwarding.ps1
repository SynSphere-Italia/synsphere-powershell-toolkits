#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Trova le REGOLE DELLA POSTA IN ARRIVO che inoltrano/redirigono verso domini ESTERNI.
.DESCRIPTION
    Le regole inbox che inoltrano a indirizzi esterni sono uno dei segnali più comuni
    di account compromesso (esfiltrazione silenziosa della posta). Lo script analizza
    le inbox rule di tutte le caselle e segnala quelle con forward/redirect verso domini
    NON accettati dal tenant. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-ExternalInboxRules-<data>.csv
.EXAMPLE
    .\07-Get-M365InboxRulesExternalForwarding.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online. Analizza le inbox rule di ogni casella: su tenant grandi è lento.
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-ExternalInboxRules-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

# Domini accettati dal tenant (tutto il resto è "esterno")
$accepted = (Get-AcceptedDomain).DomainName
function Test-External($recipients) {
    foreach ($r in $recipients) {
        if ($r -match 'SMTP:([^\]]+)') {
            $domain = ($matches[1] -split '@')[-1]
            if ($accepted -notcontains $domain) { return $true }
        }
    }
    return $false
}

$report = foreach ($mbx in Get-EXOMailbox -ResultSize Unlimited) {
    foreach ($rule in Get-InboxRule -Mailbox $mbx.PrimarySmtpAddress -ErrorAction SilentlyContinue) {
        $targets = @($rule.ForwardTo) + @($rule.RedirectTo) + @($rule.ForwardAsAttachmentTo) | Where-Object { $_ }
        if ($targets -and (Test-External $targets)) {
            [pscustomobject]@{
                Mailbox  = $mbx.PrimarySmtpAddress
                RuleName = $rule.Name
                Enabled  = $rule.Enabled
                Targets  = ($targets -join '; ')
            }
        }
    }
}
if ($report) {
    $report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host ("ATTENZIONE: {0} regole inbox con inoltro ESTERNO → {1}. Verificare possibili compromissioni." -f $report.Count, $OutputCsv) -ForegroundColor Red
} else {
    Write-Host "Nessuna inbox rule con inoltro esterno trovata." -ForegroundColor Green
}
