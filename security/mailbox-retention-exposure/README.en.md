# Mail retention inventory for Microsoft 365

How long this tenant keeps employees' email, who decided it, and which holds have no end date.

[Versione italiana](README.md) · [← All the toolkits](../../README.en.md)

## What it's for

It is aimed at the sysadmin of a small or mid-sized company, or the technician of a managed service provider, who has to answer a question the portal never shows in one place: how long employees' mail stays in the tenant, and under which decision. The script collects four sets of data and puts them side by side — the holds active on mailboxes with their duration, the mailboxes of people who have left the company, the Microsoft Purview retention policies that cover mail, the retention of the audit logs — and ends with the list of items to check.

It changes nothing in the tenant: it runs `Get-*` cmdlets only. What it produces is material for a decision that has to be taken and declared, not a configuration to apply.

## The scripts

| File | What it does | Reads / Writes |
|------|--------------|----------------|
| `get-mailbox-retention-exposure-synsphere.ps1` | Reads user and shared mailboxes and builds four reports. **A)** Litigation holds and in-place holds with their duration: it flags `Unlimited` durations as UNLIMITED, durations above `-GiorniSoglia` (default 1095 days), holds that are not communicated to the user — that is, with both `RetentionComment` and `RetentionUrl` empty — and active retention holds. **B)** Inactive mailboxes, with the soft-delete date and the days elapsed: these are the mailboxes that outlive the removal of the licence because a hold applies to them. **C)** Purview retention policies, with their mail scope, the configured duration and the action at expiry. **D)** Custom audit log retention policies and the distribution of `AuditLogAgeLimit` per mailbox. It closes with a numbered list of items to check, derived from what it found. `-SoloRischi` narrows the section A detail to flagged entries only, `-SaltaConformita` skips Purview, `-EsportaCsv` writes the reports to disk. | **Read-only** against the tenant: no write cmdlet towards Microsoft 365. With `-EsportaCsv` it creates the folder you name and writes up to four CSV files into it |

## Before you run it

- **PowerShell 5.1 or 7+.** The script declares no `#Requires`: the minimum version appears only as prose in the `.NOTES` block, so on an older version it will not stop with a clear message.
- **The `ExchangeOnlineManagement` module**, the only one required. `Connect-IPPSSession`, needed for sections C and D, ships in the same module. Install it beforehand:

  ```powershell
  Install-Module ExchangeOnlineManagement -Scope CurrentUser
  ```

  The script installs nothing by itself: if the module is missing it stops and prints exactly this command.
- **Read-only permissions.** The practical minimum, as stated in the `.NOTES` block: for sections A and B the Exchange role **View-Only Recipients** (included in View-Only Organization Management); for sections C and D read access to retention and audit policies in Microsoft Purview. The Entra ID **Global Reader** role covers both connections. Authentication is interactive (`Connect-ExchangeOnline` and `Connect-IPPSSession` open the browser) and works with MFA; no credential is stored in the code.
- **Section A has no fallback.** If your permissions are not enough for `Get-Mailbox`, the script stops there with an error and produces none of the four sections. Sections B, C and D each have their own `try/catch` instead: if the read fails they are skipped with a warning, which is warning 2 below.
- **The custom audit log retention policies in section D require Microsoft Purview Audit (Premium).** Without that plan the read fails, the script says so on screen and carries on. The per-mailbox `AuditLogAgeLimit` distribution is always computed, because it comes from the mailboxes already read.

## ⚠️ Warnings

1. **The "Durata" column only answers for litigation holds: a mailbox can be kept indefinitely without appearing among the UNLIMITED ones.** The duration is computed only when `LitigationHoldEnabled` is true; in every other case it stays `n/d`. Holds that come from a Purview policy, an eDiscovery case or a retention label are never expanded: they show up only as a number in the `AltriBlocchi` column and as true/false in `EtichetteConserv`. So the summary line "Litigation hold ILLIMITATO: 0" is not proof that nothing in the tenant is held without an end date, and a mailbox with `Durata = n/d` and `AltriBlocchi = 2` means "two active holds whose duration this report does not show". Read those two columns together with section C, and expand the in-place holds by hand before stating a duration. In the same way, the "duration above threshold" counter depends on `-GiorniSoglia`: with the default, a zero means "nothing beyond three years", not "compliant durations". Lower the threshold to the period you have actually declared in your privacy notice.

2. **If the Security & Compliance connection fails, the inventory comes out half done and looks complete.** That connection sits in a `try/catch`: on failure the script prints a yellow "Security & Compliance non disponibile" notice and continues. Section C is not printed at all, of section D only the `AuditLogAgeLimit` distribution survives, and on export the two corresponding CSVs are not created. The same happens by design with `-SaltaConformita`. The consequence is that a result with no retention policies is not a tenant with no retention policies: it is a measurement that was never taken — and precisely the one that says who decided the duration. Before reading any number, check that the line "Security & Compliance: connesso" appeared, and count the exported files.

