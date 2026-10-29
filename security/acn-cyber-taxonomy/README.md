# Tassonomia Cyber ACN

Uno script che scarica la Tassonomia Cyber dell'ACN dalla sua fonte ufficiale e ti dice qual è il tag esatto da scrivere, invece di inventare un codice.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

La Tassonomia Cyber dell'Agenzia per la Cybersicurezza Nazionale è il vocabolario comune per descrivere eventi e minacce cyber: ogni caratteristica di un evento diventa un tag nella forma `acn:predicato="valore"`. Oltre che come documento, ACN la pubblica in formato JSON come tassonomia MISP, e questo script la legge da lì a ogni esecuzione invece di portarsi dietro una copia che invecchia.

È rivolto a chi, in una PMI o in un MSP, deve classificare un incidente con quel vocabolario — tipicamente per una notifica o per la rendicontazione interna — e vuole verificare un tag prima di scriverlo. Lo script filtra per predicato, cerca una parola fra valori, etichette e descrizioni, valida un singolo tag suggerendo i valori simili quando quello passato non esiste, esporta la tassonomia in CSV e genera una scheda di classificazione vuota da compilare.

Sul sistema è di sola lettura: non tocca tenant, utenti, policy o impostazioni, non richiede permessi amministrativi e non installa niente. L'unica scrittura è il CSV, e dove nasce quel file conta — vedi le due sezioni in fondo.

## Gli script

| File | Che cosa fa | Legge / Scrive |
| --- | --- | --- |
| `Get-AcnCyberTaxonomy.ps1` | Scarica la Tassonomia Cyber dell'ACN dalla sua pubblicazione MISP e la rende consultabile da riga di comando: filtro per predicato, ricerca libera su valori, etichette e descrizioni, validazione di un tag `acn:predicato="valore"` con suggerimento dei valori simili, esportazione in CSV e generazione di una scheda di classificazione da compilare, con i predicati raggruppati in quattro famiglie. | Sola lettura sul sistema e sul tenant; **SCRIVE** un CSV nella directory corrente |

Le modalità sono cinque, tutte sullo stesso file:

- senza parametri — esporta l'intera tassonomia in CSV e stampa il riepilogo per famiglia;
- `-Predicato <nome>` — solo i valori di un predicato (per esempio `impact`, `malicious-code`, `involved-asset`, `vector`);
- `-Cerca <testo>` — cerca il testo fra valori, etichette e descrizioni, per capire come si chiama una cosa nel vocabolario ACN;
- `-ValidaTag '<tag>'` — verifica che il tag esista nella tassonomia e, se non esiste, suggerisce i valori simili. È l'unica modalità che non scrive nessun file;
- `-SchedaEvento` — genera una scheda di classificazione vuota, un predicato per riga, con le colonne `ValoreScelto`, `TagRisultante` e `Note` da compilare.

Due parametri valgono per tutte: `-File` legge una copia locale del JSON invece di scaricarlo, `-OutputCsv` decide dove finisce il CSV.

## Prima di eseguirlo

**PowerShell 5.1 o successivo.** Lo script dichiara `#Requires -Version 5.1` — è l'unica dipendenza dichiarata nel codice — e gira anche su PowerShell 7.

**Nessun modulo da installare.** Usa soltanto cmdlet integrati: `Invoke-WebRequest`, `ConvertFrom-Json`, `Get-Content`, `Export-Csv`, `Get-Date`, `Test-Path`. Nel file non c'è nessun `Import-Module` né nessun `#Requires -Modules`, quindi non serve nessun `Install-Module`: si esegue su una postazione appena installata.

**Nessun permesso amministrativo e nessuna autenticazione.** Non c'è `#Requires -RunAsAdministrator`, e non c'è nessun `Connect-MgGraph`, `Connect-AzAccount` o `Connect-ExchangeOnline`: lo script non chiede nessun permesso delegato o applicativo, su nessun tenant, e non ha un ruolo da assegnare.

I due requisiti veri sono altri:

