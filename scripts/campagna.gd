class_name Campagna
extends RefCounted
## Grand Campaign Game 1805-1815 (regole GCG della 7ª edizione), partita a due giocatori: la Francia
## e i suoi alleati contro l'Inghilterra e i suoi. Qui ci sono lo stato politico delle potenze,
## le conquiste, la produzione dalle riserve, le alleanze, gli stati minori e la vittoria.
## Lo stato della campagna sta in m.s["camp"].

const MAGGIORI := ["FR", "EN", "AU", "PR", "RU", "SP"]

## Città di produzione: "citta" producono tutto, "landwehr" solo Landwehr, "navali" solo navi
const PRODUZIONE := {
	"FR": {"citta": ["Paris"], "navali": ["Antwerp", "Toulon"]},
	"EN": {"citta": ["London", "Plymouth"], "navali": ["Portsmouth"]},
	"PR": {"citta": ["Berlin"], "landwehr": ["Konigsberg"]},
	"AU": {"citta": ["Vienna", "Budapest"], "landwehr": ["Prague", "Innsbruck"]},
	"RU": {"citta": ["Moscow", "St Petersburg", "Kiev"]},
	"SP": {"citta": ["Madrid"]},
}
const CAPITALI := {"FR": ["Paris"], "EN": ["London"], "PR": ["Berlin", "Konigsberg"], "AU": ["Vienna"], "RU": ["Moscow", "St Petersburg"], "SP": ["Madrid"]}

## Stati minori: città di produzione, gruppo, riserva del 1805 e aggiunte di gennaio
const MINORI := {
	"H": {"citta": ["Amsterdam"], "gruppo": "ovest"},
	"Pt": {"citta": ["Lisbon"], "gruppo": "ovest"},
	"I": {"citta": ["Milan"], "gruppo": "italia"},
	"N": {"citta": ["Florence"], "gruppo": "italia"},
	"Da": {"citta": ["Trieste"], "gruppo": "italia"},
	"Sz": {"citta": ["Geneva"], "gruppo": "italia"},
	"B": {"citta": ["Munich"], "gruppo": "germania"},
	"Br": {"citta": ["Brunswick"], "gruppo": "germania"},
	"Ha": {"citta": ["Hanover"], "gruppo": "germania"},
	"He": {"citta": ["Cassel"], "gruppo": "germania"},
	"R": {"citta": ["Frankfurt"], "gruppo": "germania"},
	"S": {"citta": ["Dresden"], "gruppo": "germania"},
	"W": {"citta": ["Cassel"], "gruppo": "germania"},
	"Wu": {"citta": ["Stuttgart"], "gruppo": "germania"},
	"D": {"citta": ["Copenhagen"], "gruppo": "baltico"},
	"Po": {"citta": ["Warsaw"], "gruppo": "baltico"},
	"Sw": {"citta": ["Stockholm"], "gruppo": "baltico"},
}
const GRUPPI := {"ovest": ["H", "Pt"], "italia": ["I", "N", "Da", "Sz"], "germania": ["B", "Br", "Ha", "He", "R", "S", "W", "Wu"], "baltico": ["D", "Po", "Sw"]}
const NOMI_GRUPPI := {"ovest": "stati occidentali", "italia": "stati italiani", "germania": "stati tedeschi", "baltico": "stati baltici"}
## Minori che solo la Francia può creare (GCG H.1)
const DA_CREARE := ["Da", "N", "Po", "R", "W"]

## Aggiunte di gennaio alle riserve (Force Pool Display): anno -> [chiave riserva o "capo:NOME", quantità]
const GENNAIO := {
	"FR": {1806: [["capo:Eugene", 1], ["capo:Murat", 1], ["capo:@0", 1]], 1807: [["capo:Bessieres", 1], ["capo:Victor", 1], ["capo:@0", 1], ["GC", 1]],
		1808: [["capo:Jerome", 1], ["capo:Joseph", 1], ["capo:@0", 1], ["GI", 1]], 1809: [["I", 1]], 1810: [["I", 1]], 1811: [["I", 1]],
		1812: [["capo:@0", 1], ["GI", 4]], 1813: [["capo:@0", 1], ["GI", 3]], 1814: [["I", 3]]},
	"EN": {1806: [["capo:Uxbridge", 1], ["I", 1], ["K:I", 1]], 1807: [["capo:Moore", 1], ["I", 1], ["K:I", 1]],
		1808: [["capo:Wellington", 1], ["capo:Beresford", 1], ["capo:Hill", 1], ["I", 1]],
		1809: [["I", 1]], 1810: [["I", 1]], 1811: [["I", 1]], 1812: [["I", 1]], 1813: [["I", 1]], 1814: [["I", 1]]},
	"PR": {1806: [["capo:@0", 1], ["I", 1]], 1807: [["capo:Blucher", 1], ["I", 1]], 1808: [["capo:@0", 1], ["I", 1]], 1809: [["I", 1]], 1810: [["I", 1]],
		1811: [["capo:Bulow", 1], ["capo:Yorck", 1], ["I", 1]], 1812: [["capo:Kleist", 1], ["I", 1]], 1813: [["I", 1]], 1814: [["I", 1]]},
	"AU": {1806: [["I", 1]], 1807: [["capo:@0", 4], ["I", 1]], 1808: [["I", 1]], 1809: [["capo:Louis", 1], ["capo:@0", 2], ["I", 1]],
		1810: [["capo:Schwarzenberg", 1], ["capo:Bellegarde", 1], ["capo:@0", 1], ["I", 1]], 1811: [["I", 1]], 1812: [["I", 1]], 1813: [["I", 1]], 1814: [["I", 1]]},
	"RU": {1806: [["I", 6], ["C", 1]], 1807: [["capo:@0", 1], ["I", 6], ["C", 1]], 1809: [["capo:@0", 1], ["I", 5], ["GI", 1]],
		1812: [["capo:Docturov", 1], ["capo:Wittgenstein", 1], ["I", 1]], 1813: [["GI", 1]]},
	"SP": {1806: [["I", 1]], 1807: [["I", 1]], 1808: [["I", 1]], 1809: [["I", 1]], 1810: [["I", 1]], 1811: [["I", 1]], 1812: [["I", 1]], 1813: [["I", 1]], 1814: [["I", 1]]},
}
const GENNAIO_MINORI := {
	"H": {1806: [["C", 1]], 1807: [["I", 1]], 1808: [["I", 1]], 1809: [["I", 1]], 1810: [["I", 1]], 1811: [["I", 1]], 1812: [["I", 1]]},
	"Pt": {1806: [["I", 1]], 1807: [["I", 1]], 1808: [["I", 1]], 1809: [["I", 1]], 1810: [["I", 1]]},
	"I": {1806: [["I", 1]], 1807: [["I", 1]], 1808: [["I", 1]], 1809: [["I", 1]]},
	"N": {1806: [["I", 1]], 1807: [["I", 1]], 1808: [["I", 1]], 1809: [["I", 1]], 1810: [["I", 1]], 1811: [["I", 1]], 1812: [["C", 1]]},
	"Sz": {1806: [["I", 1]], 1807: [["I", 1]], 1808: [["I", 1]], 1809: [["I", 1]], 1810: [["I", 1]]},
	"B": {1807: [["I", 1]], 1808: [["I", 1]], 1809: [["I", 1]], 1810: [["I", 1]]},
	"R": {1807: [["I", 1]], 1808: [["I", 1]], 1809: [["I", 1]], 1810: [["I", 1]], 1811: [["I", 1]], 1812: [["I", 1]]},
	"W": {1806: [["I", 1]], 1807: [["I", 1]]},
	"Wu": {1806: [["I", 1]], 1807: [["I", 1]], 1808: [["I", 1]], 1809: [["I", 1]]},
	"Po": {1807: [["I", 1]], 1808: [["I", 1]], 1809: [["I", 1]], 1810: [["I", 1]], 1811: [["I", 1]], 1812: [["I", 1]], 1813: [["I", 1]], 1814: [["I", 1]]},
}

