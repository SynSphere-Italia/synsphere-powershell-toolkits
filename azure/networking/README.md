# Inventario e audit della rete Azure

Dieci script di sola lettura che fotografano il lato rete di una subscription Azure — VNet, NSG, IP pubblici, peering, bilanciatori, DNS, route table — e lo scrivono in CSV.

[English version](README.en.md) · [← Tutti i toolkit](../../README.md)

## A che serve

È rivolto all'amministratore IT, al tecnico di un MSP e al network admin che devono documentare la rete di un ambiente Azure senza toccarla: capire quale topologia c'è davvero, quali regole NSG sono in vigore, quali IP pubblici sono esposti, dove viene deviato il traffico. Lo scenario tipico è la presa in carico di un ambiente che nessuno ha mai documentato, oppure il controllo periodico prima di un intervento o di una change review.

Nessuno dei dieci script modifica qualcosa su Azure: usano soltanto cmdlet `Get-*`, e l'unica cosa che producono è un file CSV sulla postazione da cui li esegui.

## Gli script

| File | Che cosa fa | Legge / Scrive |
|------|-------------|----------------|
| `01-Get-AzVNetInventory.ps1` | Inventario delle VNet e delle loro subnet: address space, region, nome e prefisso di ogni subnet, e il NSG associato alla subnet (`(nessuno)` se manca). La mappa di base della topologia. | Sola lettura |
| `02-Export-AzNsgRules.ps1` | Export di tutte le regole NSG custom della subscription, con priorità, direzione, azione, protocollo, sorgente, destinazione e porte: la documentazione di rete completa, per audit e change review. | Sola lettura |
| `03-Get-AzPublicIpReport.ps1` | Tutti gli indirizzi IP pubblici con SKU (Basic o Standard), metodo di allocazione (statico o dinamico) e risorsa a cui sono collegati. Inventario dell'esposizione e controllo dei costi. | Sola lettura |
| `04-Get-AzNetworkOrphans.ps1` | Risorse di rete orfane: NIC senza VM, IP pubblici senza associazione, NSG non collegati né a subnet né a NIC. Residui da ripulire, alcuni dei quali si pagano. | Sola lettura |
| `05-Get-AzVNetPeering.ps1` | Peering di ogni VNet con lo stato della connessione e le opzioni attive (traffico inoltrato, gateway transit, uso del gateway remoto). Serve a leggere una topologia hub-spoke e a diagnosticare problemi di connettività. | Sola lettura |
| `06-Get-AzEffectiveNsgRules.ps1` | Regole NSG **effettive** su una singola NIC, cioè la combinazione fra NSG di subnet e NSG di NIC: quello che è davvero permesso o negato su quella scheda. Richiede `-NetworkInterfaceName` e `-ResourceGroupName`. È lo strumento per il troubleshooting di connettività. | Sola lettura (ma leggi le avvertenze 2 e 3) |
| `07-Get-AzLoadBalancerInventory.ps1` | Load Balancer (SKU, numero di regole e di backend pool) e Application Gateway (SKU, numero di listener, stato operativo): i punti di ingresso applicativi della rete. | Sola lettura |
| `08-Get-AzSubnetsWithoutNsg.ps1` | Subnet senza NSG associato, cioè senza filtro sul traffico. Il codice esclude dal report le subnet di sistema: `GatewaySubnet`, `AzureFirewallSubnet`, `AzureFirewallManagementSubnet`, `AzureBastionSubnet`, `RouteServerSubnet`. | Sola lettura |
| `09-Export-AzDnsRecords.ps1` | Zone DNS **pubbliche** e tutti i loro record con TTL e valori. A, AAAA, CNAME, MX, NS e TXT sono resi in forma leggibile; gli altri tipi finiscono nella cella come JSON compatto. Le zone DNS *private* non sono comprese. | Sola lettura |
| `10-Get-AzRouteTables.ps1` | Route table (UDR) con ogni rotta — prefisso, tipo di next hop, IP del next hop — e le subnet a cui la tabella è associata. Serve a capire dove viene deviato il traffico, per esempio verso un firewall. | Sola lettura |

## Prima di eseguirli

