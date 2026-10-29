# Entra ID app registration credential expiry

Every client secret and certificate in the tenant in a single table, sorted by expiry date, with the already-expired ones at the top.

[Versione italiana](README.md) · [← All the toolkits](../../README.en.md)

## What it's for

It is aimed at the sysadmin of a small or mid-sized company, or at the consultant who looks after several tenants, and it solves a problem that gives no warning: Entra ID app registration credentials expire in silence — no email, no portal notification, no alert. The first sign is an integration that stops working: an SMTP send answering 535, a job that no longer authenticates, a webhook that no longer signs.

The portal shows those dates only if you open each application one by one. The script collects them all into a single list sorted by urgency and, for every client secret, reports the HINT field, that is the first three characters of the value. That is what tells you *which* secret a given application is using, by comparing it with the first three characters of the value configured in your environment file or vault: the full value cannot be retrieved after creation, so that is the only match available.

## The scripts

| File | What it does | Reads / Writes |
|------|--------------|----------------|
| `get-entra-app-credentials-expiry-synsphere.ps1` | Connects to Microsoft Graph asking for the `Application.Read.All` scope, reads every app registration in the tenant with `Get-MgApplication -All` and — only if you pass `-IncludiServicePrincipal` — the service principals (enterprise applications) too. For every client secret and every certificate it works out the days left to expiry, sorts from the most urgent (credentials with no expiry go last) and prints the table with application, description, type, date and HINT, colouring the expired ones and those inside the threshold. It closes with a named summary of the expired credentials and of those expiring within `-GiorniAvviso` (90 days by default). With `-SoloInScadenza` it shows only expired and expiring credentials; with `-EsportaCsv` it saves the full list to a CSV; with `-TenantId` it connects to a tenant other than the user's default one. | **Read-only** — it changes nothing in the tenant. It writes a single file to disk, the CSV, and only if you ask for it with `-EsportaCsv` |

## Before you run it

- **PowerShell 5.1 or 7.** The `.NOTES` block states "PowerShell 5.1+ oppure 7+", but the script has **no** `#Requires` directive: on an older version it will not stop by itself.
- **The `Microsoft.Graph.Applications` module**, the only one required. Install it beforehand, by hand:

  ```powershell
  Install-Module Microsoft.Graph.Applications -Scope CurrentUser
  ```

  The script installs nothing: if the module is missing it prints exactly this command and stops. This submodule is enough — the full `Microsoft.Graph` meta-module is not needed.
- **Permission: `Application.Read.All`**, requested by `Connect-MgGraph` at connection time (interactive consent, works with MFA; no credential is stored in the code). It is the minimum sufficient permission, and the `.NOTES` block explains why: credentials are ordinary properties of the application object and need no dedicated scope.
- **Directory role: Directory Readers, Global Reader, Cloud Application Administrator or Application Administrator.** Consent to the scope alone is not enough — see warning 1.

## ⚠️ Warnings

1. **An empty list, or a green "nessuna credenziale scaduta", can be a permissions problem rather than good news.** The script counts and shows whatever Graph hands back. If the user running it holds none of the roles listed above, consent to the scope is not sufficient: Graph may return only the applications that user owns. If the response comes back **empty** the script at least tells you ("Nessuna credenziale trovata. Verifica di avere i permessi di lettura."); if it comes back **partial** there is no warning at all, and the summary prints a green "no expired credentials" computed only over what it managed to read. Before you close the check, read the "*N* app registration esaminate" line and compare it with the number of app registrations you expect in that tenant: a numerator without its denominator is worth nothing.

2. **By default the scope is narrower than it looks: service principals are not examined.** Without `-IncludiServicePrincipal` the script reads app registrations only, and the help points out that some third-party integrations register their credentials on the service principal (enterprise application) instead of on the app registration. The total and the summary therefore cover only part of the tenant. For a periodic check, always run with `-IncludiServicePrincipal`.

3. **The output contains identifiers of your tenant and the first characters of your secrets.** On screen the script prints the tenant ID and the account you connected with. The CSV contains, for every credential, the application's `AppId`, the credential's `KeyId`, the first three characters of the client secret value (the `Hint` column) and the first eight of the certificate thumbprint. None of these values is in the source file: they are produced at runtime against the tenant you run on. Pasting that output into a public issue or a ticket means publishing your own tenant and application identifiers: anonymise them first, and treat the CSV as a confidential document.

4. **Without `-TenantId` you are working on the user's default tenant, which is not necessarily the one you meant.** If you administer several tenants, this is the easiest way to produce — and hand over — the report of the wrong one. The script prints the "Tenant: …" line right after connecting for exactly this reason: read it before you read the table, or pass `-TenantId` explicitly.

5. **The CSV is overwritten without asking.** The export calls `Export-Csv` without `-NoClobber`: if the file you name in `-EsportaCsv` already exists, it is rewritten and the previous report is gone. The name carries no date — you choose it — so it is easy to keep reusing the same one. If you need to compare a before and an after, use two distinct names.

6. **The Graph session stays open when the script ends.** There is no `Disconnect-MgGraph`: on a shared workstation the authenticated session remains active, and the next run reuses it without asking you anything. Close it with `Disconnect-MgGraph` when you are done, especially before moving to another tenant.

## Where the output goes

Unlike most of the scripts in this collection, there is **no default path** here: without `-EsportaCsv` the script writes nothing to disk and everything stays in the console. The CSV is created only if you pass that parameter, under the name you give it. Two consequences to keep in mind:

- **A relative path resolves where the prompt is, not where the script is.** If you cloned this repository and launch from there, `-EsportaCsv .\credenziali.csv` creates the file **inside the clone**. The root `.gitignore` excludes `*.csv`, but do not rely on it: check with `git status` before you commit. The same applies to folders synced to OneDrive, SharePoint or Dropbox, where no `.gitignore` protects you.
- **A second export under the same name deletes the previous one, without asking** (warning 5). The name does not carry the date automatically: if you want to keep a history, put it there yourself.

What ends up in the file deserves the protection of a confidential document: the names of every registered application, the credential descriptions, `AppId`, `KeyId`, the first three characters of every client secret, the start of the certificate thumbprints and the expiry dates. It is the list of which integrations exist in the tenant and of when each one becomes fragile.

The console output is not saved anywhere. If you need a record of the job, open one with `Start-Transcript` before you launch: the root `.gitignore` excludes `transcript*.txt`.

## Examples

```powershell
# Every credential of every app registration
.\get-entra-app-credentials-expiry-synsphere.ps1

# Only what expires within 60 days, or has expired already
.\get-entra-app-credentials-expiry-synsphere.ps1 -SoloInScadenza -GiorniAvviso 60

# Full report, app registrations and service principals, exported to CSV
.\get-entra-app-credentials-expiry-synsphere.ps1 -IncludiServicePrincipal -EsportaCsv .\credenziali.csv

# Periodic check on a specific tenant, with the CSV outside the clone
.\get-entra-app-credentials-expiry-synsphere.ps1 -TenantId "contoso.onmicrosoft.com" -SoloInScadenza -IncludiServicePrincipal -EsportaCsv C:\Report\credenziali-entra.csv
```

## More

The same content is available as a ZIP download from [synsphere.it/download/script-powershell-scadenze-credenziali-entra-id](https://synsphere.it/download/script-powershell-scadenze-credenziali-entra-id/). If you need help: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