## Costo in punti produzione per punto forza
const COSTI := {"S": 5.0, "T": 5.0, "GC": 3.0, "GI": 2.0, "C": 2.0, "I": 1.0, "CC": 1.0, "L": 0.5, "M": 0.5, "P": 0.5}

# =============================================================================================
# Preparazione

static func prepara(m: Motore) -> void:
	var s: Dictionary = m.s
	s["camp"] = {
		"pol": {"FR": "pro", "SP": "pro", "EN": "anti", "AU": "anti", "RU": "anti", "PR": "neutro"},
		"minori": {"B": "pro", "H": "pro", "I": "pro", "Sz": "pro", "Wu": "pro", "R": "pro", "Pt": "anti",
			"Br": "neutro", "He": "neutro", "S": "neutro", "D": "neutro", "Sw": "neutro",
			"Da": "nonformato", "N": "nonformato", "Po": "nonformato", "W": "nonformato", "Ha": "nonformato"},
		"conq": {}, "in_conquista": {}, "fonti": {}, "capi_pool": {"FR": [], "EN": [], "AU": [], "PR": [], "RU": [], "SP": []},
		"acc": {"EN": 0.0, "FRn": 0.0, "ENn": 0.0}, "guerre": {}, "spagna": -1, "prussia": -1, "tilsit": -1,
		"polonia": "", "esilio": -1, "napoleone_tornato": false, "inv_spagna": -1, "inv_russia": -1,
		"spagna_fr": 0, "storia": [],
	}
	# riserve del 1805
	var pool := {"FR||I": 30, "FR||C": 4, "EN||I": 6, "EN||L": 1, "EN||M": 2, "EN||C": 1, "PR||I": 12, "PR||C": 7,
		"AU||I": 20, "RU||I": 21, "RU||C": 2, "RU||CC": 5, "FR|N|I": 4, "FR|Da|I": 2, "FR|W|I": 3, "FR|W|C": 1, "FR|Po|I": 3, "FR|Po|C": 3}
	for k in pool:
		s["pool"][k] = int(s["pool"].get(k, 0)) + int(pool[k])
	s["camp"]["capi_pool"]["FR"].append("Poniatowski")
	# città dei neutrali: nessuno le controlla
	for h in Mappa.esagoni:
		if Mappa.ha_citta(h) and Mappa.area(h) in [1, 2, 3, 4] and Mappa.stato(h) in ["PR", "S", "He", "Br", "D", "Sw", "N"]:
			if m.sp_in(h, 0) == 0 and m.sp_in(h, 1) == 0:
				s["controllo"][h] = 2
	_annota(m, "Francia e Spagna contro Inghilterra, Austria e Russia; la Prussia è neutrale")

static func _annota(m: Motore, t: String) -> void:
	m._log("[b]%s[/b]" % t)
	m.s["camp"]["storia"].append("%s %d: %s" % [Dati.MESI[int(m.s["mese"])], int(m.s["anno"]), t])
	m.eventi.append({"k": "annuncio", "t": t})

static func stato(m: Motore, naz: String) -> String:
	if m.s["camp"]["pol"].has(naz):
		return str(m.s["camp"]["pol"][naz])
	return str(m.s["camp"]["minori"].get(naz, "neutro"))

static func lato_stato(st: String) -> int:
	return 0 if st == "pro" else (1 if st == "anti" else 2)

static func conquiste(m: Motore, naz: String) -> int:
	return int(m.s["camp"]["conq"].get(naz, 0))

# =============================================================================================
# Cambi di stato politico

## Una potenza maggiore cambia schieramento: "pro", "anti" o "neutro"
static func cambia(m: Motore, naz: String, nuovo: String, perche: String) -> void:
	var s: Dictionary = m.s
	var prima := stato(m, naz)
	if prima == nuovo:
		return
	s["camp"]["pol"][naz] = nuovo
	var nomi := {"pro": "si schiera con la Francia", "anti": "si unisce alla Coalizione", "neutro": "diventa neutrale"}
	if naz == "FR":
		nomi["pro"] = "torna in guerra"
	_annota(m, "%s %s%s" % [Dati.NAZ[naz]["nome"], nomi[nuovo], (" (" + perche + ")") if perche != "" else ""])
	if nuovo == "neutro":
		if not naz in s["neutrali"]:
			s["neutrali"].append(naz)
		_rimpatria(m, naz)
		for h in Mappa.esagoni:
			if Mappa.ha_citta(h) and Mappa.stato(h) == naz and m.sp_in(h, 0) == 0 and m.sp_in(h, 1) == 0:
				s["controllo"][h] = 2
	else:
		s["neutrali"].erase(naz)
		var l := lato_stato(nuovo)
		s["lati_x"][naz] = l
		for h in Mappa.esagoni:
			if Mappa.ha_citta(h) and Mappa.stato(h) == naz and m.sp_in(h, 1 - l) == 0 and int(s["controllo"].get(h, -1)) != 1 - l:
				s["controllo"][h] = l
		# i satelliti della Prussia la seguono
		if naz == "PR":
			for sub in ["Br", "He", "S"]:
				if s["camp"]["minori"].get(sub, "") == "neutro":
					_minore(m, sub, nuovo)
	m._aggiorna_aperti()

## Stato minore: cambia schieramento (e con esso le sue unità)
static func _minore(m: Motore, code: String, nuovo: String) -> void:
	var s: Dictionary = m.s
	var prima: String = s["camp"]["minori"].get(code, "neutro")
	if prima == nuovo:
		return
	s["camp"]["minori"][code] = nuovo
	if nuovo == "neutro":
		if not code in s["neutrali"]:
			s["neutrali"].append(code)
	else:
		s["neutrali"].erase(code)
		var l := lato_stato(nuovo)
		# le unità del minore passano alla potenza guida del nuovo schieramento
		var guida := "FR" if l == 0 else ("RU" if code == "Sw" else "EN")
		for id in s["unita"].keys():
			var u: Dictionary = s["unita"][id]
			if u["s"] == code and m.lato_di(u["n"]) != l:
				u["n"] = guida
		for id in s["navi"].keys():
			var nv: Dictionary = s["navi"][id]
			if nv["s"] == code and m.lato_di(nv["n"]) != l:
				nv["n"] = guida
		for id in s["capi"].keys():
			var c: Dictionary = s["capi"][id]
			if c["s"] == code and m.lato_di(c["n"]) != l:
				c["n"] = guida
		for nome in MINORI[code]["citta"]:
			var h := Mappa.hex(nome)
			if h != "" and m.sp_in(h, 1 - l) == 0:
				s["controllo"][h] = l
	m._log("%s: %s." % [Dati.MINORI.get(code, code), {"pro": "satellite della Francia", "anti": "con la Coalizione", "neutro": "neutrale"}[nuovo]])

## Le truppe di una potenza diventata neutrale tornano in patria (nella città di produzione più vicina)
static func _rimpatria(m: Motore, naz: String) -> void:
	var s: Dictionary = m.s
	var casa := []
	for nome in PRODUZIONE.get(naz, {}).get("citta", []) + CAPITALI.get(naz, []):
		var h := Mappa.hex(nome)
		if h != "" and m.sp_in(h, 0) == 0 and m.sp_in(h, 1) == 0:
			casa.append(h)
	for id in s["unita"].keys():
		var u: Dictionary = s["unita"][id]
		if u["n"] != naz or u["h"] == "" or Mappa.stato(u["h"]) == naz:
			continue
		if casa.is_empty():
			m._al_pool(u, int(u["sp"]))
			s["unita"].erase(id)
			continue
		var best: String = casa[0]
		for h in casa:
			if Mappa.distanza(u["h"], h, 40) < Mappa.distanza(u["h"], best, 40):
				best = h
		u["h"] = best
		u["in"] = false
	for id in s["capi"]:
		var c: Dictionary = s["capi"][id]
		if c["n"] == naz and c["h"] != "" and Mappa.stato(c["h"]) != naz and not casa.is_empty():
			c["h"] = casa[0]

# =============================================================================================
# Inizio del segmento: gennaio, guerre lontane, Prussia, Spagna, minori, produzione