- **connettività HTTPS in uscita** verso `raw.githubusercontent.com`, con un timeout di 60 secondi sul download. Si evita del tutto con `-File`, passando una copia locale del JSON;
- **diritto di scrittura nella directory da cui lanci il comando**, perché è lì che nasce il CSV.

## ⚠️ Avvertenze

1. **La scheda di classificazione è costruita su un elenco di predicati scritto nello script, non su quello appena scaricato.** Le quattro famiglie — Baseline Characterization, Threat Type, Threat Actor, Additional Context — e i predicati che le compongono sono un raggruppamento nostro, cablato nel codice per rendere leggibile l'output: non fanno parte del JSON dell'ACN. Il ramo `-SchedaEvento` itera quell'elenco interno e non i dati scaricati, e un predicato che non ritrova lo salta senza dire niente. La conseguenza è che un predicato aggiunto a monte non comparirebbe mai nella scheda, e uno rinominato o rimosso sparirebbe in silenzio: la scheda può sembrare completa senza esserlo, ed è proprio l'artefatto che compili e porti in giro. Confronta il numero di righe della scheda con la riga che lo script stampa a ogni avvio (`Tassonomia 'acn' — N predicati, N valori`), e lancia una volta il comando senza parametri: l'esportazione completa raggruppa per famiglia e mostra un gruppo `(non classificato)` con i predicati che l'elenco interno non conosce.

2. **Una seconda esecuzione nello stesso giorno sovrascrive il CSV precedente, senza chiedere.** Il nome di default contiene solo la data (`.\ACN-SchedaEvento-20261029.csv`, `.\ACN-Tassonomia-20261029.csv`), `Export-Csv` è invocato senza `-NoClobber` e lo script non supporta né `-WhatIf` né `-Confirm`. Lo scenario che costa di più è quello normale: generi la scheda, compili `ValoreScelto` in Excel, poi rilanci `-SchedaEvento` lo stesso giorno per un secondo evento, e la scheda compilata se ne va senza una domanda. Ogni volta che la scheda ti serve per qualcosa, passa `-OutputCsv` con un nome che identifichi l'evento.

3. **I dati arrivano dal repository MISP, ramo `main`, senza verifica di integrità.** A ogni esecuzione lo script scarica `raw.githubusercontent.com/MISP/misp-taxonomies/main/acn/machinetag.json`: non è un endpoint dell'ACN, è la pubblicazione della tassonomia nel repository del progetto MISP, e non c'è nessun checksum né nessun pinning su un commit. Il contenuto con cui classifichi un evento vale quindi quanto quel ramo nel momento in cui lo leggi. Non c'è rischio di esecuzione di codice — il contenuto passa solo per `ConvertFrom-Json` e nel file non esiste nessun `Invoke-Expression` — il rischio è di disponibilità e di contenuto: dietro un proxy aziendale il download fallisce e lo script si ferma con un messaggio che rimanda a `-File`. Per una classificazione che devi poter difendere, verifica il tag sul documento dell'ACN; per lavorare offline o su una copia congelata, scarica il JSON una volta e usa `-File`.

4. **I numeri scritti nella documentazione dello script non si aggiornano, il conteggio a video sì.** L'help in testa al file cita un numero fisso di valori e di predicati, scritto a mano: se ACN e MISP aggiornano il JSON quel numero diventa falso e niente lo segnala, proprio perché la tassonomia non è incorporata. Il conteggio vero è quello che lo script stampa a ogni avvio, nella riga `Tassonomia 'acn' — N predicati, N valori`. È l'unico da citare in un documento: non il numero nell'help, non un numero in questo README.

5. **Anche una semplice ricerca scrive un CSV.** Nel ramo di consultazione l'esportazione avviene prima della stampa a video: `-Predicato` e `-Cerca` ti mostrano la tabella dei tag, ma hanno già scritto `.\ACN-Tassonomia-<data>.csv`. Due conseguenze: una consultazione veloce lascia un file nella cartella in cui ti trovi, e sovrascrive l'esportazione completa fatta lo stesso giorno. Se stai solo cercando una parola, lancia il comando in una cartella di lavoro oppure passa `-OutputCsv` su un percorso temporaneo. L'unica modalità che non scrive niente è `-ValidaTag`.

