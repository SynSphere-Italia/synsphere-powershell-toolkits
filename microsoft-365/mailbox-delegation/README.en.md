# Microsoft 365 mailbox delegation

Grant or revoke the four Exchange Online mailbox delegations from the command line, repeatably and with a log.

[Versione italiana](README.md) · [← All toolkits](../../README.en.md)

## What it's for

This is for the system administrator of a small or mid-sized company, or the engineer at an MSP, who has to set up a mailbox delegation on a Microsoft 365 tenant, or take it apart during offboarding, without going through the portal. The starting scenario is the assistant (or the front office) who handles a manager's mail: two presets cover it, and for anything else the four permissions are exposed one by one.

The four permissions, as the script describes them:

- **FullAccess** — the delegate opens, reads and manages the mailbox. On its own it does **not** allow sending.
- **SendAs** — the delegate sends *as* the manager: the recipient sees only the manager.
- **SendOnBehalf** — the delegate sends *on behalf of* the manager: who actually wrote stays visible.
- **InboxEditor** — a folder-only permission (the Inbox, for instance), with no access to the rest of the mailbox.

The two presets: `-Preset Assistente` = FullAccess + SendOnBehalf; `-Preset AssistenteComeMe` = FullAccess + SendAs. To read **and** send you need FullAccess together with either SendAs or SendOnBehalf: full access alone is not enough to send.

## The scripts

| File | What it does | Reads / Writes |
|------|--------------|----------------|
| `Set-MailboxDelegation.ps1` | Grants or revokes the four delegation permissions on a mailbox. Connects to Exchange Online, checks that both the mailbox and the delegate exist, applies only what is missing, and prints the state of the three main permissions at the end. With `-Remove` it revokes instead of granting (offboarding). Supports `-WhatIf` and `-Confirm`, and writes a timestamped log. | **WRITES** — mailbox permissions and a log file |
| `Esempi.ps1` | Seven ready-made invocations to adapt: assistant preset, transparent sending, custom permissions, folder only, simulation, offboarding, bulk delegation from a CSV. Every line is commented out, so running the file as shipped does nothing. | Read-only as shipped; the lines you uncomment **WRITE**, because they call the main script |

## Before you run them

- **PowerShell 5.1 or 7.** That is what the `.NOTES` block states; neither script carries a `#Requires` directive, so nothing stops them from running on a different version.
- **The ExchangeOnlineManagement module**, the only one required. Install it by hand first, for the reason given in warning 6:

  ```powershell
  Install-Module ExchangeOnlineManagement -Scope CurrentUser
  ```

- **Permissions: the Exchange RBAC role group `Recipient Management` is enough.** It covers every cmdlet actually used: `Add-MailboxPermission` / `Remove-MailboxPermission`, `Add-RecipientPermission` / `Remove-RecipientPermission`, `Set-Mailbox -GrantSendOnBehalfTo`, `Add-MailboxFolderPermission` / `Set-MailboxFolderPermission` / `Remove-MailboxFolderPermission`, and the `Get-*` cmdlets of the final check. The Exchange Administrator role works but is broader than needed; where PIM is available, activate the role only for as long as the job takes.
- **Nothing else is needed**: no Microsoft Graph scope, no Entra ID role, no app registration, no certificate. Authentication is interactive through `Connect-ExchangeOnline`; `-AdminUpn` tells it which account to use. No credential is stored in the code.

## ⚠️ Warnings

1. **`SendOnBehalf` can be skipped silently, in both directions.** The check that avoids re-applying an existing delegation compares only the local part of the address, as a substring, against the entries of `GrantSendOnBehalfTo` (which Exchange returns as a canonical name built from the display name, not as an SMTP address). When granting: with `-Delegate anna@contoso.it` and an existing entry `Gianna Verdi`, "anna" is a substring of "Gianna", so the script logs "SendOnBehalf: already present, skipping" and **does not grant** the delegation you asked for. When revoking, which is the offboarding case: with `-Delegate s.rossi@contoso.it` and the entry `Stefano Rossi`, "s.rossi" does not match, so the script logs "SendOnBehalf: not present, nothing to remove" and **does not revoke** a permission that is there, leaving the departing assistant able to keep sending on behalf. Neither case raises an error, and the final check does not save you: it prints `GrantSendOnBehalfTo`, which looks populated because it holds the *other* delegates. Check by hand, looking for your delegate's own line:

```powershell
Get-Mailbox -Identity direttore@contoso.it | Select-Object -ExpandProperty GrantSendOnBehalfTo
```

2. **The example labelled "read-only" grants full access.** In `Esempi.ps1`, example 3 is titled "Custom permissions (read-only, no sending)" but passes `-Permission FullAccess`. FullAccess is not read-only: it allows opening, reading, deleting, moving and creating items in the mailbox, and the only thing it leaves out is sending. Anyone who copies that line for an intern hands them control of the mailbox. A genuinely read-only delegation would need a folder permission with the Reviewer right, which this kit does not expose: `-Permission InboxEditor` grants **Editor**, not Reviewer.