static func inizio_segmento(m: Motore) -> void:
	var s: Dictionary = m.s
	var l := int(s["lato"])
	if int(s["mese"]) == 0:
		if l == 0:
			_gennaio(m)
			_guerre_lontane(m)
	_guerre_in_corso(m, l)
	if l == 0:
		_crea_minori(m)
		_esilio(m)
		if int(s["anno"]) == 1810 and int(s["mese"]) == 7:
			_bernadotte(m)
	else:
		_prussia(m)
		_spagna(m)
		_tilsit_scadenza(m)
	_aggiorna_minori(m)
	_asse_francese(m)
	_produzione_lato(m, l)
	if l == 1:
		_ricostruzione(m)
	_chiedi_alleanze(m, l)

## Gennaio: aggiunte alle riserve di tutte le potenze
static func _gennaio(m: Motore) -> void:
	var s: Dictionary = m.s
	var anno := int(s["anno"])
	for naz in GENNAIO:
		for voce in GENNAIO[naz].get(anno, []):
			_aggiungi(m, naz, "", str(voce[0]), int(voce[1]))
	for code in GENNAIO_MINORI:
		for voce in GENNAIO_MINORI[code].get(anno, []):
			var naz := "FR" if s["camp"]["minori"].get(code, "") != "anti" else "EN"
			if code == "Pt":
				naz = "EN" if s["camp"]["minori"].get("Pt", "") != "pro" else "FR"
			_aggiungi(m, naz, code, str(voce[0]), int(voce[1]))
	# l'Austria conquistata una volta aggiunge una cavalleria ogni anno
	if conquiste(m, "AU") >= 1:
		_aggiungi(m, "AU", "", "C", 1)
	m._log("Gennaio %d: nuove truppe nelle riserve." % anno)

static func _aggiungi(m: Motore, naz: String, sub: String, voce: String, n: int) -> void:
	if voce.begins_with("capo:"):
		for i in n:
			m.s["camp"]["capi_pool"][naz].append(voce.substr(5))
		return
	var t := voce
	if ":" in voce:
		sub = voce.split(":")[0]
		t = voce.split(":")[1]
	var k := "%s|%s|%s" % [naz, sub, t]
	m.s["pool"][k] = int(m.s["pool"].get(k, 0)) + n

## Gennaio, fase delle alleanze francese: guerra anglo-americana e russo-turca
static func _guerre_lontane(m: Motore) -> void:
	var s: Dictionary = m.s
	var g: Dictionary = s["camp"]["guerre"]
	var t1 := m.dado()
	var t2 := m.dado()
	if t1 == 1 and not g.has("america") and not s["camp"].has("america_finita"):
		g["america"] = {"naz": "EN", "via": {"I": 4, "S": 2, "T": 2}, "capi2": false}
		_annota(m, "L'Inghilterra è in guerra con gli Stati Uniti: 4 PF e quattro navi lasciano l'Europa")
		_ritira_per_guerra(m, "america")
	if t2 == 1 and not g.has("turchia"):
		g["turchia"] = {"naz": "RU", "via": {"I": 10, "C": 4}, "capi2": true}
		_annota(m, "La Russia è in guerra con la Turchia: 14 PF e un capo da 2 partono per il sud")
		_ritira_per_guerra(m, "turchia")

static func _ritira_per_guerra(m: Motore, k: String) -> void:
	var s: Dictionary = m.s
	var g: Dictionary = s["camp"]["guerre"][k]
	var naz: String = g["naz"]
	var tolti := {}
	for t in g["via"]:
		var resto := int(g["via"][t])
		var tipi := [t] if t != "C" else ["C", "CC"]
		# prima dalla riserva, poi dalla mappa (lontano dal nemico)
		for tt in tipi:
			var k2 := "%s||%s" % [naz, tt]
			var dal_pool := mini(resto, int(s["pool"].get(k2, 0)))
			s["pool"][k2] = int(s["pool"].get(k2, 0)) - dal_pool
			resto -= dal_pool
		if t in ["S", "T"]:
			for id in s["navi"].keys():
				if resto > 0 and s["navi"][id]["n"] == naz and s["navi"][id]["s"] == "" and s["navi"][id]["t"] == t:
					s["navi"].erase(id)
					resto -= 1
		else:
			for id in s["unita"].keys():
				var u: Dictionary = s["unita"][id]
				if resto <= 0:
					break
				if u["n"] == naz and u["s"] == "" and u["t"] in tipi and not (u["in"] and s["assedi"].has(u["h"])):
					var n := mini(resto, int(u["sp"]))
					u["sp"] = int(u["sp"]) - n
					resto -= n
					if int(u["sp"]) <= 0:
						s["unita"].erase(id)
		tolti[t] = int(g["via"][t]) - resto
	g["tolti"] = tolti
	if g["capi2"]:
		for id in s["capi"]:
			var c: Dictionary = s["capi"][id]
			if c["n"] == naz and int(c["v"]) == 2 and c["h"] != "":
				c["h"] = ""
				c["ritirato"] = true
				g["capo"] = id
				break

## Ogni turno di guerra: con 12 su due dadi la guerra finisce e le truppe tornano
static func _guerre_in_corso(m: Motore, l: int) -> void:
	var s: Dictionary = m.s
	var g: Dictionary = s["camp"]["guerre"]
	for k in g.keys():
		var naz: String = g[k]["naz"]
		if m.lato_di(naz) != l and not (naz in s["neutrali"]):
			continue
		if int(g[k].get("dal", -1)) == int(s["turno"]):
			continue
		var t := m.dado() + m.dado()
		if t < 12:
			continue
		for t2 in g[k].get("tolti", {}):
			_aggiungi(m, naz, "", t2, int(g[k]["tolti"][t2]))
		if g[k].has("capo") and s["capi"].has(g[k]["capo"]):
			s["capi"][g[k]["capo"]].erase("ritirato")
			s["capi"][g[k]["capo"]]["h"] = Mappa.hex(CAPITALI[naz][0])
		g.erase(k)
		if k == "america":
			s["camp"]["america_finita"] = true
		_annota(m, "Finisce la guerra %s: le truppe tornano nelle riserve" % ("con gli Stati Uniti" if k == "america" else ("con la Turchia" if k == "turchia" else "con la Svezia")))

## Agosto 1810: Bernadotte diventa principe ereditario di Svezia
static func _bernadotte(m: Motore) -> void:
	var s: Dictionary = m.s
	for id in s["capi"]:
		var c: Dictionary = s["capi"][id]
		if c["nome"] == "Bernadotte" and c["n"] == "FR" and not c["morto"]:
			c["h"] = ""
			c["morto"] = true
			m._nuovo_capo("RU", "Bernadotte", Mappa.hex("Stockholm"), "Sw")
			if s["camp"]["minori"].get("Sw", "") == "neutro":
				for id2 in s["capi"]:
					if s["capi"][id2]["nome"] == "Bernadotte" and s["capi"][id2]["s"] == "Sw":
						pass
			_annota(m, "Bernadotte lascia la Francia e diventa principe ereditario di Svezia")
			return

# ---------- Prussia (GCG M.2)

static func _prussia(m: Motore) -> void:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	if c.get("prussia_guerra", false) or stato(m, "PR") != "neutro" or conquiste(m, "PR") > 0:
		return
	var maggio_1806 := 9
	var dopo_austria := int(c.get("prima_austria", 999)) + 3
	if int(s["turno"]) < mini(maggio_1806, dopo_austria):
		return
	var n := int(c.get("prussia_tiri", 0)) + 1
	c["prussia_tiri"] = n
	var t := m.dado() + m.dado()
	if t <= n + 1:
		c["prussia_guerra"] = true
		cambia(m, "PR", "anti", "dichiara guerra alla Francia")
	else:
		m._log("La Prussia esita (dadi %d, serve %d o meno)." % [t, n + 1])

# ---------- Spagna (GCG L.1, N.1)

