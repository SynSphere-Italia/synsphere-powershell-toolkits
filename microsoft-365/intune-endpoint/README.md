# Intune / Endpoint Management Toolkit

Dieci script PowerShell che fotografano un parco endpoint gestito con Microsoft Intune — inventario, conformità, policy, app, Autopilot, versioni di Windows — ed esportano il risultato in CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

Gli script interrogano Intune via Microsoft Graph e restituiscono in forma tabellare lo stato del parco gestito: dispositivi iscritti, conformità e motivi di non conformità, policy e profili con le loro assegnazioni, app pubblicate, macchine che non si fanno più vedere, ripartizione fra Windows 10 e Windows 11. Sono rivolti ad amministratori IT e a MSP che gestiscono tenant Intune di piccole e medie imprese e hanno bisogno di un numero su tutto il parco senza ricavarlo a mano dalla console, oppure di un file datato da allegare come evidenza in un audit di conformità. Nove script su dieci sono di sola lettura; uno solo agisce sul tenant.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `01-Get-IntuneDeviceInventory.ps1` | Inventario completo dei dispositivi iscritti: sistema operativo e versione, stato di conformità, proprietà (aziendale o personale), produttore, modello, numero di serie, utente assegnato e data dell'ultimo check-in. È la fotografia di base del parco. | Sola lettura |
| `02-Get-IntuneComplianceOverview.ps1` | Conta i dispositivi per stato di conformità e per sistema operativo e calcola la percentuale di conformi. Totali a video, dettaglio per OS nel CSV. Non esporta identità. | Sola lettura |
| `03-Get-IntuneNonCompliantDevices.ps1` | Elenca i dispositivi il cui stato non è «compliant» (non conformi, in errore, in attesa di valutazione, in periodo di tolleranza) con OS, versione, utente, proprietà e ultimo check-in. | Sola lettura |
| `04-Export-IntuneCompliancePolicies.ps1` | Ogni criterio di conformità con la piattaforma di riferimento, la data di ultima modifica e il numero di gruppi a cui è assegnato: serve a vedere se una piattaforma è scoperta o se una policy esiste ma non è assegnata a nessuno. | Sola lettura |
| `05-Export-IntuneConfigurationProfiles.ps1` | I profili di configurazione dispositivo (impostazioni, restrizioni, VPN, Wi-Fi, certificati) con tipo, ultima modifica e numero di assegnazioni. | Sola lettura |
| `06-Get-IntuneAppInventory.ps1` | Le app pubblicate in Intune (Win32, Microsoft Store, LOB, collegamenti web) con editore, tipo e numero di assegnazioni; le app con zero assegnazioni sono quelle pubblicate e mai distribuite. | Sola lettura |
| `07-Get-IntuneStaleDevices.ps1` | I dispositivi che non sincronizzano da più giorni della soglia indicata (`-DaysInactive`, default 30), con i giorni di inattività. Elenca i candidati alla pulizia: non rimuove nulla. | Sola lettura |
| `08-Get-IntuneAutopilotDevices.ps1` | I dispositivi registrati per Windows Autopilot con numero di serie, produttore, modello, group tag, stato di iscrizione e stato di assegnazione del profilo di deployment. | Sola lettura |
| `09-Get-IntuneWindowsVersionReport.ps1` | Deduce dalla build se un PC Windows è Windows 10 o Windows 11 (build maggiore o uguale a 22000 = Windows 11) e produce riepilogo a video e CSV per dispositivo; una versione non interpretabile finisce in «Windows (n/d)». | Sola lettura |
| `10-Invoke-IntuneDeviceSync.ps1` | Invia il comando di sincronizzazione ai dispositivi il cui nome corrisponde al filtro `-DeviceNameLike`, per applicare subito policy, profili e app senza attendere il ciclo automatico. Supporta `-WhatIf`. | **SCRIVE** (azione sul tenant) |

## Prima di eseguirli

**PowerShell.** Il prerequisito dichiarato dalla raccolta è PowerShell 5.1 (quello preinstallato su Windows) oppure PowerShell 7. Nessuno dei dieci script dichiara una versione minima con `#Requires -Version`.

**Moduli.** Serve il Microsoft Graph PowerShell SDK completo:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

Il meta-modulo è necessario, non comodo. In testa a ogni script `#Requires -Modules Microsoft.Graph.Authentication` dichiara solo il modulo che fornisce `Connect-MgGraph`, mentre i cmdlet che leggono i dati stanno altrove: `Microsoft.Graph.DeviceManagement` (01-05, 07, 09, 10), `Microsoft.Graph.Devices.CorporateManagement` (06), `Microsoft.Graph.DeviceManagement.Enrollment` (08).

**Permessi.** Un account con ruolo Intune Administrator o permessi Graph equivalenti. Tutti gli scope sono delegati e interattivi: il consenso viene chiesto al primo `Connect-MgGraph`, non c'è autenticazione app-only, nessun certificato e nessun segreto nel codice. Ogni script chiede soltanto lo scope che usa.

| Scope Graph | Script |
| --- | --- |
| `DeviceManagementManagedDevices.Read.All` | 01, 02, 03, 07, 09 |
| `DeviceManagementConfiguration.Read.All` | 04, 05 |
| `DeviceManagementApps.Read.All` | 06 |
| `DeviceManagementServiceConfig.Read.All` | 08 |
| `DeviceManagementManagedDevices.PrivilegedOperations.All` + `DeviceManagementManagedDevices.Read.All` | 10 |

