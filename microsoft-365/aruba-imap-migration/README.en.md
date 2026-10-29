# Aruba to Microsoft 365 IMAP migration

Create, from the command line, the IMAP migration endpoint and the migration batch that move mail from Aruba-hosted mailboxes into Exchange Online, starting from a CSV file.

[Versione italiana](README.md) · [← All the toolkits](../../README.en.md)

## What it's for

It is aimed at the sysadmin of a small or mid-sized company, or at an MSP technician, who has to move the mailboxes of a domain hosted at Aruba into a Microsoft 365 tenant without repeating the IMAP migration steps by hand in the portal. The script runs the four operations it takes in sequence — prerequisite checks, connection to Exchange Online, creation (or reuse) of the IMAP endpoint, creation of the batch from the CSV — and then prints the commands to follow progress, complete the batch and remove it.

One limit to know before you start, because it decides how you plan the job: an IMAP migration moves **mail only**, that is folders and messages. Contacts, calendars, tasks and rules stay where they are and must be handled separately.

## The scripts

| File | What it does | Reads / Writes |
|------|--------------|----------------|
| `migrazione-aruba-microsoft-365-synsphere.ps1` | Checks that the `ExchangeOnlineManagement` module is present and that the CSV has the three columns Microsoft requires, connects to Exchange Online with modern authentication (reusing the session if one is already open), creates the IMAP migration endpoint to `imaps.aruba.it:993` over SSL — or reuses the existing one if an endpoint with the same name is already there — and creates the migration batch by passing the CSV to `New-MigrationBatch`. With `-AutoStart` the batch starts immediately; without it, the batch is created `Stopped`. At the end it prints the monitoring and batch clean-up commands. Supports `-WhatIf` and `-Confirm`. | **WRITES** — creates a migration endpoint and a migration batch in the tenant; with `-AutoStart` it also starts copying mail. No files on disk |

## Before you run it

- **PowerShell 5.1 or later.** The first line declares `#Requires -Version 5.1`, so on an earlier version the script will not run at all.
- **The `ExchangeOnlineManagement` module**, the only one required. Install it beforehand, by hand:

  ```powershell
  Install-Module ExchangeOnlineManagement -Scope CurrentUser
  ```

  The script installs nothing by itself: if the module is missing it stops and prints exactly this command.
- **Permissions: the Exchange Administrator role (the `Organization Management` role group) is enough.** It covers `New-MigrationEndpoint` and `New-MigrationBatch`, which is everything the script creates. The script's `.NOTES` block asks for "Exchange/Global": Global Administrator is not needed, see warning 5. Authentication is interactive through `Connect-ExchangeOnline` (a browser window opens) and works with MFA; no credential is stored in the code.
- **On the tenant side, before you launch**: the **target** mailboxes must already exist and have a licence that includes Exchange Online, and the custom domain must already be added and verified. The batch does not create users.
- **On the Aruba side**: valid credentials for every source mailbox, and the right IMAP host. The `imaps.aruba.it` default does not hold for every setup — some use dedicated hosts, which you should check in the Aruba control panel for the domain and pass with `-ArubaImapServer`.

## ⚠️ Warnings

1. **The working file of this procedure is a list of clear-text passwords.** The CSV Microsoft requires for an IMAP migration has the header `EmailAddress,UserName,Password`, and the third column holds the password of the source Aruba mailbox: one row per mailbox, in the clear. The script embeds no credentials — it reads the file you prepare and hands it to `New-MigrationBatch` — but for the whole duration of the migration that file sits on your disk and is worth, on its own, access to all the mail in the domain. Keep it outside the cloned repository folder and on an encrypted disk, and delete it once the migration is over. The root `.gitignore` excludes `*.csv`, but do not rely on it: it does not cover a file renamed with another extension, nor a `git add -f`, nor the copies you made elsewhere.

2. **With `-AutoStart` the entire CSV starts at once, with no cap and no per-mailbox confirmation.** With that switch the batch is created already running: nothing in the code counts the rows of the CSV or imposes a ceiling, so a 300-mailbox file starts in full. The `.NOTES` block warns about Aruba's IMAP throttling and recommends waves of 20-50 mailboxes, but that is advice in the help, not a control in the script. The first time, run **without** `-AutoStart`: the batch is created `Stopped`, you inspect it with `Get-MigrationBatch` and start it by hand with `Start-MigrationBatch` when you are ready. Split the CSV into waves rather than trusting a single file. The dry run is trustworthy: endpoint and batch creation sit inside `ShouldProcess`, so `-WhatIf` creates nothing.

