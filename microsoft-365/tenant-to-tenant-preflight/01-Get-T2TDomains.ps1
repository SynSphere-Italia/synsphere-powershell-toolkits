#Requires -Modules Microsoft.Graph.Identity.DirectoryManagement
<#
.SYNOPSIS
    Domini custom del tenant con stato di verifica e record DNS attualmente pubblicati.
.DESCRIPTION
    Inventaria i domini del tenant (verificato, predefinito, iniziale, gestito o federato) e per
    ognuno esporta i record di servizio che Microsoft 365 richiede OGGI su quel tenant: MX, TXT
    di verifica e SPF, CNAME e SRV.

    ATTENZIONE ALLO SCOPO. Questo script fotografa il tenant SORGENTE. NON produce i record da
    creare sul tenant di destinazione, e nessuno script potrebbe farlo prima dello spostamento:
    i CNAME DKIM del target dipendono dal prefisso del dominio iniziale del target e dalla
    partizione assegnata, valori che esistono solo dopo che il dominio e' stato aggiunto di la'.
    Un runbook DNS "gia' pronto" ricavato dal sorgente sarebbe sbagliato.

    Sola lettura.
.PARAMETER OutputCsv
    Percorso del CSV di output. Default: .\T2T-Domains-<data>.csv
.EXAMPLE
    .\01-Get-T2TDomains.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Permessi Graph: Domain.Read.All (Global Reader e' sufficiente)
#>
[CmdletBinding()]
param(
    [string]$OutputCsv = (".\T2T-Domains-{0}.csv" -f (Get-Date -Format 'yyyyMMdd'))
)
$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'Domain.Read.All' -NoWelcome

$report = foreach ($d in Get-MgDomain -All) {

    # Get-MgDomainServiceConfigurationRecord richiede l'ID del dominio: la catena si chiude
    # perche' Get-MgDomain li enumera tutti. E' una chiamata per dominio (pattern N+1).
    $records = @()
    try {
        $records = Get-MgDomainServiceConfigurationRecord -DomainId $d.Id -All
    } catch {
        Write-Warning ("Record di servizio non leggibili per {0}: {1}" -f $d.Id, $_.Exception.Message)
    }

    foreach ($r in $records) {
        $ap = $r.AdditionalProperties

        # Il valore utile sta in una proprieta' diversa per ogni tipo di record.
        $valore = switch ($r.RecordType) {
            'Mx'    { "{0} (preference {1})" -f $ap['mailExchange'], $ap['preference'] }
            'Txt'   { $ap['text'] }
            'CName' { $ap['canonicalName'] }
            'Srv'   { "{0}:{1} (priority {2}, weight {3})" -f $ap['nameTarget'], $ap['port'], $ap['priority'], $ap['weight'] }
            default { ($ap.Values -join ' ') }
        }

        [pscustomobject]@{
            Dominio            = $d.Id
            Verificato         = $d.IsVerified
            Predefinito        = $d.IsDefault
            DominioIniziale    = $d.IsInitial
            Autenticazione     = $d.AuthenticationType      # Managed oppure Federated
            ServiziSupportati  = ($d.SupportedServices -join ', ')
            TipoRecord         = $r.RecordType
            Etichetta          = $r.Label
            Servizio           = $r.SupportedService
            Ttl                = $r.Ttl
            Valore             = $valore
            Obbligatorio       = $r.IsOptional -eq $false
        }
    }

    # Un dominio senza record di servizio deve comunque comparire nell'inventario.
    if (-not $records) {
        [pscustomobject]@{
            Dominio            = $d.Id
            Verificato         = $d.IsVerified
            Predefinito        = $d.IsDefault
            DominioIniziale    = $d.IsInitial
            Autenticazione     = $d.AuthenticationType
            ServiziSupportati  = ($d.SupportedServices -join ', ')
            TipoRecord         = '(nessun record di servizio)'
            Etichetta          = ''
            Servizio           = ''
            Ttl                = ''
            Valore             = ''
            Obbligatorio       = ''
        }
    }
}

$report | Sort-Object Dominio, TipoRecord | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ("Domini: {0} | righe record: {1}" -f (($report.Dominio | Select-Object -Unique).Count), $report.Count)
Write-Host ("Esportato in {0}" -f $OutputCsv)
Write-Host ""
Write-Host "Promemoria: i record DKIM del tenant di destinazione NON sono ricavabili da qui." -ForegroundColor Yellow
Write-Host "Si leggono sul target dopo aver aggiunto e verificato il dominio." -ForegroundColor Yellow