static func pro_fr_in_spagna(m: Motore) -> int:
	var n := 0
	for u in m.s["unita"].values():
		if u["h"] != "" and Mappa.stato(u["h"]) == "SP" and u["n"] != "SP" and u["s"] != "Sp" and m.lato_unita(u) == 0:
			n += int(u["sp"])
	return n

static func _spagna(m: Motore) -> void:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	if stato(m, "SP") != "pro":
		return
	var attiva := int(c["spagna"]) >= 0
	if not attiva:
		var luglio_1807 := 23
		if int(s["turno"]) > luglio_1807 or (conquiste(m, "AU") > 0 and conquiste(m, "PR") > 0):
			var squadre := 0
			for k in ["SP||S"]:
				squadre += int(s["pool"].get(k, 0))
			c["spagna"] = clampi(12 - squadre - pro_fr_in_spagna(m) / 10, 0, 12)
			c["spagna_fr"] = pro_fr_in_spagna(m) / 10
			m._log("Comincia la crisi spagnola: indicatore a %d." % int(c["spagna"]))
		return
	var dieci := pro_fr_in_spagna(m) / 10
	var v := int(c["spagna"]) - 1 - (dieci - int(c["spagna_fr"]))
	c["spagna_fr"] = dieci
	c["spagna"] = clampi(v, 0, 12)
	if int(c["spagna"]) <= 0:
		cambia(m, "SP", "anti", "il popolo insorge contro i Francesi")
		_invasione_spagna(m)
	else:
		m._log("Crisi spagnola: indicatore a %d." % int(c["spagna"]))

static func _invasione_spagna(m: Motore) -> void:
	var c: Dictionary = m.s["camp"]
	if int(c["inv_spagna"]) < 0 and pro_fr_in_spagna(m) > 0:
		c["inv_spagna"] = int(m.s["turno"])
		_aggiungi(m, "SP", "", "M", 10)
		_aggiungi(m, "SP", "", "P", 6)
		c["capi_pool"]["SP"].append_array(["Cuesta", "Pallafox"])
		_annota(m, "I Francesi invadono la Spagna")

## Controlli dopo il movimento: invasioni di neutrali, della Spagna e della Russia
static func dopo_movimento(m: Motore) -> void:
	var s: Dictionary = m.s
	var l := int(s["lato"])
	var c: Dictionary = s["camp"]
	# Spagna alleata: più di 20 PF francesi o a sud della riga di Madrid è un'invasione
	if l == 0 and stato(m, "SP") == "pro":
		var sud := false
		var riga_madrid := int(Mappa.hex("Madrid").split(",")[0])
		var gib := Mappa.hex("Gibraltar")
		for u in s["unita"].values():
			if u["h"] != "" and Mappa.stato(u["h"]) == "SP" and u["n"] != "SP" and m.lato_unita(u) == 0:
				if int(str(u["h"]).split(",")[0]) >= riga_madrid and not Mappa.adiacenti(u["h"], gib):
					sud = true
		if pro_fr_in_spagna(m) > 20 or sud:
			cambia(m, "SP", "anti", "invasa dai Francesi")
			_invasione_spagna(m)
	if l == 0 and stato(m, "SP") == "anti":
		_invasione_spagna(m)
	# Russia: una città maggiore russa francese prima del 1810, o 25 PF in Russia dopo
	if l == 0 and int(c["inv_russia"]) < 0:
		var inv := false
		if int(s["anno"]) < 1810:
			for h in Mappa.esagoni:
				if Mappa.citta_maggiore(h) and Mappa.stato(h) == "RU" and m.controllore(h) == 0:
					inv = true
		else:
			var n := 0
			for u in s["unita"].values():
				if u["h"] != "" and Mappa.stato(u["h"]) == "RU" and m.lato_unita(u) == 0:
					n += int(u["sp"])
			inv = n >= 25
		if inv:
			c["inv_russia"] = int(s["turno"])
			_annota(m, "La Grande Armée invade la Russia")
			if stato(m, "RU") != "anti":
				cambia(m, "RU", "anti", "invasa")
	# invasione di neutrali: la potenza invasa passa con l'altro schieramento
	var invasi := {}
	for u in s["unita"].values():
		if u["h"] == "" or m.lato_unita(u) != l:
			continue
		var st := Mappa.stato(u["h"])
		if st == u["n"] or st == u["s"]:
			continue
		if st in MAGGIORI and stato(m, st) == "neutro" and not c["in_conquista"].has(st):
			invasi[st] = true
		elif MINORI.has(st) and str(c["minori"].get(st, "")) == "neutro":
			invasi[st] = true
		elif st in MAGGIORI and stato(m, st) == "neutro" and c["in_conquista"].has(st) and l == 1 and str(c["in_conquista"][st]) == "0" and int(s["turno"]) > int(c.get("conq_turno", {}).get(st, -9)) + 1:
			# una potenza conquistata dalla Francia, invasa dalla Coalizione, si difende con la Francia
			invasi[st] = true
	for st in invasi:
		var chi := ""
		for u in s["unita"].values():
			if u["h"] != "" and m.lato_unita(u) == l and Mappa.stato(u["h"]) == st:
				chi = "%s %s a %s" % [u["n"], u["t"], Mappa.nome(u["h"])]
				break
		m._log("Invasione di %s: %s." % [st, chi])
		var nuovo := "anti" if l == 0 else "pro"
		if st in MAGGIORI:
			if st == "RU" and nuovo == "pro":
				continue
			cambia(m, st, nuovo, "invasa")
		else:
			_minore(m, st, nuovo)
			m._log("%s è invasa e si schiera contro l'invasore." % Dati.MINORI.get(st, st))

# =============================================================================================
# Stati minori: creazione (GCG H) e schieramento secondo la città di produzione (G.4.a)

static func _crea_minori(m: Motore) -> void:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	var fr_in := func(nome: String) -> bool:
		var h := Mappa.hex(nome)
		for u in m.unita_in(h, 0):
			if s["unita"][u]["n"] == "FR" and s["unita"][u]["s"] == "":
				return true
		return false
	var crea := func(code: String, perche: String) -> void:
		c["minori"][code] = "pro"
		s["neutrali"].erase(code)
		for nome in MINORI[code]["citta"]:
			s["controllo"][Mappa.hex(nome)] = 0
		_annota(m, "Nasce %s, satellite della Francia (%s)" % [Dati.MINORI[code], perche])
	if c["minori"]["Da"] == "nonformato" and fr_in.call("Trieste"):
		crea.call("Da", "i Francesi a Trieste")
	if c["minori"]["N"] == "nonformato" and fr_in.call("Florence"):
		crea.call("N", "i Francesi a Firenze")
	if c["minori"]["W"] == "nonformato" and fr_in.call("Brunswick") and fr_in.call("Cassel"):
		crea.call("W", "i Francesi a Brunswick e Kassel")
	if c["minori"]["R"] == "pro" and not c.get("reno", false) and fr_in.call("Frankfurt") and (conquiste(m, "AU") > 0 or conquiste(m, "PR") > 0):
		c["reno"] = true
		_annota(m, "Nasce la Confederazione del Reno")
	if c["polonia"] == "" and m.controllore(Mappa.hex("Warsaw")) == 0 and conquiste(m, "AU") > 0 and conquiste(m, "PR") > 0:
		_chiedi(m, 0, "polonia", "La questione polacca: Varsavia è francese e Austria e Prussia sono state vinte. Che cosa fai della Polonia?",
			["granducato", "regno", "nessuna"], ["Il Granducato di Varsavia", "Il Regno di Polonia", "Nessuna Polonia"])

## Lo schieramento di un minore segue chi tiene la sua città di produzione
static func _aggiorna_minori(m: Motore) -> void:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	for code in MINORI:
		var st: String = c["minori"].get(code, "neutro")
		if st == "nonformato" or (code in ["D", "Sw"] and st == "neutro"):
			continue
		var h := Mappa.hex(MINORI[code]["citta"][0])
		if h == "":
			continue
		var ctl := m.controllore(h)
		if code in ["Br", "He", "S"] and stato(m, "PR") == "neutro" and st == "neutro":
			continue
		# la Baviera è satellite francese anche se Monaco all'inizio è austriaca
		if code == "B" and ctl == 0:
			c["monaco_fr"] = true
		if code == "B" and ctl == 1 and not c.get("monaco_fr", false):
			continue
		if ctl == 0 and st != "pro":
			_conquista_minore(m, code, "pro")
		elif ctl == 1 and st != "anti":
			_conquista_minore(m, code, "anti")

