#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users
<#
.SYNOPSIS
    Disabilita (o elimina) gli account utente inattivi da oltre N giorni.
.DESCRIPTION
    Individua gli account che non accedono (interattivo o non interattivo) da più di N
    giorni e, su richiesta, li DISABILITA o li ELIMINA. Default = solo report.
    Supporta -WhatIf. Operazione di scrittura: usare con estrema cautela.
.PARAMETER InactiveDays
    Soglia di inattività. Default: 90.
.PARAMETER Action
    Report (default) | Disable | Delete.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-InactiveUsers-<data>.csv
.EXAMPLE
    .\09-Remove-M365InactiveUsers.ps1 -InactiveDays 120           # solo report
.EXAMPLE
    .\09-Remove-M365InactiveUsers.ps1 -InactiveDays 120 -Action Disable -WhatIf
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is". Testare con -WhatIf.
    Permessi Graph: User.ReadWrite.All, AuditLog.Read.All
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$InactiveDays = 90,
    [ValidateSet('Report', 'Disable', 'Delete')][string]$Action = 'Report',
    [string]$OutputCsv = (".\M365-InactiveUsers-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.ReadWrite.All', 'AuditLog.Read.All' -NoWelcome

$cutoff = (Get-Date).AddDays(-$InactiveDays)
$report = foreach ($u in Get-MgUser -All -Property DisplayName, UserPrincipalName, Id, AccountEnabled, SignInActivity) {
    $dates = @($u.SignInActivity.LastSignInDateTime, $u.SignInActivity.LastNonInteractiveSignInDateTime) |
        Where-Object { $_ } | ForEach-Object { [datetime]$_ }
    $real = if ($dates) { ($dates | Measure-Object -Maximum).Maximum } else { $null }
    if (($null -eq $real) -or ($real -lt $cutoff)) {
        $done = 'Report'
        if ($Action -eq 'Disable' -and $PSCmdlet.ShouldProcess($u.UserPrincipalName, 'Disabilita account')) {
            Update-MgUser -UserId $u.Id -AccountEnabled:$false; $done = 'Disabled'
        } elseif ($Action -eq 'Delete' -and $PSCmdlet.ShouldProcess($u.UserPrincipalName, 'ELIMINA account')) {
            Remove-MgUser -UserId $u.Id; $done = 'Deleted'
        }
        [pscustomobject]@{
            DisplayName       = $u.DisplayName
            UserPrincipalName = $u.UserPrincipalName
            RealLastSignIn    = if ($real) { $real.ToString('yyyy-MM-dd') } else { 'Mai' }
            WasEnabled        = $u.AccountEnabled
            ActionTaken       = $done
        }
    }
}
$report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} account inattivi da oltre {1} giorni (azione: {2}) → {3}" -f $report.Count, $InactiveDays, $Action, $OutputCsv) -ForegroundColor Yellow
if ($Action -eq 'Report') { Write-Host "Solo report. Rilancia con -Action Disable (e -WhatIf) per agire." -ForegroundColor Yellow }
