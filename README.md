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
- Scenari in `scripts/scenari.gd`: **The Sun of Austerlitz 1805** (agosto-dicembre 1805, vince il Francese con
  almeno un PF a Vienna) e **Struggle of Nations 1813** (aprile-dicembre 1813, vince il Francese se tiene una città
  maggiore non assediata nell'area 3), con neutrali (Austria, Svezia, satelliti), alleanze, rinforzi mensili,
  assedi e trincee iniziali, fonti di rifornimento dello scenario.
- L'IA segue i consigli dei giocatori esperti e del designer (articolo "Napoleon's Empire" su The General):
  corpi di 5-10 PF, Napoleone pesato più dei suoi PF, marcia forzata per le mosse decisive, nel 1805 Ulm e poi
  Vienna, nel 1813 fuga iniziale degli Alleati e ammassamento francese al nord se arriva l'Austria.

Semplificazioni: niente movimento navale né Egitto, niente contrattacco di chi viene attaccato, rinforzi in
battaglia tentati in automatico (si spengono dal menu), aree di mappa e montagne basse/alte ricavate dall'immagine.

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