## Conquista di un minore (GCG I.3): la riserva passa al vincitore; con un dado 4+ anche le truppe
## sulla mappa cambiano bandiera, altrimenti tornano nella riserva del vincitore
static func _conquista_minore(m: Motore, code: String, nuovo: String) -> void:
	var s: Dictionary = m.s
	var l := lato_stato(nuovo)
	var guida := "FR" if l == 0 else "EN"
	for k in s["pool"].keys():
		var p: PackedStringArray = str(k).split("|")
		if p[1] == code and p[0] != guida and int(s["pool"][k]) > 0:
			var k2 := "%s|%s|%s" % [guida, code, p[2]]
			s["pool"][k2] = int(s["pool"].get(k2, 0)) + int(s["pool"][k])
			s["pool"][k] = 0
	var t := m.dado()
	var resta_sulla_mappa: bool = code in ["I", "Po", "Pt", "Sp"] or (code == "B" and conquiste(m, "AU") == 0)
	if not resta_sulla_mappa:
		for id in s["unita"].keys():
			var u: Dictionary = s["unita"][id]
			if u["s"] == code and m.lato_di(u["n"]) != l:
				if t >= 4:
					u["n"] = guida
				else:
					var k3 := "%s|%s|%s" % [guida, code, u["t"]]
					s["pool"][k3] = int(s["pool"].get(k3, 0)) + int(u["sp"])
					s["unita"].erase(id)
	s["camp"]["minori"][code] = nuovo
	s["neutrali"].erase(code)
	m._log("%s passa %s." % [Dati.MINORI.get(code, code), "alla Francia" if l == 0 else "alla Coalizione"])

# =============================================================================================
# Conquista delle potenze maggiori (GCG I)

static func citta_chiave(m: Motore, naz: String) -> Array:
	var out := []
	var nomi: Array = CAPITALI.get(naz, []).duplicate()
	nomi.append_array(PRODUZIONE.get(naz, {}).get("citta", []))
	if naz == "AU" and int(m.s["anno"]) * 12 + int(m.s["mese"]) >= 1808 * 12 + 5:
		nomi.append_array(PRODUZIONE["AU"]["landwehr"])
	if naz == "RU" and m.s["camp"]["guerre"].has("turchia"):
		pass
	for nome in nomi:
		var h := Mappa.hex(nome)
		if h != "" and not h in out:
			out.append(h)
	return out

## Controllo delle conquiste (a fine combattimento e a fine movimento)
static func controlla_conquiste(m: Motore) -> void:
	var s: Dictionary = m.s
	for naz in MAGGIORI:
		var st := stato(m, naz)
		if st == "neutro":
			continue
		var l := lato_stato(st)
		var vinto := false
		match naz:
			"FR":
				var parigi := Mappa.hex("Paris")
				m.calcola_rifornimento(1)
				for id in m.unita_in(parigi, 1):
					var u: Dictionary = s["unita"][id]
					if m.rifornita(u, 1) and not (s["assedi"].has(parigi) and int(s["assedi"][parigi]["lato"]) == 0):
						vinto = true
			"EN", "SP":
				vinto = true
				var una := false
				for h in Mappa.esagoni:
					if Mappa.ha_citta(h) and Mappa.stato(h) == naz and Mappa.area(h) in [1, 2, 3, 4]:
						una = true
						if m.sp_in(h, 1 - l) == 0:
							vinto = false
				vinto = vinto and una
			_:
				vinto = true
				for h in citta_chiave(m, naz):
					if m.controllore(h) != 1 - l:
						vinto = false
		if vinto:
			_conquistata(m, naz, 1 - l)

static func _conquistata(m: Motore, naz: String, vincitore: int) -> void:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	c["conq"][naz] = conquiste(m, naz) + 1
	if naz == "AU" and not c.has("prima_austria"):
		c["prima_austria"] = int(s["turno"])
	c["in_conquista"][naz] = str(vincitore)
	if not c.has("conq_turno"):
		c["conq_turno"] = {}
	c["conq_turno"][naz] = int(s["turno"])
	_annota(m, "%s è conquistata %s (volta %d)" % [Dati.NAZ[naz]["nome"], "dalla Francia" if vincitore == 0 else "dalla Coalizione", conquiste(m, naz)])
	s["pv"] = [0, 0]
	if naz == "FR":
		_esilio_inizio(m)
	# le truppe fuori dai confini tornano nella riserva
	for id in s["unita"].keys():
		var u: Dictionary = s["unita"][id]
		if u["n"] == naz and u["s"] == "" and u["h"] != "" and Mappa.stato(u["h"]) != naz:
			m._al_pool(u, int(u["sp"]))
			s["unita"].erase(id)
	for id in s["capi"]:
		var cp: Dictionary = s["capi"][id]
		if cp["n"] == naz and cp["s"] == "" and cp["h"] != "" and Mappa.stato(cp["h"]) != naz:
			cp["h"] = ""
			cp["fuori"] = int(s["turno"]) + 1
	# le città tenute dal vincitore diventano sue fonti di rifornimento; le capitali vanno lasciate
	for h in Mappa.esagoni:
		if not Mappa.ha_citta(h) or Mappa.stato(h) != naz:
			continue
		if m.controllore(h) == vincitore:
			c["fonti"][h] = vincitore
		var capitale: bool = Mappa.nome_citta(h) in CAPITALI.get(naz, [])
		if capitale and naz != "FR":
			for id in m.unita_in(h, vincitore):
				var dest := m._dest_ritirata(h, vincitore)
				if dest != "":
					s["unita"][id]["h"] = dest
			for id in m.capi_in(h, vincitore):
				var dest2 := m._dest_ritirata(h, vincitore)
				if dest2 != "":
					s["capi"][id]["h"] = dest2
			s["controllo"][h] = 2
	cambia(m, naz, "neutro", "")
	# le unità rimaste in patria diventano neutrali e non subiscono logoramento
	if naz == "AU" and conquiste(m, "AU") == 1:
		c["austria_rivincita"] = true

## Potenze conquistate: ricostruiscono con la loro produzione; a riserva vuota tornano libere
static func _ricostruzione(m: Motore) -> void:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	for naz in c["in_conquista"].keys():
		if naz == "FR":
			continue
		_produzione_naz(m, naz, 2)
		if _riserva_terrestre(m, naz) > 0:
			continue
		c["in_conquista"].erase(naz)
		m._log("%s ha ricostruito il suo esercito." % Dati.NAZ[naz]["nome"])
		if naz == "AU" and c.get("austria_rivincita", false):
			c.erase("austria_rivincita")
			cambia(m, "AU", "anti", "dopo la ricostruzione dichiara guerra alla Francia")
		if naz == "RU" and c.get("russia_mai_pro", false):
			pass

static func _riserva_terrestre(m: Motore, naz: String) -> int:
	var n := 0
	for k in m.s["pool"]:
		var p: PackedStringArray = str(k).split("|")
		if p[0] == naz and p[1] == "" and not p[2] in ["S", "T"]:
			n += int(m.s["pool"][k])
	return n

## IA: la Grande Armée marcia sulla città chiave più vicina della potenza nemica da abbattere
static func _asse_francese(m: Motore) -> void:
	var nap := ""
	for id in m.s["capi"]:
		if m.s["capi"][id]["nome"] == "Napoleon" and m.s["capi"][id]["h"] != "":
			nap = m.s["capi"][id]["h"]
	var best := ""
	var bd := 999
	if nap != "":
		for naz in ["AU", "PR", "RU", "SP"]:
			if stato(m, naz) != "anti":
				continue
			for h in citta_chiave(m, naz):
				if m.controllore(h) == 0:
					continue
				var d := Mappa.distanza(nap, h, 60)
				if d < bd:
					bd = d
					best = h
	if not m.scen.has("ia"):
		m.scen["ia"] = {}
	if best == "":
		m.scen["ia"].erase("asse")
	else:
		m.scen["ia"]["asse"] = {"lato": 0, "naz": ["FR"], "raduno": Mappa.nome_citta(best), "parti": 0, "obiettivo": Mappa.nome_citta(best)}