3. **`-Remove` revokes immediately and asks nothing.** `-WhatIf` and `-Confirm` really are supported, but `ConfirmImpact` is set to `Medium` while PowerShell's default `$ConfirmPreference` is `High`: no prompt appears unless you pass `-Confirm` explicitly. `-Permission FullAccess,SendAs,SendOnBehalf -Remove` strips all three delegations at once without a question. Run the same line with `-WhatIf` first: the simulation is trustworthy, every writing call sits inside `ShouldProcess`.

4. **On the folder permission the log claims "OK" even when it removed nothing.** In the `-Remove` branch of `InboxEditor` the error from `Remove-MailboxFolderPermission` is suppressed with `-ErrorAction SilentlyContinue`, and the log line "folder permission removed" is written regardless: if the permission was not there, if the folder does not exist, or if the name is wrong, you still read a success. The most common cause is the name itself: the default is `Posta in arrivo`, which does not exist on an English-language tenant, so on an EN tenant the folder permission is neither granted nor revoked and no error says so. Pass `-Folder` in the tenant's own language (`-Folder 'Inbox'`) and verify the result with `Get-MailboxFolderPermission -Identity 'direttore@contoso.it:\Inbox'`.

5. **The bulk CSV example runs with no simulation and no safety net.** Example 7 in `Esempi.ps1` loops over `Import-Csv .\deleghe.csv` and applies the `Assistente` preset — FullAccess + SendOnBehalf — to every row: no `-WhatIf`, no `try/catch`, no column validation, no final summary. A CSV with the wrong column, one row too many or a mistyped address grants full access to mailboxes you did not intend, and the loop keeps going. Run it twice: first with `-WhatIf` added to the inner call, reading every pair that would be touched, then for real.

6. **If the module is missing, the script installs it from the PowerShell Gallery without asking.** On the first connection it runs `Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber`: `-Force` suppresses the untrusted-repository prompt (PSGallery is Untrusted by default) and `-AllowClobber` allows overwriting command names already exposed by other modules on your workstation. Install the module by hand first, with the command in the previous section, and the script installs nothing.

## Where the output goes

This kit exports no CSV. The only file it writes is a text log, and four things are worth knowing about it.

- **It is created where the prompt is, not next to the script.** The default path is the current directory plus `Set-MailboxDelegation.log`. `Esempi.ps1` suggests opening PowerShell as administrator, and an elevated console starts in `C:\Windows\System32`, so the log lands there. If you cloned the repository and run from the clone, the log is created **inside the clone**: the root `.gitignore` excludes `*.log`, but check before you commit rather than trusting it. Pass `-LogPath` with an explicit path and the question does not arise.
- **The name is fixed and carries no date**: later runs **append** to the same file instead of overwriting it. The log grows and mixes different jobs on different mailboxes; if you want one file per job, you have to pass `-LogPath`.
- **"Log saved to: …" is printed either way.** The write uses `-ErrorAction SilentlyContinue`: if the path is not writable the error stays invisible, and at the end of the run you read a save confirmation for a file that does not exist. Check that the file is really there.
- **The log contains personal data.** It holds the mailbox address, the delegate's address and, in the final state, the full `GrantSendOnBehalfTo` list — that is, the other people who hold the delegation on that mailbox too. Treat it as a tenant document, not as scrap.

## Examples

```powershell
# Classic assistant scenario: full access + send on behalf
.\Set-MailboxDelegation.ps1 -Mailbox direttore@contoso.it -Delegate segreteria@contoso.it -Preset Assistente

# Full access + send as, with automapping off
.\Set-MailboxDelegation.ps1 -Mailbox ceo@contoso.it -Delegate ufficio@contoso.it -Preset AssistenteComeMe -AutoMapping $false

# Simulate granting the Inbox folder permission only
.\Set-MailboxDelegation.ps1 -Mailbox direttore@contoso.it -Delegate stage@contoso.it -Permission InboxEditor -WhatIf

# Offboarding: revoke the permissions. Try it with -WhatIf first, see warning 3
.\Set-MailboxDelegation.ps1 -Mailbox direttore@contoso.it -Delegate segreteria@contoso.it -Permission SendAs,FullAccess -Remove
```

## More

The same content is available as a ZIP from [synsphere.it/download/script-powershell-delega-cassetta-microsoft-365](https://synsphere.it/download/script-powershell-delega-cassetta-microsoft-365/); the step-by-step guide to the scenario is [here](https://synsphere.it/notizie/delegare-cassetta-mail-microsoft-365-assistente-pmi), in Italian. If you need a hand: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licence: see [LICENSE](../../LICENSE) in the repository root.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview and Defender are trademarks of the Microsoft group of companies. SynSphere Italia is not affiliated with or endorsed by Microsoft.
