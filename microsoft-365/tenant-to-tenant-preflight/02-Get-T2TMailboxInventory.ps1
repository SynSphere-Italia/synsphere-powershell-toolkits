#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Inventario delle mailbox con ExchangeGuid, ArchiveGuid, dimensioni e numero elementi.
.DESCRIPTION
    E' il documento di riferimento di tutta la migrazione: ExchangeGuid e ArchiveGuid sono i
    valori che vanno riportati sugli oggetti mail-enabled del tenant di destinazione perche' il
    servizio di spostamento riconosca la cassetta come la stessa.

    Tre default di Exchange Online rendono questo report sbagliato se non li si forza, e nessuno
    dei tre produce un errore:
      - Get-EXOMailbox usa il property set 'Minimum': ExchangeGuid e ArchiveGuid NON escono e le
        colonne restano vuote. Vanno chiesti esplicitamente.
      - ResultSize vale 1000: oltre quella soglia l'elenco tronca in silenzio.
      - Il parametro -Archive e' un FILTRO (restituisce solo le cassette con archivio), non un
        espansore: la dimensione dell'archivio richiede una seconda chiamata per cassetta.

    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\T2T-Mailboxes-<data>.csv
.PARAMETER SkipStatistics
    Salta le statistiche di dimensione. Utile sui tenant grandi: senza questo interruttore lo
    script esegue una chiamata per cassetta (due se c'e' l'archivio).
.EXAMPLE
    .\02-Get-T2TMailboxInventory.ps1
.EXAMPLE
    .\02-Get-T2TMailboxInventory.ps1 -SkipStatistics
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Ruolo minimo: View-Only Organization Management (include View-Only Recipients)
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\T2T-Mailboxes-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')),
    [switch]$SkipStatistics
)
$ErrorActionPreference = 'Stop'

function ConvertTo-Bytes {
    <#
        TotalItemSize non e' un numero. A seconda del cmdlet e della versione del modulo torna
        un oggetto ByteQuantifiedSize oppure una stringa del tipo "1.234 GB (1.324.343 bytes)".
        Sommare quelle stringhe produce una concatenazione, non un totale: qui si normalizza
        sempre in byte, che e' anche l'unita' con cui il cruscotto (script 10) confronta
        Exchange, SharePoint e i report Graph.
    #>
    param($Size)
    if ($null -eq $Size) { return $null }
    if ($Size.PSObject.Methods.Name -contains 'ToBytes') { return [int64]$Size.ToBytes() }
    if ($Size.Value -and $Size.Value.PSObject.Methods.Name -contains 'ToBytes') { return [int64]$Size.Value.ToBytes() }
    $m = [regex]::Match([string]$Size, '\(([\d\.,\s]+)\s*bytes\)')
    if ($m.Success) { return [int64](($m.Groups[1].Value -replace '[^\d]', '')) }
    return $null
}

if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
    Connect-ExchangeOnline -ShowBanner:$false
}

Write-Host "Lettura delle cassette..." -ForegroundColor Cyan

$mailboxes = Get-EXOMailbox -ResultSize Unlimited `
    -RecipientTypeDetails UserMailbox, SharedMailbox, RoomMailbox, EquipmentMailbox `
    -PropertySets Minimum, Archive `
    -Properties DisplayName, UserPrincipalName, PrimarySmtpAddress, ExchangeGuid, ArchiveGuid,
                ArchiveStatus, RecipientTypeDetails, EmailAddresses, WhenCreated

$totale = @($mailboxes).Count
$i = 0

$report = foreach ($mb in $mailboxes) {
    $i++
    if ($totale -gt 50 -and ($i % 25) -eq 0) {
        Write-Progress -Activity "Statistiche cassette" -Status ("{0} di {1}" -f $i, $totale) -PercentComplete (100 * $i / $totale)
    }

    $sizeBytes = $null; $items = $null; $archBytes = $null; $archItems = $null

    if (-not $SkipStatistics) {
        try {
            $st = Get-MailboxStatistics -Identity $mb.ExchangeGuid.ToString() -ErrorAction Stop
            $sizeBytes = ConvertTo-Bytes $st.TotalItemSize
            $items     = $st.ItemCount
        } catch {
            Write-Warning ("Statistiche non leggibili per {0}" -f $mb.UserPrincipalName)
        }

        # L'archivio richiede una chiamata a se': -Archive non e' incluso nella precedente.
        if ($mb.ArchiveGuid -and $mb.ArchiveGuid -ne [guid]::Empty) {
            try {
                $sa = Get-MailboxStatistics -Identity $mb.ExchangeGuid.ToString() -Archive -ErrorAction Stop
                $archBytes = ConvertTo-Bytes $sa.TotalItemSize
                $archItems = $sa.ItemCount
            } catch {
                Write-Warning ("Statistiche archivio non leggibili per {0}" -f $mb.UserPrincipalName)
            }
        }
    }

    [pscustomobject]@{
        DisplayName        = $mb.DisplayName
        UserPrincipalName  = $mb.UserPrincipalName
        SmtpPrimario       = $mb.PrimarySmtpAddress
        Tipo               = $mb.RecipientTypeDetails
        ExchangeGuid       = $mb.ExchangeGuid
        ArchiveGuid        = $mb.ArchiveGuid
        StatoArchivio      = $mb.ArchiveStatus
        DimensioneByte     = $sizeBytes
        DimensioneGB       = if ($null -ne $sizeBytes) { [math]::Round($sizeBytes / 1GB, 2) } else { $null }
        NumeroElementi     = $items
        ArchivioByte       = $archBytes
        ArchivioGB         = if ($null -ne $archBytes) { [math]::Round($archBytes / 1GB, 2) } else { $null }
        ArchivioElementi   = $archItems
        AliasSmtp          = (($mb.EmailAddresses | Where-Object { $_ -clike 'smtp:*' }) -join ';')
        CreataIl           = $mb.WhenCreated
    }
}

Write-Progress -Activity "Statistiche cassette" -Completed
$report | Sort-Object Tipo, UserPrincipalName | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

$gb = [math]::Round((($report.DimensioneByte | Measure-Object -Sum).Sum + ($report.ArchivioByte | Measure-Object -Sum).Sum) / 1GB, 2)
Write-Host ("Cassette: {0} | volume totale (primaria + archivio): {1} GB" -f $totale, $gb)
Write-Host ("Esportato in {0}" -f $OutputCsv)