# =============================================================================================
# Produzione (GCG J)

static func citta_produzione(m: Motore, naz: String, l: int) -> Array:
	var out := []
	var nomi: Array = PRODUZIONE.get(naz, {}).get("citta", []).duplicate()
	for nome in nomi:
		var h := Mappa.hex(nome)
		if h != "" and m.controllore(h) != 1 - l and m.sp_in(h, 1 - l) == 0:
			out.append(h)
	if naz == "FR":
		# Parigi e altre tre città maggiori francesi a scelta
		var altre := []
		for h in Mappa.esagoni:
			if Mappa.citta_maggiore(h) and Mappa.stato(h) == "FR" and not Mappa.nome_citta(h) in ["Paris", "Brussels", "Antwerp"] and m.controllore(h) == l and m.sp_in(h, 1 - l) == 0:
				altre.append(h)
		altre.sort_custom(func(a, b): return _vicinanza_nemico(m, a, l) < _vicinanza_nemico(m, b, l))
		out.append_array(altre.slice(0, 3))
	return out

static func _vicinanza_nemico(m: Motore, h: String, l: int) -> int:
	var best := 99
	for h2 in m.esagoni_di(1 - l):
		best = mini(best, Mappa.distanza(h, h2, 12))
	return best

static func _produzione_lato(m: Motore, l: int) -> void:
	for naz in MAGGIORI:
		if stato(m, naz) == ("pro" if l == 0 else "anti") and not m.s["camp"]["in_conquista"].has(naz):
			_produzione_naz(m, naz, l)
	_produzione_minori(m, l)

## Un dado: 5 o meno un punto per città di produzione, 6 o più due punti
static func _dado_produzione(m: Motore, naz: String) -> int:
	var s: Dictionary = m.s
	var t := m.dado()
	if naz == "FR" and m._capo_in_citta("Napoleon", "Paris"):
		if int(s["camp"]["inv_russia"]) >= 0:
			t += 1
		elif int(s["mese"]) in [0, 6]:
			t += 3
	if naz == "RU":
		var n := 0
		for u in s["unita"].values():
			if u["h"] != "" and Mappa.area(u["h"]) == 4 and m.lato_unita(u) == 0:
				n += int(u["sp"])
		if n >= 20:
			t += 1
	if naz == "EN" and m.controllore(Mappa.hex("Lisbon")) == 0:
		t -= 1
	return t

static func _produzione_naz(m: Motore, naz: String, l: int) -> void:
	var s: Dictionary = m.s
	var citta := citta_produzione(m, naz, l if l < 2 else (1 if stato(m, naz) == "neutro" else lato_stato(stato(m, naz))))
	if l == 2:
		# potenza conquistata: produce dalla capitale e dalle città non occupate
		citta = []
		for nome in PRODUZIONE.get(naz, {}).get("citta", []) + CAPITALI.get(naz, []):
			var h := Mappa.hex(nome)
			if h != "" and m.sp_in(h, 0) == 0 and m.sp_in(h, 1) == 0 and not h in citta:
				citta.append(h)
	var t := _dado_produzione(m, naz)
	var per := 2 if t >= 6 else 1
	var pp := float(citta.size() * per)
	var lw := 0.0
	for nome in PRODUZIONE.get(naz, {}).get("landwehr", []):
		var h := Mappa.hex(nome)
		if h != "" and (m.controllore(h) == l or l == 2) and m.sp_in(h, 1 - mini(l, 1)) == 0:
			lw += per
	var navali := 0.0
	for nome in PRODUZIONE.get(naz, {}).get("navali", []):
		var h := Mappa.hex(nome)
		if h != "" and m.controllore(h) == l:
			navali = float(per) if naz == "EN" else 1.0
	if naz == "EN":
		pp += float(s["camp"]["acc"].get("EN", 0.0))
	var comprate := []
	# capi dalla riserva: nella capitale
	var capi: Array = s["camp"]["capi_pool"].get(naz, [])
	if not capi.is_empty() and not citta.is_empty():
		for nome in capi:
			var id := m._nuovo_capo(naz, nome, citta[0])
			if id != "":
				comprate.append(nome if nome != "@0" else "un capo")
		capi.clear()
	if citta.is_empty():
		return
	var messe := {}
	var spesa_terra := 0.0
	var limite_terra := 2.0 if naz == "EN" else 999.0
	# Landwehr (solo dalle città con il simbolo nero)
	while lw >= 0.5 and int(s["pool"].get("%s||L" % naz, 0)) > 0:
		var h := _dove(m, citta, messe, l)
		if h == "":
			break
		m._nuova_unita(naz, "", "L", 1, h)
		s["pool"]["%s||L" % naz] = int(s["pool"]["%s||L" % naz]) - 1
		messe[h] = int(messe.get(h, 0)) + 1
		lw -= 0.5
		comprate.append("L")
	# priorità: cavalleria se l'esercito ne ha poca, poi fanteria, poi Guardia, poi milizia
	var ordine := _ordine_acquisti(m, naz)
	var giro := 0
	while pp >= 0.5 and giro < 60:
		giro += 1
		var fatto := false
		for t2 in ordine:
			var k := "%s||%s" % [naz, t2]
			var costo: float = COSTI.get(t2, 1.0)
			if int(s["pool"].get(k, 0)) <= 0 or costo > pp or spesa_terra + costo > limite_terra:
				continue
			var h := _dove(m, citta, messe, l)
			if h == "":
				break
			m._nuova_unita(naz, "", t2, 1, h)
			s["pool"][k] = int(s["pool"][k]) - 1
			messe[h] = int(messe.get(h, 0)) + 1
			pp -= costo
			spesa_terra += costo
			comprate.append(t2)
			fatto = true
			break
		if not fatto:
			break
	# navi: Inghilterra e Francia accumulano i punti navali (fino a 5) e varano una squadra
	if naz in ["EN", "FR"]:
		var kacc := naz + "n"
		var acc := float(s["camp"]["acc"].get(kacc, 0.0)) + navali
		var kn := "%s||S" % naz
		if acc >= 5.0 and int(s["pool"].get(kn, 0)) > 0:
			var porto := Mappa.hex(PRODUZIONE[naz]["navali"][0])
			if naz == "FR" and m.controllore(porto) != 0:
				porto = Mappa.hex("Toulon")
			if porto != "" and m.controllore(porto) == l:
				m._nuova_nave(naz, "", "S", 1, porto, "")
				s["pool"][kn] = int(s["pool"][kn]) - 1
				acc -= 5.0
				comprate.append("una squadra navale")
		s["camp"]["acc"][kacc] = minf(acc, 5.0)
	if naz == "EN":
		s["camp"]["acc"]["EN"] = minf(pp, 5.0)
	if not comprate.is_empty():
		m._log("Produzione %s (dado %d, %d città): %s." % [Dati.NAZ[naz]["agg"], t, citta.size() + int(lw > 0), _riassunto(comprate)])

static func _riassunto(lista: Array) -> String:
	var conta := {}
	var nomi := {"I": "fanteria", "C": "cavalleria", "GI": "fanteria della Guardia", "GC": "cavalleria della Guardia", "L": "Landwehr", "M": "milizia", "P": "partigiani", "CC": "cosacchi"}
	for x in lista:
		conta[x] = int(conta.get(x, 0)) + 1
	var out := []
	for x in conta:
		if nomi.has(x):
			out.append("%d %s" % [int(conta[x]), nomi[x]])
		else:
			out.append(str(x) if int(conta[x]) == 1 else "%d × %s" % [int(conta[x]), x])
	return ", ".join(out)

