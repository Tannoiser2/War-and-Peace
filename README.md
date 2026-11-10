# War and Peace — versione digitale (uso personale)

Il gioco strategico di Mark McLaughlin sulle guerre napoleoniche (6ª/7ª edizione, One Small Step), in Godot 4.7
con esportazione web. Mappa d'Europa in 3D con il tabellone e le pedine originali del modulo di Tabletop Simulator,
IA per giocare da soli, partita online con un amico e salvataggi su Firebase.

Si gioca qui: https://tannoiser2.github.io/War-and-Peace/ (e nella ludoteca: https://tannoiser2.github.io).

## Cosa c'è

- **Mappa**: il tabellone originale (riscalato a 4096 px) con la griglia esagonale digitalizzata: 1.467 esagoni di
  terra con terreno (aperto, foresta, montagna, palude), fiumi sui lati, lati di mare, 142 città (capitali, maggiori,
  minori), stati e aree di mappa 1-4. I dati stanno in `assets/mappa/mappa.json`; gli strumenti che li hanno
  estratti dall'immagine sono in `tools/estrazione/`.
- **Pedine**: le pedine originali (120 tipi di unità, 95 capi, segnalini), in `assets/pedine/` con `catalogo.json`.
- **Regole** (`scripts/motore.gd`): sequenza di gioco, logoramento, alleanze, rinforzi, movimento con i capi
  (10/12 PF, 3 PM per la fanteria), marcia forzata, travolgimento, rifornimento a catena, trincee, combattimento a
  round con comando/morale/terreno, demoralizzazione, rinforzi in battaglia, ritirate e avanzate, città
  (capienza, assalto, assedio), perdite fra i capi, punti vittoria.
- **IA** (`scripts/ia.gd`): concentra le forze contro obiettivi e armate nemiche secondo i rapporti di forza, evita
  gli ammassi che si logorano, usa la marcia forzata quando serve, decide assalti, assedi e ritirate. Tre caratteri:
  prudente, normale, aggressivo.
- **Online** (`scripts/rete.gd`): stanza con codice di 4 lettere, ogni decisione numerata nel registro della stanza
  (`warpeace/rooms/<codice>/log/<n>`); i dadi sono deterministici, quindi le due copie del gioco restano uguali.
  Se l'amico non entra, l'altra parte la guida l'IA del dispositivo che ha creato la stanza.
  Le regole del database sono quelle comuni della ludoteca (radice `warpeace`).
- **Salvataggi**: in locale a ogni cambio di lato e su Firebase (`warpeace/salvataggi/<uid>`).
- Comandi: trascina per spostare, rotella o pizzico per lo zoom, tasto destro o due dita per ruotare (anche su iPad).

## Tabelle e scenari

- Le tabelle in `scripts/dati.gd` sono quelle ufficiali della Player-Aid Card (6ª/7ª ed., One Small Step 2019):
  Combat Results Table, Combat Loss Chart, Attrition Table, Forced March Table, Terrain Effects Chart.
- Scenari in `scripts/scenari.gd`: tutti quelli del libretto ufficiale della 7ª edizione (One Small Step 2020):
  I Italia 1796 (introduttivo e avanzato), II Egitto 1798-99 (anche con le flotte), III Marengo 1800, IV Austerlitz
  1805, V Jena e Friedland 1806-07, VI Wagram 1809, VII Russia 1812, VIII Lipsia 1813, IX Francia 1814, X Waterloo
  1815, XI Guerra di Spagna 1808-14, XII Spagna 1811-14, XIII The Final Glory (1812-1814 collegati). Ogni scenario
  è un dizionario: schieramento in forma breve (`G("Ulm", ["FR:Ney"], "FR 4I; FR:B 1I")`), rinforzi per data,
  alleanze ed eventi con condizioni ed effetti, fonti di rifornimento, condizioni di vittoria, "fasi" per gli
  scenari collegati. Gli esagoni ufficiali (es. P23) si scrivono `#riga,colonna` (riga = 56 - lettere, colonna + 5).
- Regole navali del Grand Campaign Game (sezione F): squadre e trasporti, 4 PM, zone di mare (Atlantico, Mare
  del Nord, Baltico, Mediterraneo occidentale e orientale), intercettazione, combattimento con la Naval Results
  Table e la Naval Damage Table, inseguimento, blocco, trasporti senza scorta, burrasche, Nelson.
