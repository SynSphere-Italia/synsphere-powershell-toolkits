#Requires -Modules Az.Accounts, Az.Dns
<#
.SYNOPSIS
    Export delle zone DNS pubbliche e dei relativi record.
.DESCRIPTION
    Elenca ogni zona DNS pubblica e tutti i suoi record (A, CNAME, MX, TXT, NS…) con TTL e
    valori: la documentazione DNS completa, utile per audit e migrazioni. Sola lettura.
.PARAMETER OutputCsv
    Percorso CSV. Default: .\Az-DnsRecords-<data>.csv
.EXAMPLE
    .\09-Export-AzDnsRecords.ps1
.NOTES
    SynSphere Italia — https://synsphere.it · Fornito "as is".
    Per le zone DNS private usa Az.PrivateDns. Permessi: ruolo Reader. Prima: Connect-AzAccount
#>
[CmdletBinding()]
param([string]$OutputCsv = (".\Az-DnsRecords-{0}.csv" -f (Get-Date -Format 'yyyyMMdd')))
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$report = [System.Collections.Generic.List[object]]::new()
foreach ($zone in Get-AzDnsZone) {
    foreach ($rs in Get-AzDnsRecordSet -ZoneName $zone.Name -ResourceGroupName $zone.ResourceGroupName) {
        $valori = switch ($rs.RecordType) {
            'A'     { ($rs.Records.Ipv4Address) -join ', ' }
            'AAAA'  { ($rs.Records.Ipv6Address) -join ', ' }
            'CNAME' { ($rs.Records.Cname) -join ', ' }
            'MX'    { ($rs.Records | ForEach-Object { "$($_.Preference) $($_.Exchange)" }) -join ', ' }
            'NS'    { ($rs.Records.Nsdname) -join ', ' }
            'TXT'   { ($rs.Records.Value) -join ' | ' }
            default { ($rs.Records | ConvertTo-Json -Compress) }
        }
        $report.Add([pscustomobject]@{
            Zona = $zone.Name; Record = $rs.Name; Tipo = $rs.RecordType; TTL = $rs.Ttl; Valori = $valori
        })
    }
}
$report | Sort-Object Zona, Tipo, Record | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host ("{0} record DNS → {1}" -f $report.Count, $OutputCsv) -ForegroundColor Green