6. **`-ValidaTag` valida il predicato e il valore, non il namespace.** Se il namespace che passi è diverso da quello della tassonomia, lo script lo segnala in giallo ma prosegue: subito sotto può comparire `TAG VALIDO`, che si riferisce alla coppia predicato/valore e non al tag così come l'hai scritto. Il formato accettato è volutamente permissivo — `acn:impact="..."`, `impact="..."`, `impact:...` — quindi il tag che hai digitato e quello che lo script ha validato possono non essere la stessa stringa. Copia sempre la forma canonica dal campo `Tag` dell'output: è quella costruita con il namespace reale della tassonomia.

## Dove finiscono i file

Entrambi i CSV hanno un nome di default **relativo** alla directory corrente, e quel nome contiene solo la data:

- `.\ACN-Tassonomia-<aaaammgg>.csv` — l'esportazione della tassonomia, anche quando è filtrata per predicato o per ricerca;
- `.\ACN-SchedaEvento-<aaaammgg>.csv` — la scheda di classificazione da compilare.

Due conseguenze da tenere a mente ogni volta:

- **Il file nasce dove si trova il prompt, non dove si trova lo script.** Se hai clonato questo repository e lanci da lì, il CSV finisce dentro il clone. Il `.gitignore` nella radice esclude `*.csv`, ma non fidarti: controlla con `git status` prima di committare. E in una cartella sincronizzata su OneDrive o SharePoint nessun `.gitignore` ti protegge.
- **Una seconda esecuzione nello stesso giorno sovrascrive la precedente, senza chiedere.** Il nome contiene la data ma non l'ora: per conservare due risultati dello stesso giorno servono due `-OutputCsv` diversi.

Sul contenuto, al contrario di quasi tutti gli altri toolkit di questa raccolta: l'esportazione della tassonomia **non contiene dati del tenant**. Sono predicati, valori, etichette, descrizioni e tag di un vocabolario pubblico: nessun utente, nessun indirizzo, nessun permesso, nessuna credenziale. La scheda, però, cambia natura appena la compili: `ValoreScelto`, `TagRisultante` e `Note` descrivono un incidente reale, e da quel momento è un documento interno da trattare come tale, fuori dal repository e fuori dalle cartelle condivise per distrazione.

## Esempi

```powershell
# Come si chiama "ransomware" nel vocabolario ACN
.\Get-AcnCyberTaxonomy.ps1 -Cerca ransomware

# Tutti i valori di un predicato
.\Get-AcnCyberTaxonomy.ps1 -Predicato malicious-code

# Verificare un tag prima di scriverlo: non scrive nessun file
.\Get-AcnCyberTaxonomy.ps1 -ValidaTag 'acn:impact="account-compromise"'

# Scheda di classificazione per un evento, con un nome che non verrà sovrascritto
.\Get-AcnCyberTaxonomy.ps1 -SchedaEvento -OutputCsv 'C:\Incidenti\2026-014-classificazione.csv'
```

## Altro

Lo stesso contenuto si scarica come ZIP dalla pagina [synsphere.it/download/script-powershell-tassonomia-cyber-acn/](https://synsphere.it/download/script-powershell-tassonomia-cyber-acn/).

Se serve aiuto a classificare un evento o a impostare la rendicontazione interna: [synsphere.it/contattaci](https://synsphere.it/contattaci).

Fonte dei dati: la Tassonomia Cyber dell'ACN, pubblicata come tassonomia MISP ([github.com/MISP/misp-taxonomies/tree/main/acn](https://github.com/MISP/misp-taxonomies/tree/main/acn)). Documento di riferimento: Agenzia per la Cybersicurezza Nazionale ([acn.gov.it](https://www.acn.gov.it/)). Lo script legge la fonte ufficiale: non sostituisce il documento dell'ACN e non ne costituisce una interpretazione autentica.

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