- Regole facoltative di battaglia, da scegliere a inizio partita (anche online, nella stanza): matrice tattica
  (Optional Tactical Matrix del foglio delle tabelle, con i segnalini originali), manovra sul retro (U), carica di
  cavalleria (V), Guardia Imperiale (W), combattimento demoralizzato (Y), nebbia di guerra (Z: le pile nemiche
  sono una bandiera con "?", il capo si vede solo vicino alle proprie truppe, le battaglie si scoprono dopo la
  dichiarazione; è solo dell'interfaccia, l'IA vede tutto). L'IA sceglie la tattica con la strategia
  mista d'equilibrio della matrice (o la ritirata se vuole lasciare il campo), carica quando è la forza più grande,
  impegna la Guardia quando il morale francese è basso e tenta sempre la manovra sul retro. Per le simulazioni:
  `WP_OPZIONI=matrice,carica,guardia,aggiramento,demoralizzato`.
- Contrattacchi (regola N5): quando l'attaccante interrompe una battaglia campale, il difeso può contrattaccare.
- La mappa ha anche il riquadro dell'Egitto (150 esagoni con Nilo, deserto, Siria) e le zone di mare dei porti e
  delle coste (`tools/estrazione/mari_egitto.py`).
- L'IA segue i consigli dei giocatori esperti e del designer (articolo "Napoleon's Empire" su The General):
  corpi di 5-10 PF, Napoleone pesato più dei suoi PF, marcia forzata per le mosse decisive, nel 1805 Ulm e poi
  Vienna, nel 1813 fuga iniziale degli Alleati e ammassamento francese al nord se arriva l'Austria.
- Catene di depositi (regola M3c): per ogni armata senza rifornimento l'IA calcola la strada dalla fonte più
  vicina e i punti dove serve un PF dello stesso colore (al massimo 3 PM l'uno dall'altro); la cavalleria libera
  (o staccata dalle armate grandi) occupa i depositi vuoti e capi minori con i rinforzi fanno da convoglio,
  lasciando un PF in ogni deposito lungo la marcia. Le truppe dei depositi non vengono raccolte.
- Strategie di scenario (`ia.asse`): nel 1814 Austriaci, Russi e Prussiani si radunano a Baden a gennaio e da
  febbraio marciano insieme su Parigi, anche d'inverno con la marcia forzata. Nel 1815 gli assi sono due:
  Prussiani e Inglesi da Namur (da luglio), Austriaci e Russi da Baden (da agosto). Le armate in marcia
  lungo un asse lasciano fino a tre depositi per non perdere il rifornimento, e i rinforzi inglesi fermi a
  Londra attraversano la Manica verso il porto più vicino al fronte.
- Per gli scenari nuovi l'IA sa anche: mandare i capi in più a prendere i rinforzi rimasti fermi senza capo,
  lasciare depositi lungo la strada (fanteria ogni 3 punti movimento, regola J6e) per non perdere il
  rifornimento, assaltare una città importante quando l'esercito è senza rifornimento e l'assedio è impossibile,
  contrattaccare con forze nettamente superiori, imbarcare e sbarcare le armate, cacciare e bloccare le flotte
  nemiche, sbarcare le forze in mare e spostarsi via mare dove lo scenario lo permette.
- Confronti fra versioni dell'IA: `WP_IA_VECCHIA=<lato>` spegne i comportamenti nuovi per un lato e
  `WP_NO_RACCOLTA`, `WP_NO_DEPOSITI`, `WP_NO_CATENE`, `WP_NO_DISPERATO` uno alla volta; `WP_DEBUG_IA=1` stampa i piani.

Semplificazioni: rinforzi in battaglia tentati in automatico (si spengono dal menu); intercettazioni e inseguimenti
navali decisi in automatico; rimpiazzi a punti della Spagna comprati in automatico; prede navali affondate e
riparazioni gratuite nei porti amici; le flotte globali (oltre i mari europei) non sono in gioco; aree di mappa e
montagne basse/alte ricavate dall'immagine.

## Prove

```
tests/corri.sh sim.gd 6                      # partite automatiche IA contro IA
xvfb-run godot --path . -s res://tests/foto.gd -- movimento   # screenshot (menu, partita, movimento, battaglia, fine)
GODOT=godot tests/prova_online.sh            # due copie del gioco online su un finto Firebase
python3 tools/controlla_glifi.py             # ogni carattere dei testi esiste nei font
```

## Pubblicazione

Solo a richiesta: Actions → *Pubblica* → *Run workflow*, oppure un commit con `[pubblica]` nel messaggio.
Pubblica su GitHub Pages e, se ci sono i segreti `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`, sulla ludoteca
privata di Cloudflare.

Font: Cinzel ed EB Garamond (SIL Open Font License, in `assets/font/`).
