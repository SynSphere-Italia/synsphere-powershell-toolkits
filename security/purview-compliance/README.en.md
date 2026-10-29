# Microsoft Purview Compliance Toolkit

Ten read-only PowerShell scripts that separate the Purview configuration present in the portal from the configuration that is actually protecting something, and produce the evidence as CSV.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

In the Microsoft Purview portal, a measure that is configured and a measure that is actually protecting look the same: a row in a list. These scripts read the existing configuration and tell the two apart across four areas — retention, sensitivity labels, data loss prevention, and the unified audit log — exporting one UTF-8 CSV each.

They are written for Microsoft 365 administrators and for consultants working with small and medium businesses who have to hand an auditor not the list of configured policies, but a measurement of which ones act. None of the ten adds or changes configuration in the tenant.

## The scripts

| File | What it does | Reads / Writes |
| --- | --- | --- |
| `01-Get-RetentionPolicyScope.ps1` | Retention policies with the locations they are actually distributed to (Exchange, SharePoint, OneDrive, modern groups, Teams chats and channels) and their distribution status. It always uses `-DistributionDetail`, without which Microsoft documentation states that the status and the `*Location` properties are inaccurate. | Read-only |
| `02-Get-RetentionLabelsAndRules.ps1` | Retention labels and the rules attached to them: how long content is kept, which date the count starts from, what happens at the end of the period, and whether the label is a record label. | Read-only |
| `03-Get-SensitivityLabelsAndPolicies.ps1` | Sensitivity labels compared against the publishing policies: it flags the ones that exist but are not included in any policy, and therefore never reach a single user. | Read-only |
| `04-Get-DlpPolicies.ps1` | DLP policies with status, operating mode and configured locations. It does not use `-DistributionDetail`: for DLP, Microsoft documentation states that `DistributionResults` is unreliable. | Read-only |
| `05-Get-DlpRulesDetail.ps1` | For each DLP rule: the sensitive information types it calls on with their minimum count and confidence, the configured actions (block, notify, user override) and the severity assigned to the incident. | Read-only |
| `06-Get-DlpPoliciesInTestMode.ps1` | Isolates the DLP policies that are not protecting: those in test mode and those disabled, with the number of days since they were last changed. | Read-only |
| `07-Get-UnifiedAuditLogStatus.ps1` | Status of unified audit log ingestion, read from Exchange Online; it also attempts the audit log retention policies and, if the cmdlet is unavailable, says so instead of inferring that none exist. | Read-only |
| `08-Get-CustomSensitiveInfoTypes.ps1` | Sensitive information types grouped by publisher, stating which ones are called on by at least one DLP rule. | Read-only |
| `09-Get-ComplianceSearchInventory.ps1` | Inventory of the compliance (eDiscovery) searches in the tenant: status, author, date, scope searched and query. It does not start, change or export any search. | Read-only |
| `10-Get-PurviewComplianceSummary.ps1` | A dashboard of the four areas on one screen. Each section is independent: if it cannot be read, it says so and the others carry on. It opens no connections of its own. | Read-only |

The only thing written is the CSV on disk: no script changes the tenant configuration.

If you are starting from scratch: `10` for the overall picture, then `06` to see what was left in simulation, then `07` (if the audit log is off, that comes before everything else), then `01` for the real scope of retention, and `03` with `08` to see whether the classification work ever reached users.

## Before you run them

- **PowerShell 5.1 or PowerShell 7.** No script pins the version with `#Requires -Version`.
- **ExchangeOnlineManagement module v3.2.0 or later**, which provides both `Connect-IPPSSession` and `Connect-ExchangeOnline`:

  ```powershell
  Install-Module ExchangeOnlineManagement -MinimumVersion 3.2.0
  ```

  The `#Requires` line at the top of each script checks that the module is present, not its version: with an older module the error does not come at startup but at the first missing cmdlet.
- **Two connection contexts, and they are not interchangeable.**
  - `Connect-IPPSSession` (Security & Compliance) → `01`, `02`, `03`, `04`, `05`, `06`, `08`, `09`
  - `Connect-ExchangeOnline` → `07`
  - `10` reads from both but opens neither: open them yourself before running it, otherwise the sections you have not connected will come back as unavailable.
- **Permissions.** A read-only role is enough for the Purview reads, typically View-Only Configuration or View-Only Retention Management, or Global Reader. `07` and the audit section of `10` need a role that allows `Get-AdminAuditLogConfig`, typically View-Only Organization Configuration or Global Reader.
- **Licence.** The audit log retention policies that `07` attempts to read (`Get-UnifiedAuditLogRetentionPolicy`) require the compliance context and an Audit Premium licence.
- No Microsoft Graph scope and no Azure RBAC role: the toolkit uses only cmdlets from the ExchangeOnlineManagement module.

## ⚠️ Warnings

1. **A property that cannot be read is counted as "in production".** In the dashboard (`10`) and in `06`, policy status is tested in the negative (`-ne $false`): if the `Enabled` field is unreadable — partial permissions, a different module version — the policy ends up among those that protect. `01` does the opposite (`-eq $true`) and the same policy is not counted, so the two scripts can give numbers that disagree. For a compliance tool this is the dangerous direction of error, because it declares protected what was never measured. Always read the raw `Modalita` and `Abilitata` columns in the CSV, not just the counts on screen: an empty cell there is not a "no".

