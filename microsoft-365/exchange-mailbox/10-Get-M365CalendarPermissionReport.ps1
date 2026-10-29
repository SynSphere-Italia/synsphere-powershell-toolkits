#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Report permessi sui calendari (chi può vedere/modificare il calendario di chi).
.DESCRIPTION
    Per ogni casella esporta i permessi assegnati sulla cartella Calendario, inclusi i
    livelli "Default" e "Anonymous" (un Default troppo permissivo = oversharing).
    Individua automaticamente la cartella calendario anche su tenant in italiano
    (FolderType = Calendar), quindi è language-safe. Sola lettura.
.PARAMETER UserPrincipalName
    Opzionale: limita il report al calendario di un singolo utente.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-CalendarPermissions-<data>.csv
.EXAMPLE
    .\10-Get-M365CalendarPermissionReport.ps1 -UserPrincipalName mario.rossi@azienda.it
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients). Su tutte le caselle è lento.
#>
[CmdletBinding()]
param(
    [string]$UserPrincipalName,
    [string]$OutputCsv = (".\M365-CalendarPermissions-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$mailboxes = if ($UserPrincipalName) { Get-EXOMailbox -Identity $UserPrincipalName } else { Get-EXOMailbox -ResultSize Unlimited }

$report = foreach ($mbx in $mailboxes) {
    $id = $mbx.PrimarySmtpAddress
    # Trova la cartella calendario per tipo (language-safe: "Calendar" o "Calendario")
    $cal = Get-EXOMailboxFolderStatistics -Identity $id -FolderScope Calendar -ErrorAction SilentlyContinue |
        Where-Object { $_.FolderType -eq 'Calendar' } | Select-Object -First 1
    if (-not $cal) { continue }
    $folderId = "{0}:\{1}" -f $id, $cal.Name
    foreach ($p in Get-EXOMailboxFolderPermission -Identity $folderId -ErrorAction SilentlyContinue | Where-Object { $_.AccessRights -ne 'None' }) {
        [pscustomobject]@{
            Calendar     = $id
            User         = $p.User
            AccessRights = ($p.AccessRights -join ', ')
        }
    }
}
$report | Sort-Object Calendar, User | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Esportati {0} permessi calendario in {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