3. **If an endpoint with the same name exists, it is reused without checking where it points.** The script looks the endpoint up by name (default `Endpoint-Aruba-IMAP`) and, if it finds one, prints "Endpoint IMAP già esistente: lo riuso" without comparing server, port and security type against the values you passed. On a tenant where that endpoint was left over from an earlier migration, `-ArubaImapServer` and `-ArubaImapPort` have no effect at all and the batch goes off to query the old server: the run succeeds and nothing tells you. Check where it points first, or pass a distinct `-EndpointName` for each migration:

```powershell
Get-MigrationEndpoint -Identity 'Endpoint-Aruba-IMAP' | Format-List Identity,RemoteServer,Port,Security
```

4. **A "Completed" batch does not mean the mailbox has been migrated.** An IMAP migration copies folders and messages and nothing else: contacts, calendars, tasks and rules are not included, as the script's own help states. If you read the batch status as "migration done" and move the MX record, your users find their mail and no calendar. Plan that part of the job separately (export to `.pst` from Outlook and import, or recreate on the client) and treat it as a cutover step, not as a finishing touch.

5. **The help asks for a higher role than the job needs.** The `.NOTES` block prescribes an "Exchange/Global administrator account with MFA". For the two cmdlets the script actually uses, Exchange Administrator is enough: Global Administrator is not necessary, and following the help literally means doing with the most privileged role in the tenant an operation that does not require it. Use Exchange Administrator and, where PIM is available, activate it only for the duration of the job.

## Where the output goes

**This script exports nothing**: no CSV, no log, no report. Everything it produces is printed to the console, which makes the console the only record of the job — if you need one, open it with `Start-Transcript` before launching (the root `.gitignore` excludes `transcript*.txt`).

The only file involved is the **input** CSV, and warning 1 applies to it: it lives wherever you put it, it holds clear-text passwords, and it must never be committed.

What the script leaves behind is in the tenant, not on disk, and has to be cleaned up by hand:

- **The migration endpoint stays** after the migration, which is exactly why later runs reuse it (warning 3).
- **Batches accumulate.** The default name contains the date **and the time** (`Migrazione-Aruba-<yyyymmdd-hhmm>`), so two runs on the same day do not overwrite each other: they create two separate batches, both of them in the tenant. You close them with `Complete-MigrationBatch` and then `Remove-MigrationBatch`, the commands the script itself prints at the end.
- **With `-NotificationEmails`, Microsoft delivers the end-of-migration report** to the addresses you list: that is mail leaving your control, and it carries the per-mailbox outcome, so pick internal addresses.

## Examples

```powershell
# Dry run: checks prerequisites and parameters, creates nothing
.\migrazione-aruba-microsoft-365-synsphere.ps1 -CsvPath .\caselle-aruba.csv `
    -TargetDeliveryDomain "contoso.mail.onmicrosoft.com" -WhatIf

# First time: create the batch and do NOT start it (it is created Stopped)
.\migrazione-aruba-microsoft-365-synsphere.ps1 -CsvPath .\caselle-aruba.csv `
    -TargetDeliveryDomain "contoso.mail.onmicrosoft.com" -NotificationEmails "it@contoso.it"

# Create and start the batch right away: read warning 2 first
.\migrazione-aruba-microsoft-365-synsphere.ps1 `
    -CsvPath .\caselle-aruba.csv `
    -TargetDeliveryDomain "contoso.mail.onmicrosoft.com" `
    -NotificationEmails "it@contoso.it" `
    -AutoStart

# Dedicated IMAP host and a distinct endpoint name for this migration
.\migrazione-aruba-microsoft-365-synsphere.ps1 -CsvPath .\ondata-1.csv `
    -TargetDeliveryDomain "contoso.mail.onmicrosoft.com" `
    -ArubaImapServer "imaps.customer-domain.it" -EndpointName "Endpoint-Aruba-contoso"

# Manual start and monitoring (commands printed by the script)
Start-MigrationBatch -Identity 'Migrazione-Aruba-20261029-0930'
Get-MigrationBatch   -Identity 'Migrazione-Aruba-20261029-0930' | Format-List Status,*Count*
```

## More

The same content is available as a ZIP download from [synsphere.it/download/script-powershell-migrazione-aruba-microsoft-365](https://synsphere.it/download/script-powershell-migrazione-aruba-microsoft-365/). If you need help: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
