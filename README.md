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

## Da completare con il materiale originale

Il modulo TTS non contiene la **Player-Aid Card** (tabelle di combattimento, perdite, logoramento, marcia forzata,
effetti del terreno) né il **libretto degli scenari**. Per ora:

- le tabelle in `scripts/dati.gd` sono **ricostruite** in modo coerente con gli esempi del regolamento
  (es. 3:2 con 9 = L 1 / S D1; 13 PF: "1" = 2 perdite, "D1" = 3; logoramento 5 con 10 PF = 2*; marcia forzata +2:
  3 = 2, 4 = 1*, 5 = 0; fiume = 2);
- lo scenario **Austerlitz 1805** in `scripts/scenari.gd` è **ricostruito** sulla storia.

Quando arrivano le tabelle e gli scenari veri basta sostituire quei dati (il formato degli scenari è pensato per
aggiungere gli altri: Jena-Friedland, Wagram, Russia 1812, ecc.).

Semplificazioni attuali: niente movimento navale né Egitto, niente contrattacco di chi viene attaccato, rinforzi in
battaglia tentati in automatico (si spengono dal menu).

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
