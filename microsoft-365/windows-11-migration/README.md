# Migrazione a Windows 11 — toolkit PowerShell

Dieci script per sapere quali PC possono passare a Windows 11, in che ordine muoverli e che cosa mettere al sicuro prima di toccarli.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Il supporto di Windows 10 è finito il 14 ottobre 2025 e chi ha ancora un parco misto deve decidere quali macchine si aggiornano, quali vanno sostituite e in che ordine. Questi script coprono il ciclo intero: idoneità hardware della singola macchina e dell'intera flotta via WinRM, inventario dei Windows 10 e delle applicazioni installate, export delle chiavi di ripristino BitLocker prima dell'intervento, upgrade in-place con precondizioni bloccanti, verifica dopo l'upgrade con i giorni di rollback residui.

Sono pensati per amministratori IT interni e per MSP che devono pianificare le wave di migrazione. Nove script su dieci sono di sola lettura; l'unico che modifica la macchina (09) chiede conferma.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Test-Windows11Readiness.ps1` | Idoneità del PC locale ai requisiti verificabili in locale: TPM 2.0, Secure Boot, firmware UEFI, RAM da almeno 4 GB, disco di sistema da almeno 64 GB con spazio libero sufficiente, CPU a 64 bit con almeno 2 core e 1 GHz. Restituisce un esito PASS/FAIL e l'elenco dei requisiti mancanti. | Sola lettura (nessun file) |
| `02-Get-Windows11ReadinessReport.ps1` | Gli stessi controlli su un elenco di PC via WinRM, con un CSV riepilogativo idoneo / non idoneo e i requisiti mancanti macchina per macchina. Accetta `-ComputerName` oppure un CSV con colonna `ComputerName`. | Sola lettura (+ CSV) |
| `03-Get-TpmStatus.ps1` | Stato dettagliato del TPM: presenza, versione, abilitato, attivato, pronto, produttore. Serve a distinguere "TPM assente" da "TPM presente ma disabilitato nel firmware", caso in cui spesso basta attivare PTT o fTPM. | Sola lettura (+ CSV) |
| `04-Test-SecureBootUEFI.ps1` | Stato di Secure Boot, modalita' del firmware (UEFI o BIOS legacy) e stile di partizione del disco di sistema. Dice se basta attivare Secure Boot o se serve convertire il disco da MBR a GPT. Solo diagnosi: non esegue `mbr2gpt.exe`. | Sola lettura (+ CSV) |
| `05-Get-Windows10Inventory.ps1` | Inventario dei PC, locali o remoti, con edizione, versione, build, data di installazione e ultimo avvio, e marca quali risultano Windows 10. | Sola lettura (+ CSV) |
| `06-Get-UpgradeDiskSpace.ps1` | Spazio totale e libero del disco di sistema contro una soglia (25 GB per default) e, con `-AnalyzeCleanup`, la stima DISM dello spazio recuperabile dai componenti Windows. Nessuna pulizia eseguita. | Sola lettura (nessun file) |
| `07-Export-BitLockerRecoveryKey.ps1` | Esporta in CSV l'identificativo e la chiave numerica di ripristino dei volumi BitLocker protetti. Va fatto prima di toccare firmware, Secure Boot o TPM, perché un cambio di stato del TPM può far chiedere la chiave al riavvio. | Sola lettura (+ CSV **con segreti**) |
| `08-Get-InstalledAppsInventory.ps1` | Snapshot dei software installati, letto dalle chiavi di disinstallazione del registro (64 bit, WOW6432Node e HKCU): nome, versione, editore, data. Serve a confrontare prima e dopo l'upgrade che cosa è rimasto. | Sola lettura (+ CSV) |
| `09-Invoke-Windows11Upgrade.ps1` | Avvia l'upgrade in-place dal `setup.exe` di un supporto Windows 11 (ISO montata, chiavetta o cartella), dopo precondizioni bloccanti su Secure Boot/UEFI, RAM, spazio libero e alimentazione di rete; se richiesto sospende BitLocker per un riavvio. Supporta `-WhatIf`. | **SCRIVE**: aggiorna il sistema e riavvia il PC |
| `10-Test-Windows11PostUpgrade.ps1` | Verifica dopo l'upgrade: se il sistema è davvero Windows 11, versione e build, presenza di `Windows.old` e giorni residui della finestra di rollback (circa 10). | Sola lettura (+ CSV) |

## Prima di eseguirli

