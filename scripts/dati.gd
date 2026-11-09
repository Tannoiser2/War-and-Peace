## Dati fissi del gioco: nazioni, tipi di unità, tabelle e scenario.
## ATTENZIONE: le tabelle (Combattimento, Perdite, Logoramento, Marcia forzata, Terreno) sono
## PROVVISORIE: il modulo TTS non contiene la Player-Aid Card. Sono ricostruite in modo coerente con
## gli esempi del regolamento (6a/7a ed.) e vanno sostituite con quelle ufficiali appena disponibili.
class_name Dati
extends RefCounted

const LATI := ["Francia", "Coalizione"]
const LATI_BREVI := ["Francesi", "Alleati"]

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

const NOMI_TERRENO := {"pianura": "terreno aperto", "foresta": "foresta", "montagna": "montagna", "palude": "palude"}

## Costo in punti movimento per entrare in un esagono (provvisorio)
const COSTO_TERRENO := {"pianura": 1, "foresta": 2, "montagna": 3, "palude": 3}
const COSTO_FIUME := 1
## Modificatore di combattimento per chi viene attaccato in quel terreno (provvisorio, il fiume
## vale 2 come nell'esempio del regolamento)
const MOD_TERRENO := {"pianura": 0, "foresta": 1, "montagna": 2, "palude": 1}
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
# Tabelle (provvisorie)

## Tabella dei risultati del combattimento: per ogni rapporto, tiro modificato 2..12 -> [L, S]
## (L = forza più grande, S = forza più piccola). 3:2 con 9 = L 1, S D1 come nell'esempio.
const CRT := {
	"1:1": [["D2", "0"], ["D1", "0"], ["D1", "1"], ["1", "1"], ["1", "1"], ["1", "1"], ["1", "D1"], ["1", "D1"], ["0", "D1"], ["0", "D2"], ["0", "D2"]],
	"3:2": [["D1", "0"], ["D1", "1"], ["1", "1"], ["1", "1"], ["1", "D1"], ["1", "D1"], ["1", "D1"], ["1", "D1"], ["0", "D1"], ["0", "D2"], ["0", "D3"]],
	"2:1": [["D1", "1"], ["1", "1"], ["1", "1"], ["1", "D1"], ["1", "D1"], ["0", "D1"], ["0", "D1"], ["0", "D2"], ["0", "D2"], ["0", "D3"], ["0", "D3"]],
}

## Tabella delle perdite: frazione della forza più piccola (13 PF: "1" = 2, "D1" = 3 come nell'esempio)
const PERDITE := {"0": 0.0, "1": 0.15, "D1": 0.2, "D2": 0.3, "D3": 0.4}

static func perdita(risultato: String, forza_piccola: int) -> int:
	var f: float = PERDITE.get(risultato, 0.0)
	if f <= 0.0:
		return 0
	return maxi(1, int(round(forza_piccola * f)))

static func demoralizzazione(risultato: String) -> int:
	if risultato.begins_with("D"):
		return int(risultato.substr(1))
	return 0

## Tabella del logoramento: righe tiro modificato (<=2 .. >=7), colonne punti forza nell'esagono
## 3-5, 6-10, 11-15, 16-20, 21-30, 31+. Valore negativo = perdita con asterisco (una cavalleria).
## Con tiro 5 e 10 PF il risultato è 2* come nell'esempio del regolamento.
const LOGORAMENTO := [
	[0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 1, 1],
	[0, 0, 1, 1, 2, 2],
	[0, -2, -2, -2, -3, -4],
	[1, -2, -2, -3, -4, -5],
	[-1, -3, -3, -4, -5, -6],
]

static func logoramento(tiro: int, pf: int) -> int:
	if pf < 3:
		return 0
	var riga := clampi(tiro - 2, 0, 5)
	var col := 0
	if pf > 30: col = 5
	elif pf > 20: col = 4
	elif pf > 15: col = 3
	elif pf > 10: col = 2
	elif pf > 5: col = 1
	return LOGORAMENTO[riga][col]

## Tabella della marcia forzata: [tiro modificato 1..7][punti richiesti 1..3] -> punti ottenuti
## (negativo = con asterisco: si perde un punto forza). Come nell'esempio: +2 con 3 = 2, 4 = 1*, 5 = 0.
const MARCIA := [
	[1, 2, 3],
	[1, 2, 2],
	[1, 2, -2],
	[1, -1, -1],
	[-1, 0, 0],
	[0, 0, 0],
	[0, 0, 0],
]
## valore speciale: 0 con asterisco
const ZERO_ASTERISCO := -100

static func marcia(tiro: int, richiesti: int) -> Array:
	var riga := clampi(tiro - 1, 0, 6)
	var v: int = MARCIA[riga][clampi(richiesti - 1, 0, 2)]
	var ast := v < 0 or tiro >= 6
	return [absi(v), ast]

static func rapporto(grande: int, piccola: int) -> String:
	if piccola <= 0:
		return "4:1"
	var r := float(grande) / float(piccola)
	if r >= 4.0: return "4:1"
	if r >= 2.0: return "2:1"
	if r >= 1.5: return "3:2"
	return "1:1"
