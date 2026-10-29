<#
    Esempi di invocazione di Set-MailboxDelegation.ps1
    SynSphere Italia — https://synsphere.it

    COME USARLO:
      1. Apri PowerShell come amministratore nella cartella che contiene gli script.
      2. Sostituisci gli indirizzi di esempio (@contoso.it) con quelli reali del tuo tenant.
      3. Togli il commento (#) dalla riga che ti serve, oppure copiala nel terminale.

    Suggerimento: prova SEMPRE prima con -WhatIf per vedere cosa farebbe senza applicare nulla.
#>

# ─────────────────────────────────────────────────────────────────────────────
# 1) Scenario assistente classico — Accesso completo + Invia per conto (tracciabile)
#    Il destinatario vedrà "Assistente per conto di Responsabile".
# ─────────────────────────────────────────────────────────────────────────────
# .\Set-MailboxDelegation.ps1 -Mailbox direttore@contoso.it -Delegate segreteria@contoso.it -Preset Assistente

# ─────────────────────────────────────────────────────────────────────────────
# 2) Invio "trasparente" — Accesso completo + Invia come
#    Il destinatario vedrà SOLO il responsabile. AutoMapping disattivato.
# ─────────────────────────────────────────────────────────────────────────────
# .\Set-MailboxDelegation.ps1 -Mailbox ceo@contoso.it -Delegate ufficio@contoso.it -Preset AssistenteComeMe -AutoMapping $false

# ─────────────────────────────────────────────────────────────────────────────
# 3) Permessi su misura (solo lettura, niente invio)
# ─────────────────────────────────────────────────────────────────────────────
# .\Set-MailboxDelegation.ps1 -Mailbox dir@contoso.it -Delegate stagista@contoso.it -Permission FullAccess

# ─────────────────────────────────────────────────────────────────────────────
# 4) Solo una cartella (es. Posta in arrivo) senza accesso al resto della casella
# ─────────────────────────────────────────────────────────────────────────────
# .\Set-MailboxDelegation.ps1 -Mailbox dir@contoso.it -Delegate seg@contoso.it -Permission InboxEditor -Folder 'Posta in arrivo'

# ─────────────────────────────────────────────────────────────────────────────
# 5) Simulazione (consigliata prima di applicare in produzione)
# ─────────────────────────────────────────────────────────────────────────────
# .\Set-MailboxDelegation.ps1 -Mailbox dir@contoso.it -Delegate seg@contoso.it -Preset Assistente -WhatIf

# ─────────────────────────────────────────────────────────────────────────────
# 6) OFFBOARDING — revoca di tutti i permessi quando l'assistente cambia ruolo
# ─────────────────────────────────────────────────────────────────────────────
# .\Set-MailboxDelegation.ps1 -Mailbox dir@contoso.it -Delegate seg@contoso.it -Permission FullAccess,SendAs,SendOnBehalf -Remove

# ─────────────────────────────────────────────────────────────────────────────
# 7) Delega in MASSA da CSV — più coppie responsabile/assistente in un colpo solo
#    Prepara un CSV con intestazioni:  Mailbox,Delegate
#    Esempio righe:                    direttore@contoso.it,segreteria@contoso.it
# ─────────────────────────────────────────────────────────────────────────────
# Import-Csv .\deleghe.csv | ForEach-Object {
#     .\Set-MailboxDelegation.ps1 -Mailbox $_.Mailbox -Delegate $_.Delegate -Preset Assistente
# }