- **PowerShell**: Windows PowerShell 5.1 oppure PowerShell 7. Nessuno dei dieci script dichiara un `#Requires`, quindi niente blocca l'esecuzione su una versione diversa: il controllo è a carico tuo.
- **Moduli**: nessuno da installare. Gli script usano solo quello che Windows ha già in dotazione — `CimCmdlets` (`Get-CimInstance`), `SecureBoot` (`Confirm-SecureBootUEFI`), `TrustedPlatformModule` (`Get-Tpm`), `Storage` (`Get-Disk`), `BitLocker` (`Get-BitLockerVolume`, `Suspend-BitLocker`), `Microsoft.PowerShell.Management` e `Microsoft.PowerShell.Utility` — più `dism.exe`, chiamato da 06. Non serve nessun `Install-Module`.
- **Nessun permesso cloud**: nessuno script si collega a Microsoft Graph, a Entra ID o ad Azure. Non servono consensi applicativi, scope Graph o ruoli di directory.
- **Amministratore locale sulla macchina**: serve per il TPM (03), per Secure Boot (01, 02, 04, 09), per BitLocker (07, 09), per `Get-Disk` (04), per la lettura di `HKLM` (05, 08, 10) e per `setup.exe` (09). Manca anche il `#Requires -RunAsAdministrator`: senza elevazione gli script non rifiutano l'esecuzione in modo pulito, danno errori oscuri.
- **Per i report di flotta (02 e 05)**: WinRM attivo sui target (`Enable-PSRemoting`) e diritti amministrativi su ciascun target. Gli script non hanno `-Credential`: usano l'identità di chi li lancia, quindi nessuna credenziale resta nel codice. Il payload eseguito in remoto è di sola lettura, ma la raccolta è seriale, una sessione WinRM per host: su liste lunghe mettiti in conto il tempo.
- **Per l'upgrade (09)**: un supporto Windows 11 raggiungibile e il percorso del suo `setup.exe`.
- **Sistema di partenza**: Windows 10, meglio 22H2, oppure Windows 11.

## ⚠️ Avvertenze

1. **In contesto non interattivo, 09 riavvia il PC senza avvisare nessuno.** Lo script è marcato `ConfirmImpact='High'` e in interattivo ti interroga, ma gli argomenti passati a `setup.exe` includono `/quiet`: lanciato da un RMM o da Intune con `-Confirm:$false` non mostra nessuna interfaccia all'utente collegato, e la macchina si riavvia mentre quella persona sta lavorando. Usa una finestra di manutenzione, avvisa l'utente fuori banda e fai girare prima lo stesso comando con `-WhatIf`, che verifica le precondizioni senza toccare niente.

2. **07 scrive le chiavi di ripristino BitLocker in chiaro nella directory corrente.** Il default di `-OutputCsv` è un percorso relativo, quindi il file nasce dove si trova il prompt: con una console aperta come amministratore, come prescrivono gli script, quella directory è `C:\Windows\System32`. Il CSV non viene cifrato, non riceve ACL più strette, non viene cancellato a valle e nessuno chiede conferma prima di scriverlo. Passa sempre `-OutputCsv` con un percorso tuo, su volume cifrato o rimovibile; cancella il file appena hai finito; e in un parco gestito usa la via giusta, cioè l'escrow delle chiavi in Entra ID o in Active Directory (`BackupToAAD-BitLockerKeyProtector`, oppure `manage-bde -protectors -adbackup`).

3. **Un esito "idoneo" non è il via libera per 09.** Le precondizioni bloccanti di 09 coprono Secure Boot/UEFI, RAM, spazio libero e alimentazione, ma non controllano il TPM 2.0 né il disco di sistema da almeno 64 GB, che sono invece due dei controlli di 01: l'upgrade può quindi partire su una macchina che 01 marca come NON idonea e farsi rifiutare, o annullare, da `setup.exe` dopo il riavvio. In più né 01 né 02 confrontano il modello esatto di CPU con l'elenco di compatibilita' Microsoft, quindi un PC che risulta idoneo può essere respinto per il processore. Esegui sempre 01 (o 02) prima di 09 e, sui modelli di confine, conferma con PC Health Check.

4. **`-SuspendBitLocker` sospende la protezione in attesa di un riavvio che può non arrivare.** L'opzione sospende BitLocker su tutti i volumi protetti per un solo riavvio. Se poi l'upgrade non parte, viene annullato o fallisce prima del reboot, il disco resta senza protezione attiva e nessuno te lo dice. Dopo un `-WhatIf`, dopo un annullamento e dopo un upgrade concluso, verifica con `Get-BitLockerVolume` che `ProtectionStatus` sia tornato `On`; se non lo è, esegui `Resume-BitLocker`.