**Due note sulla documentazione interna.** `Get-Help` su questi script non mostra la descrizione ma solo la sintassi autogenerata: l'help c'è, in testa al file, e si legge aprendo il `.ps1`. E il blocco `.NOTES` dello script 10 indica il cmdlet `Sync-MgDeviceManagementManagedDevice` nel modulo `Microsoft.Graph.DeviceManagement.Actions`: quel modulo non esiste nella versione 2 dell'SDK, dove il cmdlet è esportato da `Microsoft.Graph.DeviceManagement`. Non cercare di installarlo.

## ⚠️ Avvertenze

1. **Lo script 10 accetta `-DeviceNameLike '*'`, che seleziona tutti i dispositivi del tenant.** Di norma chiede conferma dispositivo per dispositivo, perché è dichiarato `ConfirmImpact = 'High'`, ma `-Confirm:$false` disattiva la richiesta: la combinazione dei due invia il check-in a tutta la flotta senza una sola interazione. L'operazione in sé è benigna — è una sincronizzazione, non una cancellazione — ma resta un comando impartito a tutto il parco. Esegui prima con `-WhatIf`, che elenca i dispositivi selezionati senza inviare niente, e usa un filtro il più stretto possibile.

2. **I CSV contengono dati personali dei dipendenti.** Negli export finiscono `UserPrincipalName`, nome del dispositivo e utente assegnato (01, 03, 07, 09) e il numero di serie della macchina (01, 08). Sono dati personali a tutti gli effetti, e il percorso di default è relativo: il file nasce dove lanci il comando. Trattalo come tale — conservazione limitata nel tempo, nessuna condivisione oltre il necessario — e se ti serve solo un conteggio aggregato usa il 02, che non esporta identità.

3. **`-DaysInactive` accetta un valore negativo e lo script 07 non lo rifiuta.** Con `-DaysInactive -30` la soglia si sposta nel futuro e la condizione risulta vera per ogni dispositivo: il report elenca l'intera flotta come inattiva, e l'elenco sembra legittimo. Lo script è in sola lettura, quindi il danno non è sul tenant ma sulla decisione che prendi leggendolo. Passa sempre un numero positivo di giorni, e confronta il conteggio con il totale del parco prima di agire su quell'elenco.

4. **Nessuno script gestisce gli errori: non c'è né `try/catch` né retry.** `$ErrorActionPreference` è impostato su `Stop` in tutti e dieci e nessuno intercetta l'eccezione: un errore di Graph — throttling su un tenant grande, consenso negato, token scaduto, modulo mancante — interrompe l'esecuzione con uno stack trace grezzo. Poiché l'esportazione avviene alla fine, in quel caso non ottieni nessun CSV: l'assenza del file è l'unico segnale. Gli script che partono dai dispositivi enumerano inoltre l'intero tenant e filtrano lato client. Se succede, rilancia lo script.

5. **Un report vuoto, o un totale più basso del previsto, non è una buona notizia: è un numero da spiegare.** Gli script fotografano quello che Graph restituisce all'account con cui ti sei connesso e non verificano che il risultato sia completo. Se il 03 scrive «Trovati 0 dispositivi non conformi», o se il totale del 02 è inferiore al parco che conosci, confronta quel totale con la consistenza che ti aspetti prima di concludere che la postura è in ordine: una percentuale di conformità calcolata su un sottoinsieme è una percentuale sbagliata.

6. **Il `#Requires` in testa agli script dà un via libera che non basta.** Dichiara solo `Microsoft.Graph.Authentication`: chi installa quel modulo da solo supera il controllo, si autentica correttamente e poi si ferma alla prima chiamata `Get-Mg*`, con un errore di comando non riconosciuto che sembra un problema di permessi e non lo è. Installa il meta-modulo `Microsoft.Graph` completo.

## Dove finiscono i file

I nove script di lettura esportano un CSV; il parametro `-OutputCsv` ha come valore predefinito un percorso relativo nella forma `.\Intune-<contenuto>-<aaaammgg>.csv`. Lo script 10 non scrive nessun file.

Due conseguenze, sempre valide:

- **Il file nasce dove si trova il prompt, non dove sta lo script.** Il percorso di default è relativo alla directory corrente: se hai clonato il repository e lanci gli script da lì, il CSV finisce dentro il clone. Il `.gitignore` della radice esclude `*.csv`, ma non fidarti del filtro: controlla con `git status` prima di committare, oppure passa `-OutputCsv` con un percorso fuori dal repository.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente, senza chiedere.** Il nome predefinito contiene solo la data, non l'ora. Se ti serve lo storico — ed è il caso quando i CSV sono un'evidenza da conservare — passa `-OutputCsv` con un nome tuo, o sposta il file prima di rilanciare.

## Esempi

```powershell
# Inventario completo dei dispositivi gestiti
.\01-Get-IntuneDeviceInventory.ps1

# Percentuale di conformità, conteggi per stato e dettaglio per OS
.\02-Get-IntuneComplianceOverview.ps1

# Dispositivi che non sincronizzano da oltre 60 giorni
.\07-Get-IntuneStaleDevices.ps1 -DaysInactive 60

# Prova a vuoto del sync: elenca i dispositivi selezionati, non invia niente
.\10-Invoke-IntuneDeviceSync.ps1 -DeviceNameLike 'NB-*' -WhatIf
```

## Altro

Lo stesso contenuto è scaricabile come archivio ZIP dalla pagina del toolkit sul sito: [synsphere.it/download/toolkit-powershell-intune-endpoint](https://synsphere.it/download/toolkit-powershell-intune-endpoint/).

Se la gestione del parco endpoint ti serve come servizio, o se uno script non si comporta come descritto qui: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
