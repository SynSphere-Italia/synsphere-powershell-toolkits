#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Espande la membership delle liste di distribuzione ANNIDATE (gruppi dentro gruppi).
.DESCRIPTION
    Quando una DL contiene altre DL come membri, l'elenco reale dei destinatari è la somma
    ricorsiva. Lo script espande ogni DL seguendo i gruppi annidati e produce l'elenco
    piatto dei membri finali con il percorso di annidamento. Include una protezione anti-loop.
    Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\M365-NestedDL-<data>.csv
.EXAMPLE
    .\10-Get-M365NestedDistributionGroups.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi: Exchange Online (View-Only Recipients). Espansione ricorsiva: su strutture profonde è lento.
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\M365-NestedDL-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
Connect-ExchangeOnline -ShowBanner:$false

$rows = [System.Collections.Generic.List[object]]::new()

function Expand-DL {
    param([string]$Identity, [string]$Root, [string]$Path, [System.Collections.Generic.HashSet[string]]$Visited)
    if (-not $Visited.Add($Identity)) { return }   # già visitato → evita loop
    foreach ($m in Get-DistributionGroupMember -Identity $Identity -ResultSize Unlimited -ErrorAction SilentlyContinue) {
        if ($m.RecipientType -match 'Group') {
            # membro annidato: ricorsione
            Expand-DL -Identity $m.Identity -Root $Root -Path "$Path > $($m.DisplayName)" -Visited $Visited
        } else {
            $rows.Add([pscustomobject]@{ RootGroup = $Root; FinalMember = $m.DisplayName; MemberEmail = $m.PrimarySmtpAddress; NestingPath = $Path })
        }
    }
}

foreach ($dl in Get-DistributionGroup -ResultSize Unlimited) {
    # Espandi solo le DL che contengono almeno un gruppo annidato
    $hasNested = Get-DistributionGroupMember -Identity $dl.Identity -ResultSize Unlimited -ErrorAction SilentlyContinue |
        Where-Object { $_.RecipientType -match 'Group' }
    if ($hasNested) {
        Expand-DL -Identity $dl.Identity -Root $dl.DisplayName -Path $dl.DisplayName -Visited ([System.Collections.Generic.HashSet[string]]::new())
    }
}
$rows | Sort-Object RootGroup, FinalMember | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Espanse le DL annidate: {0} membri finali → {1}" -f $rows.Count, $OutputCsv) -ForegroundColor Green