5. **Due report possono risultare incompleti senza dichiararlo.** In 05 l'oggetto di errore porta una proprieta' in più di quello di successo (`Nota`, con il motivo del fallimento) e `Export-Csv` prende gli header dal primo oggetto della pipeline: se il primo computer risponde, la colonna `Nota` non viene creata e la causa di ogni fallimento scompare dal CSV, dove resta solo `Edizione = ERRORE`. In 08, fra le chiavi di registro lette c'è `HKCU`, che punta all'hive dell'account che esegue lo script: eseguito come amministratore, l'inventario non vede le installazioni per utente dell'utente della postazione, cioè proprio la classe di applicazioni più facile da perdere nell'upgrade. E in 02 come in 05 una macchina irraggiungibile, o su cui ti mancano i diritti, finisce fra gli ERRORE e non fra le "non idonee": se WinRM non è attivo o i diritti non bastano, la riga di riepilogo (`Idonei 0/50`, `PC Windows 10 rilevati: 0/50`) non ti sta dicendo che nessuna macchina è idonea, ti sta dicendo che nessuna ha risposto. Conta le righe ERRORE prima di usare quel totale come denominatore.

6. **06 stampa due comandi distruttivi come suggerimento.** Lo script esegue solo l'analisi in sola lettura (`dism /Online /Cleanup-Image /AnalyzeComponentStore`), poi suggerisce a schermo `dism /Online /Cleanup-Image /StartComponentCleanup` e `cleanmgr /sagerun`. Il primo rimuove in modo permanente i componenti superati e rende non più disinstallabili gli aggiornamenti già installati: non è reversibile, decidilo prima di eseguirlo. Il secondo, così come è stampato, non funziona: `cleanmgr` vuole un indice, quindi prima `cleanmgr /sageset:1` per scegliere che cosa pulire, poi `cleanmgr /sagerun:1`.

## Dove finiscono i file

Sette script su dieci esportano un CSV il cui nome contiene solo la data, in alcuni casi con il nome della macchina: 02, 03, 04, 05, 07, 08 e 10. 01 e 06 non scrivono nulla. 09 scrive i log in `%ProgramData%\SynSphere\Win11Upgrade` e crea quella cartella sulla macchina.

Due conseguenze valgono sempre:

- **Il file nasce dove si trova il prompt.** Il default di `-OutputCsv` è relativo (`.\`), quindi l'output finisce nella directory corrente, qualunque sia. Se hai clonato questo repository e lanci gli script da dentro il clone, i CSV si depositano nel clone: non committarli. Il `.gitignore` esclude `*.csv` e `*.log`, ma non fidarti del `.gitignore` — guarda `git status` prima di aggiungere. Il modo pulito è passare sempre `-OutputCsv` con un percorso tuo.
- **Una seconda esecuzione nello stesso giorno sovrascrive la prima, senza chiedere.** Nel nome c'è la data, non l'ora, e `Export-Csv` sovrascrive. Se ti serve lo storico, rinomina il file o passa un `-OutputCsv` diverso.

Sul contenuto:

- Il CSV di **07 contiene segreti di sicurezza**, le chiavi di ripristino BitLocker in chiaro. Trattalo come una password, non come un report.
- Gli altri CSV contengono nomi macchina, versione del sistema, inventario software per postazione e date di installazione. Appena li correli al dipendente assegnatario diventano dati personali: tienili il tempo che serve alla migrazione e non più a lungo, limita chi può leggerli e cancellali a wave chiusa.
- In 09 il valore di `-LogDir` viene passato a `setup.exe` dentro una lista di argomenti senza virgolette: un percorso con spazi si spezza in due e `/copylogs` riceve un valore troncato, cioè i log non finiscono dove credi. Usa un percorso senza spazi.

## Esempi

```powershell
# Idoneita' della singola macchina
.\01-Test-Windows11Readiness.ps1

# Idoneita' dell'intera flotta
.\02-Get-Windows11ReadinessReport.ps1 -ComputerName PC01,PC02,PC03

# Chiavi BitLocker prima di toccare firmware, Secure Boot o TPM
.\07-Export-BitLockerRecoveryKey.ps1

# Upgrade in-place: la prima esecuzione e' sempre con -WhatIf
.\09-Invoke-Windows11Upgrade.ps1 -SetupPath D:\setup.exe -EulaAccept -WhatIf
```

## Scaricare e chiedere aiuto

Lo stesso contenuto è scaricabile come ZIP da [synsphere.it/download/toolkit-powershell-windows-11-migrazione](https://synsphere.it/download/toolkit-powershell-windows-11-migrazione/). Se ti serve una mano sull'assessment del parco o sulla migrazione, scrivici da [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