2. **The CSV from `09` contains personal data.** The `Query` column exports the eDiscovery search query (`ContentMatchQuery`) in clear text, and that query typically contains the names of individuals and legal investigation terms, in a file written to the current directory. It is the only output in the toolkit that can contain personal data. Give it a dedicated directory with `-OutputCsv`, treat it as a confidential document, and delete it once you no longer need it.

3. **The audit log status is false if read from the wrong context.** The `UnifiedAuditLogIngestionEnabled` property, when read in Security & Compliance PowerShell, does not raise an error: it always returns `False`, and Microsoft documentation states as much. That is why `07` connects to Exchange Online. The audit section of `10`, on the other hand, reads whichever session it finds open: if you only connected `Connect-IPPSSession`, the dashboard reports "audit log not active" on a tenant where the log is running perfectly well. When in doubt, run `07` in a fresh session with only the Exchange Online connection open.

4. **In `05`, an empty `ModalitaPolicy` does not mean "in production".** The script links each rule to its policy by name; when `ParentPolicyName` is not populated, a GUID is left in its place, the lookup finds nothing, and the column stays empty with no error at all. That is precisely the column the script exists for — telling you whether the rule lives in a policy still in simulation — and an empty cell reads as "nothing wrong here". Wherever `ModalitaPolicy` is empty, check that policy with `04` or `06`.

5. **A section or a column marked "non disponibile" is not a zero.** The dashboard (`10`) degrades the four areas one at a time: when an area cannot be read it writes "non disponibile" in the `Valore` column and the others carry on. That is the intended behaviour, but it means a dashboard that looks clean may be a dashboard that measured one area out of four. The same applies to the audit log retention policies in `07` without an Audit Premium licence. Before you hand over a CSV as evidence, check that every area carries a number and not that wording.

6. **On their first read, the scripts may raise a sign-in prompt.** Each script attempts its first cmdlet and, if that fails, reads the failure as "not connected" and calls `Connect-IPPSSession` (or `Connect-ExchangeOnline`). The `catch` does not tell causes apart: insufficient permissions, throttling or a service error will equally trigger a sign-in prompt you were not expecting, after which the real error resurfaces disguised as a connection problem. Connect by hand before running them, and if a prompt appears unexpectedly, do not assume the session is the cause.

## Where the output goes

Every script exports a UTF-8 CSV, and the default for `-OutputCsv` is a relative path of the form `.\M365-<area>-<yyyymmdd>.csv`. Two consequences to keep in mind:

- **The file is born wherever the prompt is**, not next to the script. If you cloned the repository and run from there, the CSV lands inside the clone: do not commit it. The `.gitignore` in the root excludes it, but do not trust the filter — check `git status` before a commit.
- **A second run on the same day overwrites the first one without asking.** The default name contains only the date, not the time, and none of the exports uses `-NoClobber`, `-Append` or a confirmation. In an audit context that means losing the evidence you have just collected, including the CSV with the personal data from `09`. Pass an explicit `-OutputCsv`, with an absolute path, on every run.

Two details about `07`: the second file holding the audit log retention detail is built from the name of the first (`...-RetentionPolicies.csv`) and cannot be set separately; and if you pass an `-OutputCsv` that does not end in `.csv`, the main file is left with no extension.

Default names, in script order: `M365-RetentionPolicyScope-<date>.csv`, `M365-RetentionLabels-<date>.csv`, `M365-SensitivityLabels-<date>.csv`, `M365-DlpPolicies-<date>.csv`, `M365-DlpRules-<date>.csv`, `M365-DlpTestMode-<date>.csv`, `M365-AuditLogStatus-<date>.csv` (plus `M365-AuditLogStatus-<date>-RetentionPolicies.csv`), `M365-SensitiveInfoTypes-<date>.csv`, `M365-ComplianceSearches-<date>.csv`, `M365-PurviewSummary-<date>.csv`.

## Examples

```powershell
# Retention, labels and DLP: Security & Compliance context
Connect-IPPSSession
.\06-Get-DlpPoliciesInTestMode.ps1 -SoloProblemi
.\01-Get-RetentionPolicyScope.ps1
.\03-Get-SensitivityLabelsAndPolicies.ps1
.\08-Get-CustomSensitiveInfoTypes.ps1 -SoloNonMicrosoft

# Unified audit log: must be read from Exchange Online
Connect-ExchangeOnline
.\07-Get-UnifiedAuditLogStatus.ps1

# Dashboard: it opens no connections, so open both first
Connect-IPPSSession
Connect-ExchangeOnline
.\10-Get-PurviewComplianceSummary.ps1

# One file per run, in a dedicated directory outside the clone
.\09-Get-ComplianceSearchInventory.ps1 -OutputCsv C:\Evidenze\eDiscovery-20261029.csv
```

## More

The same content is available as a ZIP from [synsphere.it/download/toolkit-powershell-purview-compliance](https://synsphere.it/download/toolkit-powershell-purview-compliance/).

If you need help moving a Purview configuration from "present" to "active", with the evidence ready for an audit: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