- **Versione di PowerShell: nessuno dei dieci script la dichiara.** La direttiva `#Requires -Version` non c'è in nessuno di essi. Il vecchio file di istruzioni del kit indicava "PowerShell 5.1 o PowerShell 7", ma il codice non lo impone: su una versione diversa gli script partono comunque, e l'eventuale errore arriva più tardi.
- **Moduli.** Le direttive `#Requires -Modules` in testa agli script ne citano tre, e con questi tre la copertura è completa. Uno script che non trova il suo modulo si rifiuta di partire:

  ```powershell
  Install-Module Az.Accounts -Scope CurrentUser   # richiesto da tutti e dieci
  Install-Module Az.Network  -Scope CurrentUser   # richiesto da nove: tutti tranne il 09
  Install-Module Az.Dns      -Scope CurrentUser   # richiesto solo dal 09
  ```

  In alternativa `Install-Module Az -Scope CurrentUser` installa l'intera suite, che li comprende. Per le zone DNS private servirebbe `Az.PrivateDns`, ma nessuno script di questa cartella lo usa: le zone private restano fuori dal report.
- **Autenticazione interattiva:** `Connect-AzAccount`. Ogni script controlla il contesto e, se non ne trova uno, apre il login da sé. Nel codice non c'è nessun service principal, nessun certificato e nessun segreto; non serve nessun permesso Microsoft Graph.
- **Permessi: il ruolo Azure RBAC Reader basta per nove script su dieci.** Il decimo, `06-Get-AzEffectiveNsgRules.ps1`, richiede in aggiunta l'action `Microsoft.Network/networkInterfaces/effectiveNetworkSecurityGroups/action`: la concede il ruolo Network Contributor, oppure un ruolo custom che includa quella singola action. Il motivo è nell'avvertenza 2.
- **Solo per il 06: la VM associata alla NIC deve essere avviata**, altrimenti le regole effettive non esistono e non c'è niente da leggere.

## ⚠️ Avvertenze

1. **Il report copre soltanto la subscription attiva, e il CSV non dice quale sia.** Nessuno dei dieci script seleziona una subscription: prendono quella che `Get-AzContext` restituisce al momento del lancio, e nessuna delle colonne esportate riporta la subscription o il tenant di provenienza. Le conseguenze sono due. Se amministri più ambienti, due CSV prodotti in momenti diversi sono indistinguibili a occhio, e un report può finire attribuito all'ambiente sbagliato. E se l'ambiente ha più subscription, il report ne fotografa una sola e sembra completo. A questo si aggiunge che le liste ARM restituiscono soltanto le risorse su cui hai un'assegnazione: con Reader su un solo resource group, `Get-AzVirtualNetwork` non dà errore, restituisce meno. Il che rende ingannevoli soprattutto i due report "negativi": `0 subnet senza NSG` e `0 risorse di rete orfane` si leggono come una buona notizia, ma possono voler dire "zero fra quelle che riesci a vedere". Prima di lanciare, stampa il contesto, scegli l'ambiente in modo esplicito, e poi rinomina il CSV mettendoci il nome della subscription.

```powershell
Get-AzContext | Select-Object Name, Subscription, Tenant
Get-AzSubscription                            # tutte quelle a cui hai accesso
Set-AzContext -Subscription '<nome-o-id>'
```

2. **Lo script 06 non gira con il solo ruolo Reader, anche se il suo header dice il contrario.** Il blocco `.NOTES` di tutti e dieci gli script, e il vecchio file di istruzioni, dichiarano "Permessi: ruolo Reader": per nove è vero, per `06-Get-AzEffectiveNsgRules.ps1` no. Il cmdlet `Get-AzEffectiveNetworkSecurityGroup` richiede `Microsoft.Network/networkInterfaces/effectiveNetworkSecurityGroups/action`, che Azure classifica come *action* e non come operazione di lettura, mentre il ruolo predefinito Reader concede soltanto `*/read`. Con Reader puro quello script si interrompe con `AuthorizationFailed`, cioè con un errore che la documentazione del kit ti dice che non può capitare: lo cercherai nel posto sbagliato. Per il 06 assegna Network Contributor, o un ruolo custom che includa quella action.

3. **I CSV sono documentazione riservata: in chiaro c'è quello che serve per attaccare quella rete.** Messi insieme, i dieci export contengono le regole NSG complete con sorgenti, destinazioni e porte (02 e 06), gli indirizzi IP pubblici reali (03), il contenuto integrale delle zone DNS pubbliche record per record (09) e le route table con gli IP dei next hop (10). Il percorso predefinito è la directory corrente, cioè la cartella da cui hai aperto la shell: su una postazione aziendale è spesso una cartella sincronizzata sul cloud, e l'export vi finisce senza che nessuno lo chieda. Decidi dove scriverli con `-OutputCsv`, trattali come la documentazione di rete di un cliente e non lasciarli dove sono nati.

