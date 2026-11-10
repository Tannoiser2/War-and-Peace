## Dati fissi del gioco: nazioni, tipi di unità e tabelle ufficiali della Player-Aid Card
## (6ª/7ª edizione, One Small Step 2019).
class_name Dati
extends RefCounted

const LATI := ["Francia", "Coalizione", "Neutrali"]
const LATI_BREVI := ["Francesi", "Alleati", "Neutrali"]

## Nazioni maggiori: nome, colore della pedina
const NAZ := {
	"FR": {"nome": "Francia", "agg": "francese", "col": Color(0.42, 0.62, 0.82)},
	"AU": {"nome": "Austria", "agg": "austriaco", "col": Color(0.95, 0.95, 0.93)},
	"PR": {"nome": "Prussia", "agg": "prussiano", "col": Color(0.78, 0.78, 0.78)},
	"RU": {"nome": "Russia", "agg": "russo", "col": Color(0.6, 0.68, 0.52)},
	"EN": {"nome": "Inghilterra", "agg": "inglese", "col": Color(0.93, 0.5, 0.4)},
	"SP": {"nome": "Spagna", "agg": "spagnolo", "col": Color(0.96, 0.77, 0.2)},
	"TU": {"nome": "Turchia", "agg": "turco", "col": Color(0.96, 0.6, 0.2)},
}

## Stati minori (codici delle pedine e delle regioni della mappa)
const MINORI := {
	"B": "Baviera", "D": "Danimarca", "Da": "Dalmazia", "H": "Olanda", "I": "Regno d'Italia",
	"N": "Napoli", "Pt": "Portogallo", "Po": "Polonia", "R": "Confederazione del Reno",
	"S": "Sassonia", "Sp": "Spagna", "Sz": "Svizzera", "W": "Vestfalia", "Wu": "Württemberg",
	"Br": "Brunswick", "He": "Assia", "Sw": "Svezia", "Pm": "Piemonte", "Mm": "Mamelucchi",
	"K": "Legione tedesca del Re", "Ha": "Hannover", "Ba": "Baden",
}

## Tipi di unità: nome, è cavalleria, morale di base
const TIPI := {
	"I": {"nome": "fanteria", "cav": false},
	"GI": {"nome": "fanteria della Guardia", "cav": false},
	"L": {"nome": "Landwehr", "cav": false},
	"M": {"nome": "milizia", "cav": false},
	"P": {"nome": "partigiani", "cav": false},
	"C": {"nome": "cavalleria", "cav": true},
	"GC": {"nome": "cavalleria della Guardia", "cav": true},
	"CC": {"nome": "cosacchi", "cav": true},
}

const MESI := ["Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno", "Luglio", "Agosto",
	"Settembre", "Ottobre", "Novembre", "Dicembre"]
## Mesi invernali (indice 0 = gennaio), come sul tracciato dei mesi della mappa
const INVERNO := [0, 1, 10, 11]

const NOMI_TERRENO := {"pianura": "terreno aperto", "foresta": "foresta", "montagna": "montagna bassa", "montagna_alta": "montagna alta", "palude": "palude"}

## Costo in punti movimento per entrare in un esagono (Terrain Effects Chart). La montagna bassa
## costa 2, quella alta (Alpi) 3; palude e lago d'inverno sono terreno aperto; ogni città costa 1.
const COSTO_TERRENO := {"pianura": 1, "foresta": 2, "montagna": 2, "montagna_alta": 3, "palude": 2}
const COSTO_FIUME := 1
## Modificatore di combattimento in battaglia campale a favore di chi è attaccato in quel terreno
## (foresta, palude, lago 1; montagna 2; attacco da oltre un fiume 2)
const MOD_TERRENO := {"pianura": 0, "foresta": 1, "montagna": 2, "montagna_alta": 2, "palude": 1}
const MOD_FIUME := 2