3. **The scope is narrower than "every mailbox in the tenant".** Section A reads only mailboxes of type `UserMailbox` and `SharedMailbox`: room and equipment mailboxes, group mailboxes and the other types stay out, and archives are not inspected separately. The "Caselle totali" figure is therefore the denominator of that filter, not of the tenant, and the same applies to the `AuditLogAgeLimit` distribution in section D, which is computed over the same mailboxes. A "nothing to report" or a percentage derived from that total refers to a subset: state the scope next to the number, and check the mailboxes left out separately.

4. **The script does not say which tenant it is working on, and reuses whatever session it finds open.** Before connecting it tries `Get-OrganizationConfig`: if that answers, it prints "sessione già attiva" and moves on, without naming the domain or the organisation. The exported CSV names contain only a date and a time. On a console used for several customers you end up inventorying the tenant whose session happened to be open, and the resulting files cannot be told apart afterwards. Check the session before you run, and export into a folder named after the customer:

```powershell
Get-ConnectionInformation | Format-List Organization, UserPrincipalName
```

5. **With `-EsportaCsv`, named data about employees and former employees ends up on disk in clear text.** The four CSVs hold the address and display name of every mailbox read, who enabled the litigation hold and on what date, whether the user was informed, and the audit settings mailbox by mailbox; and the inactive-mailboxes file is, by definition, the list of names and addresses of the people who have left the company, with the date. `-SoloRischi` does not reduce the export: it filters the table on screen, while the CSV still contains every mailbox read. Export to a controlled path outside the clone, treat it like the rest of your HR documentation, and delete it once the check is over. The root `.gitignore` excludes `*.csv`, but it does not cover a file renamed with another extension, nor a `git add -f`, nor the copies you made elsewhere.

6. **With `-EsportaCsv` the script creates the whole folder tree you name without asking, and two runs in the same minute overwrite each other.** The path is created with `New-Item -Force`: a typo does not produce a message, it produces a folder. File names contain the date **and the time to the minute**, so two runs on the same day do not overwrite each other — two runs in the same minute do, with no confirmation. The script's help states in capitals "QUESTO SCRIPT NON MODIFICA NULLA" (this script changes nothing): true for the tenant, where it only runs `Get-*` cmdlets, not for the local filesystem. Pass a path that already exists, and check it first.

## Where the output goes

**Without `-EsportaCsv` nothing is written**: everything stays on screen, and the console is the only record of the check. If you need to keep it, start `Start-Transcript` before running — the root `.gitignore` excludes `transcript*.txt`.

With `-EsportaCsv <folder>` up to four files are created, in UTF-8 and without the type header:

```
blocchi-caselle-<yyyymmdd-hhmm>.csv
caselle-inattive-<yyyymmdd-hhmm>.csv
criteri-conservazione-<yyyymmdd-hhmm>.csv
policy-audit-<yyyymmdd-hhmm>.csv
```

Two things to know about that folder. First: **if the path is relative, the files are born wherever the prompt is**, so running the script from a clone of the repository puts the CSV inside the clone; do not commit it (the `.gitignore` excludes it, but check before a `git add`). Second: **a missing file is not an error**. Each report is written only if it has at least one row, and the others are listed as "Saltato (nessun dato)" — but a missing `criteri-conservazione` or `policy-audit` may also mean that sections C and D never ran, which is warning 2.

The content of these files is sensitive for the reason given in warning 5: it is personal data about identified workers, including people who no longer work for the company.

## Examples

```powershell
# Full inventory, every section
.\get-mailbox-retention-exposure-synsphere.ps1

# Flagged entries only: this is the mode for the periodic check
.\get-mailbox-retention-exposure-synsphere.ps1 -SoloRischi

# Full inventory with the four CSVs exported
.\get-mailbox-retention-exposure-synsphere.ps1 -EsportaCsv "C:\Report"

# Sections A and B only, no Purview connection, threshold lowered to two years
.\get-mailbox-retention-exposure-synsphere.ps1 -SaltaConformita -GiorniSoglia 730
```

## More

How to read the results, and the legal references behind them, are in the article the script itself points to: [Conservazione delle email dei dipendenti, i limiti di Microsoft 365 nelle PMI](https://synsphere.it/notizie/conservazione-email-dipendenti-limiti-microsoft-365-pmi) (in Italian).

The same content is available as a ZIP from [synsphere.it/download/script-powershell-conservazione-email-microsoft-365](https://synsphere.it/download/script-powershell-conservazione-email-microsoft-365/). If you need a hand: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