static func _ordine_acquisti(m: Motore, naz: String) -> Array:
	var cav := 0
	var tot := 0
	for u in m.s["unita"].values():
		if u["n"] == naz:
			tot += int(u["sp"])
			if Dati.e_cavalleria(u["t"]):
				cav += int(u["sp"])
	if tot > 0 and cav * 6 < tot:
		return ["C", "CC", "I", "GI", "GC", "M", "P", "L"]
	return ["I", "CC", "C", "GI", "GC", "M", "P", "L"]

## Città dove mettere un nuovo punto forza: al massimo 4 per città, prima la più vicina al nemico
static func _dove(m: Motore, citta: Array, messe: Dictionary, l: int) -> String:
	var best := ""
	var bd := 999
	for h in citta:
		if int(messe.get(h, 0)) >= 4:
			continue
		var d := _vicinanza_nemico(m, h, mini(l, 1)) if l < 2 else 0
		if d < bd:
			bd = d
			best = h
	return best

## Minori: la città di produzione dà punti per la riserva di quello stato (uno per gruppo per fase)
static func _produzione_minori(m: Motore, l: int) -> void:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	var guida := "FR" if l == 0 else "EN"
	var fatti_gruppi := {}
	for code in MINORI:
		var st: String = c["minori"].get(code, "")
		if st != ("pro" if l == 0 else "anti"):
			continue
		if code == "R" and not c.get("reno", false):
			continue
		var gr: String = MINORI[code]["gruppo"]
		if fatti_gruppi.has(gr):
			continue
		var h := Mappa.hex(MINORI[code]["citta"][0])
		if h == "" or m.controllore(h) != l or m.sp_in(h, 1 - l) > 0:
			continue
		var pp := 2.0 if m.dado() >= 6 else 1.0
		var comprate := []
		for t2 in ["I", "C", "M", "P", "L"]:
			var k := "%s|%s|%s" % [guida, code, t2]
			while int(s["pool"].get(k, 0)) > 0 and pp >= COSTI[t2]:
				var naz_u := guida
				var sub: String = code
				if l == 1 and not code in ["H", "Pt", "Sw"]:
					sub = "K" if code in ["Ha", "Br"] else ""
					if sub == "":
						naz_u = "EN"
				m._nuova_unita(naz_u, sub, t2, 1, h)
				s["pool"][k] = int(s["pool"][k]) - 1
				pp -= COSTI[t2]
				comprate.append(t2)
		if not comprate.is_empty():
			fatti_gruppi[gr] = true
			m._log("Produzione di %s: %s." % [Dati.MINORI.get(code, code), _riassunto(comprate)])

# =============================================================================================
# Alleanze (GCG G, regole per due giocatori)

static func punti_alleanza(m: Motore) -> Array:
	var s: Dictionary = m.s
	var pro := 0
	var anti := 0
	for naz in MAGGIORI:
		var st := stato(m, naz)
		if st == "pro": pro += 1
		elif st == "anti": anti += 1
		for nome in PRODUZIONE.get(naz, {}).get("citta", []):
			var h := Mappa.hex(nome)
			if st == "anti" and m.controllore(h) == 0: pro += 1
			if st == "pro" and m.controllore(h) == 1 and naz != "FR": anti += 1
	for h in Mappa.esagoni:
		if Mappa.citta_maggiore(h) and Mappa.stato(h) == "FR" and m.controllore(h) == 1:
			anti += 1
	for gr in GRUPPI:
		var st := stato_gruppo(m, gr)
		if st == "pro": pro += 1
		elif st == "anti": anti += 1
	anti += int(s["pv"][1])
	return [pro, anti]

static func stato_gruppo(m: Motore, gr: String) -> String:
	var tutti_pro := true
	var tutti_anti := true
	var uno := false
	for code in GRUPPI[gr]:
		var st: String = m.s["camp"]["minori"].get(code, "neutro")
		if st == "nonformato":
			continue
		uno = true
		if st != "pro": tutti_pro = false
		if st != "anti": tutti_anti = false
	if not uno:
		return "neutro"
	return "pro" if tutti_pro else ("anti" if tutti_anti else "neutro")

static func modificatore(m: Motore) -> int:
	var p := punti_alleanza(m)
	return clampi(p[1] - p[0], -4, 4)

## Potenze su cui il lato può tirare il dado delle alleanze
static func eleggibili(m: Motore, l: int) -> Array:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	var out := []
	for naz in ["AU", "PR", "RU", "SP"]:
		var st := stato(m, naz)
		if c["in_conquista"].has(naz):
			continue
		if naz == "AU" and conquiste(m, "AU") < 2:
			continue
		if naz == "PR" and (c.get("prussia_guerra", false) and conquiste(m, "PR") == 0):
			continue
		if naz == "PR" and l == 0 and st == "neutro" and conquiste(m, "PR") == 0:
			continue
		if naz == "RU":
			if not (c["in_conquista"].has("AU") and c["in_conquista"].has("PR")) and not c.get("russia_libera", false):
				continue
			if int(c["tilsit"]) > int(s["turno"]) or int(c["inv_russia"]) >= 0:
				continue
			if l == 0 and st == "neutro":
				continue
		if naz == "SP" and conquiste(m, "SP") == 0:
			continue
		if l == 0 and st in ["neutro", "anti"]:
			out.append(naz)
		elif l == 1 and st in ["neutro", "pro"]:
			out.append(naz)
	return out

static func _chiedi_alleanze(m: Motore, l: int) -> void:
	var el := eleggibili(m, l)
	if el.is_empty():
		return
	var mod := modificatore(m)
	var opz := []
	var etich := []
	for naz in el:
		opz.append(naz)
		var st := stato(m, naz)
		var effetto := ""
		if l == 0:
			effetto = "da neutrale a alleata" if st == "neutro" else "da nemica a neutrale"
		else:
			effetto = "da neutrale a nemica della Francia" if st == "neutro" else "da alleata della Francia a neutrale"
		etich.append("%s (%s)" % [Dati.NAZ[naz]["nome"], effetto])
	opz.append("nessuna")
	etich.append("Nessun tentativo")
	var serve := "0 o meno" if l == 0 else "7 o più"
	_chiedi(m, l, "alleanza", "Fase delle alleanze: scegli una potenza e tira il dado (modificatore %+d, serve %s)." % [mod, serve], opz, etich)

## Una scelta della campagna in attesa (la chiede richiesta() del motore)
static func _chiedi(m: Motore, l: int, k: String, testo: String, opz: Array, etich: Array) -> void:
	if not m.s.has("scelte_c"):
		m.s["scelte_c"] = []
	m.s["scelte_c"].append({"k": "scelta_c", "lato": l, "tipo": k, "testo": testo, "opzioni": opz, "etichette": etich})

static func risolvi(m: Motore, rq: Dictionary, v: String) -> bool:
	if not v in rq["opzioni"]:
		return false
	m.s["scelte_c"].pop_front()
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	match str(rq["tipo"]):
		"alleanza":
			if v == "nessuna":
				return true
			var mod := modificatore(m)
			var t := m.dado()
			var tot := t + mod
			var l := int(rq["lato"])
			m.eventi.append({"k": "dado", "titolo": "Alleanze: %s" % Dati.NAZ[v]["nome"], "dadi": [t]})
			if l == 0 and tot <= 0:
				cambia(m, v, "pro" if stato(m, v) == "neutro" else "neutro", "dado %d%+d" % [t, mod])
			elif l == 1 and tot >= 7:
				cambia(m, v, "anti" if stato(m, v) == "neutro" else "neutro", "dado %d%+d" % [t, mod])
			else:
				m._log("Alleanze: %s resta com'è (dado %d%+d = %d)." % [Dati.NAZ[v]["nome"], t, mod, tot])
		"polonia":
			c["polonia"] = v
			if v == "nessuna":
				_annota(m, "Nessuna Polonia: le sue terre restano a Prussia, Austria e Russia")
				for id in s["unita"].keys():
					if s["unita"][id]["s"] == "Po":
						s["unita"].erase(id)
				for k in s["pool"].keys():
					if str(k).contains("|Po|"):
						s["pool"][k] = 0
			else:
				c["minori"]["Po"] = "pro"
				s["neutrali"].erase("Po")
				_aggiungi(m, "FR", "Po", "I", 4 if v == "granducato" else 8)
				c["fonti"][Mappa.hex("Warsaw")] = 0
				if v == "regno":
					c["fonti"][Mappa.hex("Grodno")] = 0
					_aggiungi(m, "PR", "", "L", 6)
					_aggiungi(m, "RU", "", "I", 4)
				_annota(m, "Nasce %s" % ("il Granducato di Varsavia" if v == "granducato" else "il Regno di Polonia"))
			if stato(m, "RU") == "anti":
				_chiedi(m, 0, "tilsit", "Con la questione polacca risolta puoi proporre a Zar Alessandro il trattato di Tilsit: la Russia diventa neutrale per %d mesi." % _mesi_tilsit(m),
					["si", "no"], ["Firma il trattato di Tilsit", "Continua la guerra"])
		"tilsit":
			if v == "si":
				var mesi := _mesi_tilsit(m)
				c["tilsit"] = int(s["turno"]) + mesi
				c["russia_libera"] = true
				cambia(m, "RU", "neutro", "trattato di Tilsit, per almeno %d mesi" % mesi)
				if c["polonia"] != "regno":
					var mg := Mappa.hex("Magdeburg")
					s["controllo"][mg] = 0
					c["fonti"][mg] = 0
	return true