## Morale di base di un'unità (regola D7)
static func morale(naz: String, sub: String, tipo: String) -> int:
	if tipo == "GI" or tipo == "GC":
		return 3
	if tipo in ["L", "M", "P", "CC"]:
		return 0
	if sub != "" and sub != "K":
		return 1
	# simboli bianchi (morale 2): Francia, Inghilterra, Russia; simboli neri (morale 1): gli altri
	if naz in ["FR", "EN", "RU"]:
		return 2
	return 1

static func e_cavalleria(tipo: String) -> bool:
	return TIPI.get(tipo, {}).get("cav", false)

static func capienza(tipo_citta: String) -> int:
	return 4 if tipo_citta == "minore" else 6

# ---------------------------------------------------------------------------------------------
# Tabelle ufficiali

## Combat Results Table: risultati [L, S] (L = forza più grande, S = più piccola) per colonna;
## la colonna è tiro modificato - 2, spostata di 1 col 3:2 e di 2 col 2:1 (da 4:1 la forza piccola è travolta)
const CRT := [["D3", "1"], ["D2", "1"], ["D1", "1"], ["1", "0"], ["1", "1"], ["1", "1"], ["1", "1"], ["0", "1"], ["1", "D1"], ["1", "D2"], ["1", "D3"]]
const SPOSTA_CRT := {"1:1": 0, "3:2": 1, "2:1": 2}

static func crt(rap: String, tiro: int) -> Array:
	var i := clampi(tiro - 2 + int(SPOSTA_CRT.get(rap, 0)), 0, 10)
	return CRT[i]

## Combat Loss Chart: punti forza persi secondo i punti forza della forza più piccola (1..20, 21+)
const PERDITE := {
	"1": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3],
	"D1": [1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 6],
	"D2": [1, 1, 1, 2, 2, 3, 3, 3, 3, 3, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 9],
}

static func perdita(risultato: String, forza_piccola: int) -> int:
	if risultato == "0" or forza_piccola <= 0:
		return 0
	var k := "D2" if risultato == "D3" else risultato
	if not PERDITE.has(k):
		return 0
	return PERDITE[k][clampi(forza_piccola, 1, 21) - 1]

static func demoralizzazione(risultato: String) -> int:
	if risultato.begins_with("D"):
		return int(risultato.substr(1))
	return 0

## Attrition Table: righe dado modificato 1..6, colonne 3-5, 6-10, 11-15, 16-20, 21+ punti forza.
## Valore negativo = perdita con asterisco (una deve essere di cavalleria).
const LOGORAMENTO := [
	[0, 0, 0, 1, 1],
	[0, 0, 1, 1, -2],
	[0, 1, 1, -2, -3],
	[0, 1, -2, -2, -3],
	[0, -2, -2, -3, -4],
	[1, -2, -3, -3, -5],
]

static func logoramento(tiro: int, pf: int) -> int:
	if pf < 3:
		return 0
	var riga := clampi(tiro, 1, 6) - 1
	var col := 0
	if pf > 20: col = 4
	elif pf > 15: col = 3
	elif pf > 10: col = 2
	elif pf > 5: col = 1
	return LOGORAMENTO[riga][col]

## Forced March Table: [dado modificato 1..6][punti richiesti 1..3] -> punti ottenuti (negativo = con asterisco)
const MARCIA := [
	[1, 2, 3],
	[1, 2, 3],
	[1, 2, -2],
	[1, -1, -1],
	[1, 0, 0],
	[0, 0, 0],
]

static func marcia(tiro: int, richiesti: int) -> Array:
	var riga := clampi(tiro, 1, 6) - 1
	var v: int = MARCIA[riga][clampi(richiesti - 1, 0, 2)]
	return [absi(v), v < 0]

static func rapporto(grande: int, piccola: int) -> String:
	if piccola <= 0:
		return "4:1"
	var r := float(grande) / float(piccola)
	if r >= 4.0: return "4:1"
	if r >= 2.0: return "2:1"
	if r >= 1.5: return "3:2"
	return "1:1"