4. **Sono "tutto o niente": se qualcosa va storto, il CSV non viene scritto affatto.** Nessuno dei dieci script ha un `try/catch`, e tutti impostano `$ErrorActionPreference = 'Stop'`. Dato che in tutti e dieci l'`Export-Csv` è l'ultima istruzione, un resource group inaccessibile o un provider non registrato interrompono l'esecuzione prima della scrittura: non ottieni un report parziale, ottieni un'eccezione ARM grezza e nessun file. Il caso peggiore è `09-Export-AzDnsRecords.ps1`, che cicla zona per zona: una sola zona illeggibile butta via il lavoro fatto su tutte le altre. Gli script non espongono un parametro per restringere il perimetro — l'unico che lavora su un oggetto solo è il 06, su una NIC — quindi, se l'errore si ripresenta sempre sullo stesso oggetto, la sola leva è il contesto: la subscription selezionata e quello che il tuo account riesce a vedere.

5. **Due esecuzioni nello stesso giorno: la seconda sovrascrive la prima, in silenzio.** Il nome di default contiene solo la data (`yyyyMMdd`) e `Export-Csv` è invocato senza `-NoClobber` in tutti e dieci gli script. Se rilanci lo stesso script dopo aver cambiato qualcosa, il CSV di prima non c'è più e nessun messaggio te lo dice. Se ti servono un "prima" e un "dopo" — ed è il caso tipico quando si sistema una rete — passa `-OutputCsv` con due nomi diversi.

## Dove finiscono i file

Tutti e dieci gli script esportano un CSV in UTF-8, senza la riga di tipo, e in tutti e dieci il percorso è il parametro `-OutputCsv`. I nomi predefiniti sono `Az-VNetInventory-<yyyyMMdd>.csv` e, con lo stesso schema, `Az-NsgRules-`, `Az-PublicIp-`, `Az-NetworkOrphans-`, `Az-VNetPeering-`, `Az-EffectiveNsg-`, `Az-LoadBalancers-`, `Az-SubnetsNoNsg-`, `Az-DnsRecords-`, `Az-RouteTables-`. Tre cose da sapere:

- **Il file nasce dove si trova il prompt, non accanto allo script.** Il default è `.\`, cioè la directory corrente al momento del lancio. Se hai clonato questo repository e lanci da dentro il clone, il CSV si crea **dentro il clone**: il `.gitignore` della radice esclude `*.csv`, ma guarda il `git status` prima di committare, invece di fidarti. Con un `-OutputCsv` esplicito il dubbio non c'è. Il parametro è una stringa senza validazione: un percorso inesistente non viene segnalato all'inizio, l'errore arriva alla fine, quando la raccolta dei dati è già stata fatta tutta.
- **Il nome porta solo la data, e non c'è `-NoClobber`:** la seconda esecuzione dello stesso giorno sovrascrive la precedente senza chiedere (avvertenza 5).
- **Il contenuto è sensibile, non è uno scarto.** Regole NSG complete con sorgenti, destinazioni e porte; indirizzi IP pubblici reali; tutti i record delle zone DNS pubbliche; gli IP dei next hop delle route table. Chi legge questi file sa com'è fatta la rete e dove è aperta: conservali come conservi la documentazione di rete di un cliente.

## Esempi

```powershell
# Prima di tutto: accedi e verifica su quale ambiente stai lavorando (avvertenza 1)
Connect-AzAccount
Get-AzContext | Select-Object Name, Subscription, Tenant

# Inventario di VNet e subnet
.\01-Get-AzVNetInventory.ps1

# Tutte le regole NSG, in un percorso scelto da te
.\02-Export-AzNsgRules.ps1 -OutputCsv D:\Audit\NsgRules.csv

# Regole effettive su una NIC: la VM deve essere accesa e Reader non basta (avvertenze 2 e 3)
.\06-Get-AzEffectiveNsgRules.ps1 -NetworkInterfaceName nic-web01 -ResourceGroupName rg-prod

# Zone e record DNS pubblici
.\09-Export-AzDnsRecords.ps1
```

## Altro

Lo stesso contenuto si scarica come ZIP da [synsphere.it/download/toolkit-powershell-azure-networking](https://synsphere.it/download/toolkit-powershell-azure-networking/); la guida che accompagna il kit è [qui](https://synsphere.it/notizie/script-powershell-azure-networking-toolkit-pmi/). Se serve aiuto: [synsphere.it/contattaci](https://synsphere.it/contattaci).

> Licenza: vedi [LICENSE](../../LICENSE) nella radice del repository.
> Microsoft, Microsoft 365, Azure, Entra, Intune, Purview e Defender sono marchi del gruppo Microsoft. SynSphere Italia non è affiliata a Microsoft né approvata da Microsoft.