static func _mesi_tilsit(m: Motore) -> int:
	return {"nessuna": 18, "granducato": 12, "regno": 6}.get(str(m.s["camp"]["polonia"]), 12)

static func _tilsit_scadenza(m: Motore) -> void:
	var c: Dictionary = m.s["camp"]
	if int(c["tilsit"]) > 0 and int(c["tilsit"]) == int(m.s["turno"]):
		m._log("Finisce la tregua di Tilsit: la Russia torna libera di schierarsi.")

# =============================================================================================
# Napoleone in esilio (GCG K.2)

static func _esilio_inizio(m: Motore) -> void:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	c["esilio"] = int(s["turno"])
	for id in s["capi"]:
		var cp: Dictionary = s["capi"][id]
		if cp["nome"] == "Napoleon":
			cp["h"] = ""
			cp["ritirato"] = true
	_annota(m, "Napoleone abdica e parte per l'esilio")

static func _esilio(m: Motore) -> void:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	if int(c["esilio"]) < 0 or c["napoleone_tornato"]:
		return
	var mesi := int(s["turno"]) - int(c["esilio"])
	if mesi < 3:
		return
	var pro := 0
	for naz in MAGGIORI:
		if stato(m, naz) == "pro": pro += 1
	for code in MINORI:
		if c["minori"].get(code, "") == "pro": pro += 1
	var t := m.dado() - pro - mesi / 3
	if t > 0 and mesi < 12:
		return
	# sbarca in Provenza e marcia su Parigi
	var sbarco := Mappa.hex("Toulon")
	if m.sp_in(sbarco, 1) > 0:
		sbarco = Mappa.hex("Marseilles")
	var d := m.dado()
	if d == 6:
		_annota(m, "Napoleone sbarca in Provenza ma viene fucilato prima di arrivare a Parigi")
		c["napoleone_fucilato"] = true
		m._chiudi(1, "Napoleone è fucilato durante i Cento Giorni: vittoria decisiva della Coalizione.")
		return
	c["napoleone_tornato"] = true
	var parigi := Mappa.hex("Paris")
	var dove := parigi if m.sp_in(parigi, 1) == 0 else sbarco
	for id in s["capi"]:
		var cp: Dictionary = s["capi"][id]
		if cp["nome"] == "Napoleon":
			cp.erase("ritirato")
			cp["h"] = dove
			cp["morto"] = false
	m._nuovo_capo("FR", "@0", dove)
	m._nuova_unita("FR", "", "GI", 1, dove)
	c["in_conquista"].erase("FR")
	cambia(m, "FR", "pro", "Napoleone torna dall'esilio")
	_annota(m, "I Cento Giorni: Napoleone è di nuovo a %s" % Mappa.nome(dove))

# =============================================================================================
# Vittoria (regole per due giocatori)

static func citta_produzione_tutte() -> Array:
	var out := []
	for naz in PRODUZIONE:
		for k in ["citta", "landwehr"]:
			for nome in PRODUZIONE[naz].get(k, []):
				out.append(nome)
	for code in MINORI:
		for nome in MINORI[code]["citta"]:
			if not nome in out:
				out.append(nome)
	return out

static func produzione_francese(m: Motore) -> int:
	var n := 0
	for nome in citta_produzione_tutte():
		if m.controllore(Mappa.hex(nome)) == 0:
			n += 1
	return n

static func porti_francesi(m: Motore, solo_maggiori: bool) -> Array:
	var out := []
	for h in Mappa.esagoni:
		if Mappa.ha_citta(h) and Mappa.porto(h) and m.controllore(h) == 0 and (not solo_maggiori or Mappa.citta_maggiore(h)):
			out.append(Mappa.nome_citta(h))
	return out

static func vittoria_subito(m: Motore) -> bool:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	if c["napoleone_tornato"] and c["in_conquista"].has("FR") and int(c["conq"].get("FR", 0)) >= 2:
		m._chiudi(1, "Napoleone tornato dall'esilio è sconfitto di nuovo: vittoria decisiva della Coalizione.")
		return true
	var parigi := m.controllore(Mappa.hex("Paris")) == 0
	if c["in_conquista"].has("EN") and parigi and produzione_francese(m) >= 15:
		m._chiudi(0, "L'Inghilterra è conquistata: vittoria decisiva francese.")
		return true
	var mosca := m.controllore(Mappa.hex("Moscow")) == 0
	if parigi and mosca:
		var porti := porti_francesi(m, false)
		if porti.size() >= 35 and "Lisbon" in porti and "Antwerp" in porti:
			m._chiudi(0, "Parigi, Mosca e %d porti: il blocco continentale è totale. Vittoria decisiva francese." % porti.size())
			return true
		var maggiori := porti_francesi(m, true)
		var serve := ["Antwerp", "Corunna", "Hamburg", "Konigsberg", "Lisbon"]
		if maggiori.size() >= 19 and serve.all(func(x): return x in maggiori):
			m._chiudi(0, "Parigi, Mosca e %d grandi porti: vittoria marginale francese." % maggiori.size())
			return true
	return false

static func fine(m: Motore) -> void:
	var s: Dictionary = m.s
	var c: Dictionary = s["camp"]
	var parigi := Mappa.hex("Paris")
	var fr_parigi := false
	for id in m.unita_in(parigi, 0):
		if not (s["assedi"].has(parigi) and int(s["assedi"][parigi]["lato"]) == 1 and s["unita"][id]["in"]):
			fr_parigi = true
	if c["napoleone_tornato"] and fr_parigi:
		m._chiudi(-1, "Napoleone è tornato ed è ancora a Parigi: pareggio.")
		return
	var mai := int(c["conq"].get("FR", 0)) == 0 and stato(m, "FR") == "pro"
	var spagna := int(c["inv_spagna"]) >= 0 and int(c["inv_spagna"]) < Scenari.turno_di(m.scen, "1809-01")
	var russia := int(c["inv_russia"]) >= 0 and int(c["inv_russia"]) < Scenari.turno_di(m.scen, "1813-01")
	var prod := produzione_francese(m)
	var txt := "(Parigi %s, Spagna invasa prima del 1809: %s, Russia invasa prima del 1813: %s, città di produzione francesi: %d)" % [
		"francese" if fr_parigi else "perduta", "sì" if spagna else "no", "sì" if russia else "no", prod]
	if fr_parigi and mai and spagna and russia:
		if prod >= 4:
			m._chiudi(0, "L'Impero resiste: vittoria marginale francese " + txt)
		else:
			m._chiudi(1, "L'Impero resiste ma è ridotto all'osso: vittoria marginale inglese " + txt)
		return
	m._chiudi(1, "Vittoria decisiva inglese " + txt)
