## Scenari.
## - 1805: "The Sun of Austerlitz" dal libretto ufficiale degli scenari (6ª/7ª edizione).
## - 1813: "Struggle of Nations", dalla scheda ufficiale dello scenario (7ª edizione).
## Negli schieramenti: "Città" = nella città, "Città>" = in un esagono vicino, "Città+n" = a nord;
## i capi "NAZ:@0" sono capi generici di valore 0; un terzo campo dà lo stato minore del capo.
class_name Scenari
extends RefCounted

## In ordine cronologico, come nel libretto ufficiale (I-XIII); "1798n" è l'Egitto con le flotte
const ELENCO := ["1796a", "1796", "1798", "1798n", "1800", "1805", "1806", "1809", "1812", "1813", "1814", "1815", "1808", "1811", "1812g"]

static var _cache := {}

static func dati(id: String) -> Dictionary:
	if not _cache.has(id):
		var d := {}
		match id:
			"1796a": d = _italia(true)
			"1796": d = _italia(false)
			"1798": d = _egitto(false)
			"1798n": d = _egitto(true)
			"1800": d = _marengo()
			"1805": d = _austerlitz()
			"1806": d = _apogeo()
			"1809": d = _wagram()
			"1812": d = _russia(false)
			"1813": d = _nazioni()
			"1814": d = _1814()
			"1815": d = _waterloo()
			"1808": d = _penisola(false)
			"1811": d = _penisola(true)
			"1812g": d = _russia(true)
		if d.is_empty():
			return {}
		_converti_date(d)
		_cache[id] = d
	return _cache[id].duplicate(true)

# ---------------------------------------------------------------------------------------------
# Strumenti per scrivere gli scenari in poco spazio

## "FR 8I 2GI 4C; FR:B 3I 1C" -> [["FR", "", "I", 8], ["FR", "", "GI", 2], ...]
static func U(t: String) -> Array:
	var out := []
	for parte in t.split(";", false):
		var pp := parte.strip_edges().split(" ", false)
		if pp.is_empty():
			continue
		var ns := pp[0].split(":")
		var naz := ns[0]
		var sub := ns[1] if ns.size() > 1 else ""
		for i in range(1, pp.size()):
			var x: String = pp[i]
			var j := 0
			while j < x.length() and x[j] >= "0" and x[j] <= "9":
				j += 1
			out.append([naz, sub, x.substr(j), int(x.substr(0, j))])
	return out

## Un gruppo: esagono, capi ("FR:Napoleon", "FR:@0", "FR:@0:H"), unità in forma breve
static func G(h: String, capi: Array, unita := "", extra := {}) -> Dictionary:
	var g := {"hex": h, "capi": capi, "unita": U(unita)}
	g.merge(extra)
	return g

## Turno di gioco di una data "AAAA-MM" (il primo turno è il mese d'inizio)
static func turno_di(d: Dictionary, data: String) -> int:
	var p := data.split("-")
	return (int(p[0]) - int(d["anno"])) * 12 + (int(p[1]) - 1 - int(d["mese"])) + 1

## Converte le date dei rinforzi, delle alleanze, degli eventi e della vittoria in numeri di turno
static func _converti_date(d: Dictionary) -> void:
	if d.has("rinforzi_data"):
		var r := {}
		for data in d["rinforzi_data"]:
			var t := str(turno_di(d, data))
			if not r.has(t):
				r[t] = []
			r[t].append_array(d["rinforzi_data"][data])
		d["rinforzi"] = r
	for g in d.get("ogni_turno", []):
		for k in ["da", "a"]:
			if g.has(k) and g[k] is String:
				g[k] = turno_di(d, g[k])
	for k in ["alleanze", "marcatore_alleanza"]:
		if d.has(k):
			for kk in ["da", "forza"]:
				if d[k].has(kk) and d[k][kk] is String:
					d[k][kk] = turno_di(d, d[k][kk])
	for e in d.get("eventi", []):
		if e.has("da") and e["da"] is String:
			e["da"] = turno_di(d, e["da"])
	for v in d.get("vittoria_cond", []):
		if v.has("dal") and v["dal"] is String:
			v["dal"] = turno_di(d, v["dal"])
	for chi in d.get("rp", {}):
		for riga in d["rp"][chi].get("tabella", []):
			for i in 2:
				if riga[i] is String:
					riga[i] = turno_di(d, riga[i])

static func _austerlitz() -> Dictionary:
	return {
		"id": "1805",
		"titolo": "Austerlitz 1805",
		"sottotitolo": "The Sun of Austerlitz — la Terza Coalizione",
		"descrizione": "Agosto 1805: la Grande Armée è sul Reno attorno a Strasburgo e Metz, Mack è avanzato in Baviera fino a Ulm, l'arciduca Carlo difende il Veneto, i Russi si radunano in Polonia. Napoleone deve prendere e tenere Vienna prima dell'inverno; la Prussia osserva e potrebbe entrare in guerra.",
		"durata": "Cinque turni mensili, da agosto a dicembre 1805 (scenario ufficiale).",
		"mese": 7, "anno": 1805, "turni": 5,
		"lati": {"FR": 0, "B": 0, "Wu": 0, "Ba": 0, "I": 0, "Ha": 0, "Sz": 0, "R": 0, "H": 0,
			"AU": 1, "RU": 1, "PR": 1, "S": 1, "He": 1, "Br": 1},
		"in_guerra": ["FR", "B", "Wu", "Ba", "I", "Ha", "Sz", "R", "H", "AU", "RU"],
		# i Francesi possono entrare in territorio prussiano (la Coalizione guadagna un punto città), gli alleati no
		"aperti_lato": {"0": ["PR", "S", "He", "Br"]},
		"violazione": {"stati": ["PR", "S", "He", "Br"], "lato": 0},
		"fonti": {"0": {"citta": ["Milan"], "stati": ["FR"]}, "1": {"patria": true}},
		"rinforzi_persi": true,
		"controllo": {"Ulm": 1},
		"schieramento": [
			{"hex": "Strasbourg", "capi": ["FR:Napoleon", "FR:Lannes", "FR:Ney"],
				"unita": [["FR", "", "I", 8], ["FR", "", "GI", 2], ["FR", "", "C", 4]]},
			{"hex": "Metz", "capi": ["FR:Davout", "FR:Soult"], "unita": [["FR", "", "I", 12], ["FR", "", "C", 1]]},
			{"hex": "Milan", "capi": ["FR:Massena"], "unita": [["FR", "", "I", 3], ["FR", "", "C", 1], ["FR", "I", "I", 4], ["FR", "I", "C", 1]]},
			{"hex": "Coblenz", "capi": ["FR:Marmont"], "unita": [["FR", "", "I", 3], ["FR", "", "C", 1]]},
			{"hex": "Cologne", "capi": ["FR:Bernadotte"], "unita": [["FR", "", "I", 3]]},
			{"hex": "Florence", "capi": ["FR:@0"], "unita": [["FR", "", "I", 4]]},
			{"hex": "Brest", "capi": ["FR:@0"], "unita": [["FR", "", "I", 4]]},
			{"hex": "Amsterdam", "capi": ["FR:@0:H"], "unita": [["FR", "", "I", 3], ["FR", "H", "I", 3]]},
			{"hex": "Hanover", "capi": [], "unita": [["FR", "", "I", 1]]},
			{"hex": "Wurzburg", "capi": ["FR:@0:B"], "unita": [["FR", "B", "I", 3], ["FR", "B", "C", 1]]},
			{"hex": "Baden", "capi": [], "unita": [["FR", "R", "I", 1]]},
			{"hex": "Geneva", "capi": [], "unita": [["FR", "Sz", "I", 1]]},
			{"hex": "Stuttgart", "capi": [], "unita": [["FR", "Wu", "I", 2]]},
			{"hex": "Ulm", "capi": ["AU:Ferdinand", "AU:Mack"], "unita": [["AU", "", "I", 11], ["AU", "", "C", 3]]},
			{"hex": "Venice", "capi": ["AU:Charles", "AU:Hiller"], "unita": [["AU", "", "I", 14], ["AU", "", "C", 4]]},
			{"hex": "Innsbruck", "capi": ["AU:John"], "unita": [["AU", "", "I", 3], ["AU", "", "C", 1]]},
			{"hex": "Vienna", "capi": ["AU:@0"], "unita": [["AU", "", "I", 2]]},
			{"hex": "Prague", "capi": [], "unita": [["AU", "", "I", 1]]},
			{"hex": "Ratisbon", "capi": [], "unita": [["AU", "", "I", 1]]},
			{"hex": "Brest-Litovsk", "capi": ["RU:Buxhowden", "RU:Constantine"],
				"unita": [["RU", "", "I", 5], ["RU", "", "GI", 2], ["RU", "", "C", 1], ["RU", "", "GC", 1]]},
			{"hex": "Lublin", "capi": ["RU:Bagration", "RU:Kutusov"], "unita": [["RU", "", "I", 7], ["RU", "", "C", 1]]},
			{"hex": "Grodno", "capi": ["RU:Bennigsen"], "unita": [["RU", "", "I", 3], ["RU", "", "C", 1]]},
		],
		"ogni_turno": [
			{"hex": "Budapest", "capi": [], "unita": [["AU", "", "I", 1]]},
			{"hex": "Vienna", "capi": [], "unita": [["AU", "", "I", 1]]},
		],
		# con 7 (Coalizione) la Prussia entra in guerra; con 0 (Francesi) resta neutrale per sempre
		"alleanza": {"nazione": "PR", "stati": ["PR", "S", "He", "Br"], "lato": 1,
			"schieramento": [
				{"hex": "Magdeburg", "capi": ["PR:Brunswick", "PR:Ruchel"], "unita": [["PR", "", "I", 10], ["PR", "", "C", 1]]},
				{"hex": "Dresden", "capi": ["PR:@0"], "unita": [["PR", "", "I", 4], ["PR", "", "C", 1]]},
				{"hex": "Weimar", "capi": ["PR:Hohenlohe"], "unita": [["PR", "", "I", 6], ["PR", "", "C", 1]]},
				{"hex": "Berlin", "capi": [], "unita": [["PR", "", "I", 1]]},
				{"hex": "Posen", "capi": [], "unita": [["PR", "", "I", 1]]},
				{"hex": "Thorn", "capi": [], "unita": [["PR", "", "I", 1]]},
			]},
		"punti_citta": [{"Vienna": 1}, {}],
		# per l'IA: cosa prendere (lato 0) e cosa difendere/prendere (lato 1)
		"obiettivi": [{"Vienna": 12, "Ulm": 1, "Munich": 1}, {"Munich": 1, "Ulm": 1}],
		"ia": {"difendi": [{}, {"Vienna": 12}]},
		"vittoria_tipo": "vienna",
		"vittoria": "I Francesi vincono se alla fine di dicembre 1805 c'è almeno un punto forza francese non assediato a Vienna; altrimenti vince la Coalizione. Punti vittoria: 1 entrando dopo una battaglia in un esagono che aveva più di 4 PF nemici (2 per la Coalizione se c'era Napoleone). Punti città: Francia 1 per Vienna; Coalizione 1 (una sola volta) se un'unità francese entra in territorio prussiano. La differenza modifica il dado delle alleanze: con 7 della Coalizione la Prussia entra in guerra, con 0 dei Francesi resta neutrale.",
		"margine": 0,
	}

static func _nazioni() -> Dictionary:
	return {
		"id": "1813",
		"titolo": "Lipsia 1813",
		"sottotitolo": "Struggle of Nations — la battaglia delle nazioni",
		"descrizione": "Aprile 1813: la Grande Armée è perduta in Russia, Prussiani e Russi avanzano in Germania. Napoleone ricostruisce l'esercito attorno a Magonza e deve tenere la Germania. Austria e Svezia sono neutrali ma potrebbero dichiarare guerra; Baviera, Sassonia, Napoli e Svizzera esitano.",
		"durata": "Nove turni mensili, da aprile a dicembre 1813 (scenario ufficiale).",
		"mese": 3, "anno": 1813, "turni": 9,
		"lati": {"FR": 0, "H": 0, "W": 0, "R": 0, "I": 0, "Wu": 0, "Po": 0, "Ha": 0, "He": 0, "Br": 0,
			"Ba": 0, "B": 0, "N": 0, "S": 0, "Sz": 0, "PR": 1, "RU": 1, "AU": 1, "Sw": 1},
		"in_guerra": ["FR", "H", "W", "R", "I", "Wu", "Po", "Ha", "He", "Br", "Ba", "PR", "RU"],
		"neutrali": ["AU", "Sw", "B", "N", "S", "Sz"],
		# tutto è percorribile tranne l'Austria finché è neutrale (salvo la sua parte in area 2)
		"chiusi_se_neutrali": {"AU": ["AU"]},
		"aperti_area2": ["AU"],
		"permessi": {"Po": ["AU"]},
		"fonti": {"0": {"citta": ["Hanover", "Milan"], "stati": ["FR"]}, "1": {"patria": true}},
		"francesi_ridotti": true,
		"controllo": {},
		"schieramento": [
			{"hex": "Mainz", "capi": ["FR:Napoleon", "FR:Soult", "FR:Bessieres", "FR:Marmont", "FR:Ney"],
				"unita": [["FR", "", "I", 13], ["FR", "", "GI", 2], ["FR", "", "GC", 1], ["FR", "Po", "I", 1]]},
			{"hex": "Hanover", "capi": ["FR:Davout"], "unita": [["FR", "", "I", 4], ["FR", "", "C", 2]]},
			{"hex": "Brunswick", "capi": ["FR:Eugene", "FR:Victor"], "unita": [["FR", "", "I", 8], ["FR", "", "GI", 1], ["FR", "", "C", 1], ["FR", "W", "I", 1]]},
			{"hex": "Ulm", "capi": ["FR:@0", "FR:@0"], "unita": [["FR", "", "I", 5], ["FR", "I", "I", 2]]},
			{"hex": "Florence", "capi": ["FR:Murat"], "unita": []},
			{"hex": "Milan", "capi": ["FR:@0:I"], "unita": [["FR", "", "I", 2], ["FR", "I", "I", 4], ["FR", "I", "C", 1]]},
			{"hex": "Bremen", "capi": [], "unita": [["FR", "D", "I", 3]]},
			{"hex": "Magdeburg", "capi": [], "unita": [["FR", "", "I", 1]]},
			{"hex": "Frankfurt", "capi": [], "unita": [["FR", "R", "I", 1]]},
			{"hex": "Wurzburg", "capi": [], "unita": [["FR", "R", "I", 1]]},
			{"hex": "Stuttgart", "capi": [], "unita": [["FR", "Wu", "I", 3]]},
			{"hex": "Stettin", "capi": [], "unita": [["FR", "", "I", 1], ["PR", "", "L", 2]]},
			{"hex": "Thorn", "capi": [], "unita": [["FR", "", "I", 1], ["RU", "", "I", 1]]},
			{"hex": "Danzig", "capi": [], "unita": [["FR", "", "I", 6]]},
			{"hex": "Cracow", "capi": ["FR:Poniatowski"], "unita": [["FR", "Po", "I", 2], ["FR", "Po", "C", 1]]},
			# satelliti francesi neutrali
			{"hex": "Munich", "capi": ["FR:@0:B"], "unita": [["FR", "B", "I", 4], ["FR", "B", "C", 1]]},
			{"hex": "Florence", "capi": [], "unita": [["FR", "N", "I", 4]]},
			{"hex": "Dresden+n", "capi": [], "unita": [["FR", "S", "I", 2]]},
			{"hex": "Geneva", "capi": [], "unita": [["FR", "Sz", "I", 2]]},
			{"hex": "Basel", "capi": [], "unita": [["FR", "Sz", "I", 1]]},
			{"hex": "Neuchatel", "capi": [], "unita": [["FR", "Sz", "I", 1]]},
			# Prussia
			{"hex": "Dresden", "capi": ["PR:Blucher"], "unita": [["PR", "", "I", 4], ["PR", "", "C", 2]]},
			{"hex": "Berlin", "capi": ["PR:Bulow", "PR:Kleist", "PR:Yorck"], "unita": [["PR", "", "L", 1], ["PR", "", "I", 6], ["PR", "", "C", 1]]},
			{"hex": "Lubeck", "capi": ["PR:@0"], "unita": [["PR", "", "L", 2], ["PR", "He", "L", 2]]},
			{"hex": "Danzig>", "capi": [], "unita": [["PR", "", "L", 3], ["RU", "", "I", 3]]},
			# Russia
			{"hex": "Leipzig", "capi": ["RU:@0"], "unita": [["RU", "", "I", 3], ["RU", "", "C", 1], ["RU", "", "CC", 1]]},
			{"hex": "Berlin", "capi": ["RU:Wittgenstein"], "unita": [["RU", "", "I", 2], ["RU", "", "C", 1], ["RU", "", "CC", 1]]},
			{"hex": "Lubeck", "capi": [], "unita": [["RU", "", "CC", 2]]},
			{"hex": "Breslau", "capi": ["RU:Constantine", "RU:Tormazov"], "unita": [["RU", "", "I", 3], ["RU", "", "GI", 2], ["RU", "", "GC", 1]]},
			{"hex": "Posen", "capi": [], "unita": [["RU", "", "I", 1]]},
			{"hex": "Thorn>", "capi": ["RU:Barclay"], "unita": [["RU", "", "I", 3], ["RU", "", "C", 1]]},
			{"hex": "Warsaw", "capi": [], "unita": [["RU", "", "I", 1]]},
			{"hex": "Cracow>", "capi": ["RU:@0"], "unita": [["RU", "", "I", 3], ["RU", "", "C", 1]]},
			{"hex": "Brest-Litovsk", "capi": ["RU:@0"], "unita": [["RU", "", "I", 2]]},
			# Svezia (neutrale)
			{"hex": "Stralsund", "capi": ["RU:Bernadotte:Sw"], "unita": [["RU", "Sw", "I", 5], ["RU", "Sw", "C", 1]]},
			# Austria (neutrale)
			{"hex": "Prague", "capi": ["AU:Schwarzenberg", "AU:@0", "AU:@0"], "unita": [["AU", "", "I", 10], ["AU", "", "C", 2]]},
			{"hex": "Leoben", "capi": ["AU:Hiller", "AU:@0"], "unita": [["AU", "", "I", 2], ["AU", "", "L", 2], ["AU", "", "C", 1]]},
			{"hex": "Ratisbon+e", "capi": ["AU:@0"], "unita": [["AU", "", "I", 5], ["AU", "", "C", 1]]},
		],
		"assedi": [["Stettin", 1], ["Thorn", 1]],
		"trincee": [["Danzig", 0], ["Danzig>", 1], ["Dresden+n", 0]],
		"rinforzi": {
			"2": [{"hex": "Mainz", "capi": [], "unita": [["FR", "", "I", 2]]},
				{"hex": "Hanover", "capi": [], "unita": [["FR", "W", "I", 2]]},
				{"hex": "Milan", "capi": [], "unita": [["FR", "I", "I", 1]]},
				{"hex": "Stuttgart", "capi": [], "unita": [["FR", "Wu", "I", 1]]}],
			"3": [{"hex": "Mainz", "capi": [], "unita": [["FR", "", "I", 8]]},
				{"hex": "Milan", "capi": [], "unita": [["FR", "I", "I", 3]]},
				{"hex": "Stuttgart", "capi": [], "unita": [["FR", "Wu", "I", 1]]},
				{"hex": "Brest-Litovsk", "capi": ["RU:Bennigsen", "RU:Docturov"],
					"unita": [["RU", "", "I", 10], ["RU", "", "GI", 2], ["RU", "", "C", 2], ["RU", "", "CC", 2]]}],
			"4": [{"hex": "Mainz", "capi": [], "unita": [["FR", "", "I", 10], ["FR", "", "GI", 6], ["FR", "", "C", 6]]}],
			"5": [{"hex": "Mainz", "capi": ["FR:@0"], "unita": [["FR", "", "I", 2], ["FR", "", "C", 1]]}],
			"6": [{"hex": "Mainz", "capi": [], "unita": [["FR", "", "I", 4]]},
				{"hex": "Munich", "capi": [], "unita": [["FR", "B", "I", 1]]},
				{"hex": "Hanover", "capi": [], "unita": [["FR", "W", "I", 1]]}],
			"7": [{"hex": "Mainz", "capi": [], "unita": [["FR", "", "I", 2]]}],
			"8": [{"hex": "Mainz", "capi": [], "unita": [["FR", "", "I", 2]]}],
		},
		"ogni_turno": [
			{"hex": "Berlin", "capi": [], "unita": [["PR", "", "I", 1], ["PR", "", "L", 1]]},
			{"hex": "Breslau", "capi": [], "unita": [["PR", "", "I", 1], ["PR", "", "L", 1]]},
			{"hex": "Brest-Litovsk", "capi": [], "unita": [["RU", "", "I", 2]]},
			{"hex": "Prague", "capi": [], "unita": [["AU", "", "I", 1], ["AU", "", "L", 1]]},
			{"hex": "Leoben", "capi": [], "unita": [["AU", "", "I", 1], ["AU", "", "L", 1]]},
		],
		"alleanze_1813": {
			# modificatore del mese (giugno +1, luglio +2, da agosto +3)
			"mesi": {"5": 1, "6": 2, "7": 3, "8": 3, "9": 3, "10": 3, "11": 3},
			"satelliti": ["B", "N", "S", "Sz"],
			"entrano": ["AU", "Sw"],
			"defezione": {"B": "AU", "S": "PR", "R": "PR", "Wu": "PR", "Sz": "", "N": ""},
		},
		# punti città (per le alleanze): Francia 1 per Berlino; Coalizione 1 per ciascuna di queste e per ogni città in area 2
		"punti_citta": [{"Berlin": 1}, {"Berlin": 1, "Breslau": 1, "Dresden": 1, "Hamburg": 1, "Leipzig": 1, "Magdeburg": 1}],
		"punti_area2_coalizione": true,
		# obiettivi per l'IA: le città maggiori della Germania (area 3)
		"obiettivi": [
			{"Dresden": 3, "Leipzig": 3, "Magdeburg": 2, "Hamburg": 2, "Hanover": 2, "Berlin": 3, "Cassel": 1, "Breslau": 1},
			{"Dresden": 3, "Leipzig": 3, "Magdeburg": 2, "Hamburg": 2, "Hanover": 2, "Cassel": 2, "Mainz": 1},
		],
		"ia": {"difendi": [{"Magdeburg": 4, "Hamburg": 3, "Hanover": 3, "Dresden": 3, "Leipzig": 2}, {"Berlin": 4, "Breslau": 2}],
			"ammassa": ["Magdeburg", "Hamburg", "Hanover"]},
		"vittoria_tipo": "area3",
		"vittoria": "I Francesi vincono se alla fine di dicembre controllano almeno una città maggiore non assediata nell'area 3 della mappa (la Germania a est del Reno: Amburgo, Hannover, Magdeburgo, Lipsia, Dresda, Berlino, Cassel, Breslavia...); altrimenti vince la Coalizione. Punti vittoria: 1 entrando dopo una battaglia in un esagono che aveva più di 4 PF nemici (2 se c'era Napoleone). Con i punti città (Francia: Berlino; Coalizione: Berlino, Breslavia, Dresda, Amburgo, Lipsia, Magdeburgo e ogni città dell'area 2) modificano il dado delle alleanze, con il mese: con 7 Austria e Svezia entrano in guerra, con un secondo 7 i satelliti tedeschi passano alla Coalizione; con 0 dei Francesi Baviera, Sassonia, Napoli e Svizzera combattono per Napoleone.",
		"margine": 0,
	}

# =============================================================================================
# I. La campagna d'Italia 1796-97 (introduttivo e avanzato)

static func _italia(intro: bool) -> Dictionary:
	var d := {
		"id": "1796a" if intro else "1796",
		"titolo": "Italia 1796" + (" (introduttivo)" if intro else ""),
		"sottotitolo": "The Italian Campaign — la prima campagna di Bonaparte",
		"descrizione": "Primavera 1796: l'Armata d'Italia, piccola e affamata, è sulle Alpi Marittime attorno a Montenotte. Il giovane Bonaparte deve battere Austriaci e Piemontesi prima che si riuniscano e prendere le città della pianura padana." + (" Versione introduttiva: pochi pezzi e regole semplici, per imparare il gioco." if intro else " Versione avanzata: il Piemonte cambia campo se Torino cade, e la guerra arriva fino al Tirolo."),
		"durata": ("Cinque turni mensili, da maggio a settembre 1796." if intro else "Dieci turni mensili, da aprile 1796 a gennaio 1797."),
		"mese": 4 if intro else 3, "anno": 1796, "turni": 5 if intro else 10,
		"aree": [2, 3],
		"lati": {"FR": 0, "AU": 1, "I": 1, "B": 1, "R": 1},
		"in_guerra": ["FR", "AU", "I", "B", "R"],
		"controllo": {"Genoa": 1, "Turin": 1},
		"fonti": {"0": {"stati": ["FR"]} if intro else {"iniziali": true}, "1": {"stati": ["AU", "I", "B"]} if intro else {"stati": ["AU", "I", "B"], "citta": ["Frankfurt", "Wurzburg"]}},
		"rinforzi_regola": "vicina",
		"schieramento": [
			G("#40,28", ["FR:Bonaparte", "FR:Massena", "FR:Augereau", "FR:@0"], "FR 11I 1C"),
			G("#40,27", ["FR:@0"], "FR 2I 1C"),
			G("#40,30", ["AU:@0"], "AU 1I 1C"),
			G("Milan", ["AU:@0"], "AU 1I 1C"),
			G("#40,32", [], "AU 1C"),
		],
		"ogni_turno": [
			G("Lyon", [], "FR 1I", {"rimpiazzo": true}),
			G("Munich", [], "AU 1I", {"rimpiazzo": true}),
		],
		"rinforzi_data": {
			"1796-05": [G("Lyon", ["FR:Kellermann"], "FR 3I 1C"), G("Toulon", [], "FR 1I")],
			"1796-07": [G("@capo:Massena", ["FR:Joubert"]), G("Lyon", [], "FR 1I"),
				G("Innsbruck", ["AU:Wurmser", "AU:Davidovich", "AU:Quasdanovich", "AU:Meszaros"], "AU 4I 1C"), {"ritira": {"capi": ["Beaulieu"]}, "lato": 1}],
			"1796-08": [G("Lyon", [], "FR 1I"), G("Innsbruck", [], "AU 1I")],
			"1796-09": [G("Lyon", [], "FR 2I"), G("Toulon", [], "FR 1I"), G("Munich", [], "AU 2I")],
			"1796-11": [G("Lyon", [], "FR 2I"), G("Munich", [], "AU 1I")],
			"1797-01": [G("Lyon", [], "FR 3I"), G("Munich", [], "AU 3I")],
		},
		"morale_capo": {},
		"punti_citta": [{}, {}],
		"obiettivi": [{"Genoa": 6, "Turin": 6, "Milan": 7, "Mantua": 5, "Venice": 4, "Innsbruck": 3, "Florence": 2, "Leghorn": 2},
			{"Genoa": 4, "Turin": 3, "Toulon": 4, "Lyon": 3, "Marseilles": 2, "Avignon": 2}],
		"ia": {"difendi": [{"Toulon": 4, "Genoa": 3}, {"Milan": 5, "Mantua": 4, "Turin": 3}]},
		"margine": 0,
	}
	if intro:
		d["schieramento"].append_array([G("Genoa", ["AU:@0"], "AU 4I 1C"), G("Turin", ["AU:Beaulieu"], "AU 5I 1C")])
		d["vittoria_cond"] = [{"vince": 0, "test": {"t": "e", "tests": [
			{"t": "controlla", "lato": 0, "citta": ["Genoa", "Milan", "Toulon", "Turin"]},
			{"t": "controlla", "lato": 0, "citta": ["Mantua", "Innsbruck", "Venice"], "min": 1}]},
			"perche": "Bonaparte controlla Genova, Milano, Tolone, Torino e una piazzaforte austriaca."}]
		d["vince_default"] = 1
		d["perche_default"] = "Gli Austriaci hanno negato a Bonaparte le città d'Italia."
		d["vittoria"] = "Il Francese vince subito se controlla Genova, Milano, Tolone, Torino e una fra Mantova, Innsbruck e Venezia; altrimenti vince l'Austria a fine settembre. Niente alleanze; la Svizzera è neutrale."
	else:
		d["lati"]["Pm"] = 1
		d["schieramento"].append_array([G("#39,29", ["AU:Beaulieu"], "AU 5I 1C"), G("Turin", ["AU:@0", "AU:Colli:Pm"], "AU 1I 1C; AU:Pm 5I"),
			G("Milan>", ["AU:@0"], "AU 2I")])
		d["eventi"] = [{"id": "piemonte", "lato": 0, "da": 2, "se": {"t": "controlla", "lato": 0, "citta": ["Turin"]},
			"effetti": [{"e": "elimina", "sub": ["Pm"], "t": "Il Piemonte firma l'armistizio di Cherasco ed esce dalla guerra"}]}]
		d["vittoria_cond"] = [
			{"vince": 0, "test": {"t": "controlla", "lato": 0, "citta": ["Vienna", "Prague"], "min": 1}, "perche": "Bonaparte è a Vienna o a Praga."},
			{"vince": 0, "test": {"t": "occupa", "lato": 0, "citta": ["Genoa", "Turin", "Milan", "Venice", "Florence", "Leghorn", "Innsbruck"]}, "perche": "Bonaparte occupa l'Italia del nord fino a Innsbruck."},
			{"vince": 1, "dal": "1796-12", "test": {"t": "controlla", "lato": 1, "stati": ["I"]}, "perche": "Gli Austriaci controllano tutte le città del Regno d'Italia."},
			{"vince": 1, "test": {"t": "e", "tests": [{"t": "occupa", "lato": 1, "citta": ["Genoa", "Turin", "Milan", "Florence", "Leghorn"]}, {"t": "occupa", "lato": 1, "citta": ["Toulon", "Lyon"], "min": 1}]}, "perche": "Gli Austriaci occupano Genova, Torino, Milano, Firenze, Livorno e Tolone o Lione."},
			{"vince": 1, "test": {"t": "occupa", "lato": 1, "citta": ["Toulon", "Marseilles", "Lyon", "Avignon"]}, "perche": "Gli Austriaci occupano Tolone, Marsiglia, Lione e Avignone."},
		]
		d["vince_default"] = -1
		d["perche_default"] = "Nessuno ha raggiunto le sue condizioni di vittoria."
		d["vittoria"] = "Vittoria automatica francese con Vienna o Praga, oppure occupando Genova, Torino, Milano, Venezia, Firenze, Livorno e Innsbruck. Vittoria automatica austriaca controllando (da dicembre 1796) tutte le città del Regno d'Italia, oppure occupando Genova, Torino, Milano, Firenze, Livorno e Tolone o Lione, oppure Tolone, Marsiglia, Lione e Avignone. Altrimenti pareggio. Il Piemonte esce dalla guerra quando i Francesi prendono Torino. Le armate d'osservazione prussiane e austriache (regola facoltativa) non sono in gioco."
	return d

# =============================================================================================
# II. L'Armata d'Oriente: Bonaparte in Egitto 1798-99 (con le flotte: regola facoltativa)

static func _egitto(flotte: bool) -> Dictionary:
	var citta := {"Alexandria": 1, "Aswan": 1, "Damietta": 1, "El Arish": 1, "Gaza": 1, "Jaffa": 1, "Jerusalem": 1, "Acre": 2, "Cairo": 2}
	var d := {
		"id": "1798n" if flotte else "1798",
		"titolo": "Egitto 1798" + (" con le flotte" if flotte else ""),
		"sottotitolo": "The Army of the Orient — Bonaparte in Egitto",
		"descrizione": ("Giugno 1798: l'armata d'Oriente è ancora a Tolone, sulle navi. Bisogna attraversare il Mediterraneo sfuggendo a Nelson, sbarcare in Egitto e conquistarlo." if flotte else "Luglio 1798: Bonaparte è sbarcato ad Alessandria. I Mamelucchi difendono il Cairo e il Nilo, i Turchi la Siria; la Turchia per ora è neutrale ma il segnalino della guerra sale ogni mese."),
		"durata": ("Diciassette turni mensili, da giugno 1798 a ottobre 1799." if flotte else "Sedici turni mensili, da luglio 1798 a ottobre 1799."),
		"mese": 5 if flotte else 6, "anno": 1798, "turni": 17 if flotte else 16,
		"aree": [5],
		"lati": {"FR": 0, "TU": 1, "EN": 1, "RU": 1, "EG": 1, "SY": 1},
		"in_guerra": ["FR", "EG"],
		"neutrali": ["TU", "Mm"] if flotte else ["TU"],
		"attivi_sub": ["Mm"],
		"fonti_naz": {"FR": {"egitto": "fr"}, "TU": {"egitto": "mam", "nord_siria": true, "porti_propri": true}},
		"riforniti_turno1": [0],
		"nilo": true, "mamelucchi": true, "no_travolgimento": true, "no_4a1": true,
		"perdite_fr_dado": true, "assalto_egitto": true,
		"morale_capo": {"naz": "FR", "capi": ["Bonaparte", "Desaix"], "con": 2, "senza": 1},
		"rinforzi_regola": "persi",
		"schieramento": [
			G("Damietta", [], "TU:Mm 1C"),
			G("Cairo+e", ["TU:Ibrahim Bey:Mm"], "TU:Mm 3C"),
			G("Cairo", ["TU:Murad Bey:Mm"], "TU:Mm 4C"),
			G("Gaza", ["TU:@0"], "TU 2I"),
			G("Jaffa", [], "TU 1I"),
			G("Acre", [], "TU 2I"),
			G("Jerusalem", ["TU:Djezzar"], "TU 3I"),
		],
		"marcatore_alleanza": {"da": "1798-08", "inizio": 2, "forza": "1798-11", "lato": 1,
			"effetti": [{"e": "attiva", "codici": ["TU"]}, {"e": "guerra", "stati": ["SY"], "lato": 1, "t": "La Turchia dichiara guerra alla Francia"}]},
		"ogni_turno": [
			G("Aswan", [], "TU:Mm 1C", {"rimpiazzo": true, "se": {"t": "non", "test": {"t": "controlla", "lato": 0, "citta": ["Aswan"]}}}),
		],
		"rinforzi_data": {
			"1798-10": [G("Cairo", [], "FR 1I", {"rimpiazzo": true}), G("Aswan", ["TU:Hassan Bey:Mm"], "TU:Mm 4C")],
			"1798-12": [G("Cairo", [], "FR 1I", {"rimpiazzo": true})],
			"1799-02": [G("Cairo", [], "FR 1I", {"rimpiazzo": true})],
			"1799-04": [G("Cairo", [], "FR 1I", {"rimpiazzo": true}), G("@nord", ["TU:Abdallah"], "TU 14I", {"regola": "vicina"})],
			"1799-05": [G("El Arish", [], "TU 7I", {"alt": ["Gaza", "Jaffa", "Jerusalem", "Acre"]})],
			"1799-06": [G("Cairo", [], "FR 1I", {"rimpiazzo": true}),
				{"mare": "MOR", "capi": ["TU:Mustapha"], "unita": U("TU 6I"), "dove": "vicino", "vicino": ["Alexandria", 3], "lato": 1}],
			"1799-08": [G("Cairo", [], "FR 1I", {"rimpiazzo": true})],
			"1799-09": [G("Acre", ["TU:@0"], "TU 10I")],
			"1799-10": [G("Cairo", [], "FR 1I", {"rimpiazzo": true})],
		},
		# un porto egiziano preso dai Turchi sbarcati porta altri 6 PF
		"eventi": [{"id": "porto_turco", "lato": 1, "da": "1799-06", "se": {"t": "occupa", "lato": 1, "naz": "TU", "citta": ["Alexandria", "Rosetta", "Damietta"], "min": 1},
			"effetti": [{"e": "rinforzi", "gruppi": [G("Alexandria", [], "TU 6I", {"alt": ["Rosetta", "Damietta"]})], "t": "Altri Turchi sbarcano in Egitto"}]}],
		"punti_egitto": {"citta": citta, "soglie": [9, 6, 5]},
		"vittoria_cond": [],
		"punti_citta": [citta, {}],
		"obiettivi": [{"Cairo": 9, "Alexandria": 4, "Damietta": 3, "Aswan": 4, "El Arish": 3, "Gaza": 3, "Jaffa": 3, "Jerusalem": 3, "Acre": 5},
			{"Cairo": 8, "Alexandria": 5, "Damietta": 3, "Aswan": 3, "El Arish": 3}],
		"ia": {"difendi": [{"Cairo": 3}, {"Acre": 6, "Cairo": 5, "Aswan": 4}]},
		"vittoria": "Punti città francesi a fine partita (1 per Alessandria, Assuan, Damietta, El Arish, Gaza, Giaffa e Gerusalemme, 2 per Acri e il Cairo): 9-11 vittoria decisiva francese, 6-8 marginale, 5 pareggio, 3-4 vittoria marginale alleata, 0-2 decisiva. Rifornimento francese dal Cairo (con Bonaparte vicino o Assuan presa) e lungo il Nilo; la Turchia entra in guerra con il dado contro il segnalino (al più tardi a novembre 1798). Niente travolgimenti, niente 4:1; ogni perdita francese si può evitare con un dado più il capo di 5 o più.",
		"margine": 0,
	}
	if not flotte:
		d["schieramento"].append(G("Alexandria", ["FR:Bonaparte", "FR:Desaix", "FR:Lannes", "FR:Kleber", "FR:Murat"], "FR 14I 1C"))
	if flotte:
		d["aree"] = [5]
		d["mare_zone"] = ["MOC", "MOR"]
		d["lati"]["FR"] = 0
		d["in_guerra"] = ["FR", "EG"]
		d["schieramento"].append(G("Alexandria", [], "TU:Mm 1C"))
		d["schieramento"].append(G("Toulon", ["FR:Bonaparte", "FR:Desaix", "FR:Lannes", "FR:Kleber", "FR:Murat"], "FR 14I 1C"))
		d["flotte"] = [{"hex": "Toulon", "navi": [["FR", "", "T", 4], ["FR", "", "S", 5]]},
			{"zona": "MOC", "navi": [["EN", "", "S", 4]], "capi": ["EN:Nelson"]}]
		d["trasporti_x"] = 2
		d["bonaparte_sbarco"] = true
		d["riforniti_turno1"] = [0]
		d["marcatore_alleanza"]["da"] = "1798-08"
		d["eventi"].append({"id": "egitto_in_guerra", "lato": 0, "se": {"t": "entra_stato", "lato": 0, "stati": ["EG"]},
			"effetti": [{"e": "attiva", "codici": ["Mm"], "t": "I Mamelucchi prendono le armi contro l'invasore"}]})
		d["rinforzi_data"]["1798-10"].append({"ritira": {"capi": ["Nelson"], "navi": [["EN", "", "S", 1]]}, "lato": 1})
		d["rinforzi_data"]["1799-01"] = [{"flotta_mare": "MOC", "navi": [["EN", "", "S", 1]], "lato": 1}]
		d["rinforzi_data"]["1799-07"] = [{"flotta_mare": "MOR", "navi": [["RU", "", "S", 1]], "lato": 1}]
		d["rinforzi_data"]["1799-10"].append({"flotta_mare": "MOC", "navi": [["EN", "", "S", 1]], "lato": 1})
		d["punti_egitto"] = {"citta": citta, "soglie": [10, 7, 5], "bonaparte_francia": true, "bonus": 1}
		d["vittoria"] = "Come lo scenario dell'Egitto, con le flotte: l'armata parte da Tolone su 4 trasporti (capacità doppia) scortati da 5 squadre; Nelson incrocia nel Mediterraneo occidentale con 4 squadre. Le forze egiziane restano neutrali finché i Francesi non sbarcano. Punti città: 10-13 vittoria decisiva francese, 7-9 marginale, 5-6 pareggio, 3-4 vittoria marginale alleata, 0-2 decisiva; +1 se Bonaparte è in una città di Francia a fine partita, +1 per La Valletta (Malta non ha esagoni sulla mappa: si considera presa durante la traversata)."
	return d

# =============================================================================================
# III. Marengo: la campagna d'Italia del 1800

static func _marengo() -> Dictionary:
	return {
		"id": "1800",
		"titolo": "Marengo 1800",
		"sottotitolo": "The Italian Campaign of 1800",
		"descrizione": "Aprile 1800: il Primo Console prepara un doppio assalto all'Austria. Moreau tiene il Reno, Massena è chiuso a Genova, la flotta inglese incrocia nel Mediterraneo e l'armata di riserva si raduna a Digione per piombare dalle Alpi alle spalle di Melas.",
		"durata": "Dieci turni mensili, da aprile 1800 a gennaio 1801.",
		"mese": 3, "anno": 1800, "turni": 10,
		"aree": [2, 3],
		"lati": {"FR": 0, "Sz": 0, "H": 0, "AU": 1, "B": 1, "I": 1, "R": 1, "Wu": 1, "Ba": 1, "N": 1, "EN": 1},
		"in_guerra": ["FR", "Sz", "H", "AU", "B", "I", "R", "Wu", "Ba"],
		"fonti": {"0": {"stati": ["FR"], "tutte": true}, "1": {"stati": ["B", "AU", "I"], "tutte": true}},
		"fonti_naz": {"EN": {"costa_propria": true, "porti_propri": true}},
		"morale_capo": {"naz": "FR", "capi": ["Napoleon"], "con": 2, "senza": 1},
		"morale": [{"naz": "AU", "tipi": ["I", "C"], "val": 2}],
		"rinforzi_persi": true,
		"mare": {"lato": 1, "naz": ["EN"], "max_sp": 99, "max_capi": -1, "da": "costa", "a": "porto_amico"},
		"sbarco": "costa_amica",
		"in_mare": [{"zona": "MOC", "capi": ["EN:@0"], "unita": U("EN 2I"), "dove": "costa_amica", "lato": 1}],
		"schieramento": [
			G("Mainz", ["FR:Moreau"], "FR 8I 2C"),
			G("Coblenz", ["FR:@0"], "FR 4I"),
			G("Strasbourg", ["FR:@0"], "FR 5I 1C"),
			G("Geneva", ["FR:Lannes"], "FR 4I"),
			G("Dijon", ["FR:Kellermann", "FR:@0"], "FR 6I 1C"),
			G("#40,28", ["FR:Soult"], "FR 3I"),
			G("Genoa", ["FR:Massena"], "FR 6I 1C"),
			G("Turin", ["FR:@0"], "FR 2I"),
			G("Paris", ["FR:Napoleon"]),
			G("Toulon", [], "FR 1I"), G("Marseilles", [], "FR 1I"), G("Lyon", [], "FR 1I"),
			G("Milan", ["AU:Melas"], "AU 8I 1C"),
			G("Mantua", ["AU:@0"], "AU 5I 1C"),
			G("Venice", ["AU:@0"], "AU 4I 1C"),
			G("Baden", [], "AU 3I"),
			G("Stuttgart", ["AU:Kray"], "AU 6I 1C"),
			G("#31,28", ["AU:@0"], "AU 5I 1C"),
			G("Ulm", [], "AU 1C"),
			G("Wurzburg", [], "AU 3I 1C"),
			G("Frankfurt", [], "AU 2I 1C 1L"),
			G("Innsbruck", [], "AU 1I"), G("Munich", [], "AU 1I"), G("Ratisbon", [], "AU 1I"), G("Leoben", [], "AU 1I"),
			G("Florence", [], "AU 4L"),
		],
		"rinforzi_data": {
			"1800-05": [G("Dijon", [], "FR 2I")],
			"1800-09": [G("Paris", [], "FR 1C")],
		},
		"ogni_turno": [
			G("Lyon", [], "FR 2I", {"da": "1800-05", "alt": ["Strasbourg", "Paris"]}),
			G("Vienna", [], "AU 2I", {"alt": ["Budapest"]}),
			{"mare": "MOC", "unita": U("EN 1I"), "lato": 1, "dove": "costa_amica",
				"se": {"t": "non", "test": {"t": "o", "tests": [{"t": "occupa", "lato": 0, "citta": ["Genoa"]}, {"t": "occupa", "lato": 0, "citta": ["Florence"]}]}}},
		],
		"alleanze": {"da": "1800-11", "chi": [0], "esiti": {"0": [{"e": "vittoria", "lato": 0, "perche": "L'Austria, sconfitta, firma la pace di Lunéville."}]}, "fine": ["0"]},
		"punti_citta": [{}, {}],
		"vittoria_cond": [
			{"vince": 0, "segmento": 0, "test": {"t": "e", "tests": [{"t": "occupa", "lato": 0, "citta": ["Mantua", "Milan", "Venice"], "rif": true}, {"t": "occupa", "lato": 0, "stati": ["AU", "B"], "min": 3, "rif": true}]}, "perche": "I Francesi tengono Mantova, Milano, Venezia e tre città dell'Austria o della Baviera."},
			{"vince": 0, "segmento": 0, "test": {"t": "occupa", "lato": 0, "citta": ["Vienna", "Budapest"], "min": 1, "rif": true}, "perche": "I Francesi sono a Vienna o a Budapest."},
			{"vince": 1, "segmento": 1, "test": {"t": "o", "tests": [{"t": "occupa", "lato": 1, "stati": ["FR"], "min": 5, "rif": true}, {"t": "occupa", "lato": 1, "citta": ["Paris"], "rif": true}]}, "perche": "Gli Austriaci occupano cinque città francesi o Parigi."},
		],
		"vince_default": 1,
		"perche_default": "L'Austria resiste fino a gennaio 1801.",
		"obiettivi": [{"Mantua": 6, "Milan": 7, "Venice": 5, "Munich": 4, "Ulm": 2, "Innsbruck": 3, "Vienna": 8, "Genoa": 3},
			{"Genoa": 5, "Turin": 3, "Lyon": 3, "Dijon": 3, "Strasbourg": 3, "Toulon": 2, "Paris": 4}],
		"ia": {"difendi": [{"Genoa": 5, "Strasbourg": 3}, {"Mantua": 5, "Milan": 5, "Vienna": 8}]},
		"vittoria": "Vittoria francese subito (a fine turno francese) con Mantova, Milano, Venezia e tre città dell'Austria o della Baviera occupate e rifornite, oppure con Vienna o Budapest, oppure se da novembre 1800 il dado delle alleanze dei Francesi dà 0 (l'Austria fa la pace). Vittoria austriaca occupando cinque città francesi o Parigi, o resistendo fino a gennaio 1801. Gli Inglesi partono in mare e si muovono da porto a porto; ricevono 1 PF in mare ogni turno in cui Genova e Firenze sono libere dai Francesi. I Francesi hanno morale 2 solo con Napoleone, gli Austriaci regolari hanno morale 2.",
		"margine": 0,
	}

# =============================================================================================
# V. L'apogeo di Napoleone: 1806-1807

static func _apogeo() -> Dictionary:
	var baltico := ["Lubeck", "Stralsund", "Stettin", "Danzig", "Konigsberg", "Memel"]
	return {
		"id": "1806",
		"titolo": "Jena e Friedland 1806",
		"sottotitolo": "Napoleon's Apogee 1806-1807",
		"descrizione": "Ottobre 1806: la Prussia ha dichiarato guerra. La Grande Armée è in Franconia, Brunswick e Hohenlohe sono attorno a Lipsia e Weimar. Dietro la Vistola i Russi arrivano a ondate per tutto l'inverno, e l'Austria resta a guardare.",
		"durata": "Dieci turni mensili, da ottobre 1806 a luglio 1807.",
		"mese": 9, "anno": 1806, "turni": 10,
		"aree": [2, 3, 4],
		"lati": {"FR": 0, "B": 0, "R": 0, "H": 0, "I": 0, "N": 0, "Wu": 0, "Ba": 0, "Sz": 0,
			"PR": 1, "S": 1, "Br": 1, "He": 1, "Ha": 1, "RU": 1, "Sw": 1, "AU": 1},
		"in_guerra": ["FR", "B", "R", "H", "I", "N", "Wu", "Ba", "PR", "S", "Br", "He", "Ha", "RU", "Sw"],
		"fonti": {"0": {"citta": ["Milan", "Munich"], "stati": ["FR", "H"]}, "1": {"patria": true, "citta": baltico}},
		"rinforzi_persi": true,
		"mare": {"lato": 1, "naz": ["RU"], "max_sp": 2, "max_capi": 1, "da": "porto", "a": "porto_amico", "citta": baltico, "assediati": true, "estate": true, "anni": [1807]},
		"schieramento": [
			G("Mainz", ["FR:Napoleon"], "FR 2I 2GI"),
			G("Stuttgart", ["FR:Davout"], "FR 5I 1C; FR:Wu 2I"),
			G("Wurzburg", ["FR:Lannes", "FR:Murat"], "FR 3I 4C; FR:Wu 2I"),
			G("Ratisbon", ["FR:Soult"], "FR 5I 1C"),
			G("Ulm", ["FR:Ney"], "FR 4I; FR:B 1I"),
			G("Ansbach", ["FR:Bernadotte"], "FR 4I 1C"),
			G("Florence", ["FR:Massena"], "FR 2I 1C; FR:N 5I"),
			G("Milan", ["FR:Eugene"], "FR 3I; FR:I 4I 1C"),
			G("Trieste", ["FR:Marmont"], "FR:Da 2I"),
			G("Frankfurt", ["FR:@0"], "FR 4I; FR:R 1I"),
			G("Boulogne", ["FR:@0"], "FR 5I"),
			G("Amsterdam", ["FR:@0:H"], "FR:H 3I 1C"),
			G("Munich", [], "FR:B 2I 1C"),
			G("Baden", [], "FR:R 1I"), G("Cologne", [], "FR:R 1I"),
			G("Leipzig", ["PR:Brunswick"], "PR 10I 3C"),
			G("Leipzig+s", ["PR:Hohenlohe", "PR:@0:S"], "PR 4I 1C; PR:S 2I 1C"),
			G("Weimar", ["PR:Ruchel"], "PR 4I 1C"),
			G("Berlin", ["PR:@0"], "PR 4I 1C"),
			G("Posen", ["PR:@0"], "PR 4I 1C"),
			G("Breslau", [], "PR 1I"), G("Stettin", [], "PR 1I"), G("Danzig", [], "PR 1I"), G("Thorn", [], "PR 1I"),
			G("Warsaw", [], "PR 1I"), G("Konigsberg", [], "PR 1I"),
			G("Brunswick", [], "PR:Br 1I"), G("Cassel", [], "PR:He 1I"),
			G("Stralsund", [], "RU:Sw 2I"), G("Lubeck", [], "RU:Sw 1I"),
		],
		"rinforzi_data": {
			"1806-10": [G("Mainz", ["FR:@0"], "FR 2I"), G("Munich", [], "FR:B 1I"), G("Cologne", [], "FR:R 1I")],
			"1806-11": [G("Frankfurt", [], "FR:R 1I"), G("Grodno", ["RU:Bennigsen"], "RU 10I 1C 1CC")],
			"1806-12": [G("Frankfurt", [], "FR:R 1I"), G("Kovno", ["RU:Buxhowden"], "RU 10I 1C 1CC")],
			"1807-01": [G("Cologne", [], "FR:H 1I"), G("Brest-Litovsk", ["RU:@0"], "RU 4I 1C")],
			"1807-02": [G("Milan", [], "FR:I 3I"), G("Florence", [], "FR:N 3I"), G("Kovno", ["RU:Bagration"], "RU 2I 2GI 1GC")],
		},
		"ogni_turno": [
			G("Mainz", [], "FR 2I", {"da": "1806-11"}),
			G("Berlin", [], "PR 1I"),
			G("Memel", [], "RU 1I", {"da": "1807-03"}),
			G("Warsaw", [], "FR:Po 1I", {"se": {"t": "controlla", "lato": 0, "citta": ["Warsaw"]}}),
		],
		"eventi": [{"id": "sassonia", "lato": 0, "se": {"t": "controlla", "lato": 0, "citta": ["Dresden"]},
			"effetti": [{"e": "elimina", "coppie": [["PR", "S"]], "t": "La Sassonia passa con Napoleone"}, {"e": "rinforzi", "gruppi": [G("Dresden", [], "FR:S 1I")]}]}],
		"alleanze": {"da": 2, "esiti": {
			"0": [{"e": "flag", "k": "austria_neutrale", "t": "L'Austria resterà neutrale"}],
			"7": [{"e": "attiva", "codici": ["AU"]}, {"e": "guerra", "stati": ["AU"], "lato": 1},
				{"e": "schiera", "gruppi": [G("Vienna", ["AU:Charles"], "AU 7I 3C"), G("Prague", ["AU:Ferdinand"], "AU 7I 3C"), G("Budapest", ["AU:John"], "AU 7I 3C")], "t": "L'Austria dichiara guerra alla Francia!"}]},
			"fine": ["0", "7"]},
		"punti_citta": [{"Berlin": 1}, {}],
		"vittoria_cond": [{"vince": 1, "quando": "fine", "test": {"t": "occupa", "lato": 1, "stati": ["PR", "S", "Ha"], "maggiori": true, "min": 1, "libere": true},
			"perche": "La Coalizione tiene ancora una città maggiore di Prussia, Sassonia o Hannover."}],
		"vince_default": 0,
		"perche_default": "Le città maggiori di Prussia, Sassonia e Hannover sono tutte in mano francese: pace di Tilsit.",
		"obiettivi": [{"Berlin": 8, "Leipzig": 4, "Dresden": 4, "Magdeburg": 6, "Hanover": 4, "Hamburg": 3, "Warsaw": 5, "Danzig": 3, "Konigsberg": 5, "Breslau": 3, "Posen": 3},
			{"Berlin": 4, "Magdeburg": 3, "Dresden": 2, "Leipzig": 2}],
		"ia": {"difendi": [{}, {"Berlin": 6, "Magdeburg": 5, "Konigsberg": 4, "Breslau": 3}]},
		"vittoria": "La Coalizione vince se a fine luglio 1807 ha almeno un punto forza non assediato in una città maggiore di Prussia, Sassonia o Hannover; altrimenti vince la Francia. Punti città: Francia 1 per Berlino. Alleanze: con 7 l'Austria entra in guerra (Carlo, Ferdinando e Giovanni con 21 PF), con 0 resta neutrale; nessuno entra in Austria prima. La Sassonia passa ai Francesi quando prendono Dresda; Varsavia francese dà 1 PF polacco ogni turno. Nel 1807, fuori dall'inverno, i Russi spostano 2 PF via mare fra i porti del Baltico.",
		"margine": 0,
	}

# =============================================================================================
# VI. Wagram 1809

static func _wagram() -> Dictionary:
	var magg_au := ["Vienna", "Prague", "Budapest", "Cracow"]
	var landwehr := func(n: int) -> Array:
		var out := []
		for c in magg_au:
			out.append(G(c, [], "AU %dL" % n))
		return out
	var rd := {
		"1809-04": [G("Strasbourg", ["FR:Lannes", "FR:Bessieres", "FR:Victor"]), G("Milan", ["FR:@0"], "FR 2I; FR:I 3I")],
		"1809-05": [G("Mainz", [], "FR 3I 1C")],
		"1809-06": [G("Warsaw", [], "FR:Po 1I", {"alt": ["Thorn"]})],
		"1809-07": [G("Paris", [], "FR 8I"), G("Mainz", [], "FR 3I"), G("Antwerp+o", ["EN:@0"], "EN 8I", {"regola": "persi"})],
		"1809-08": [G("London", [], "EN 1I")],
		"1809-09": [G("London", [], "EN 1I")],
	}
	for m in ["1809-04", "1809-05"]:
		rd[m].append_array(landwehr.call(1))
	for m in ["1809-06", "1809-07", "1809-08"]:
		rd[m].append_array(landwehr.call(2))
	for m in ["1809-09", "1809-10"]:
		if not rd.has(m):
			rd[m] = []
		rd[m].append_array(landwehr.call(1))
	var russi := [G("Grodno", ["RU:@0"], "RU 5I 1C")]
	return {
		"id": "1809",
		"titolo": "Wagram 1809",
		"sottotitolo": "Wagram — la guerra della Quinta Coalizione",
		"descrizione": "Marzo 1809: l'Austria attacca mentre il grosso francese è in Spagna. L'arciduca Carlo avanza in Baviera, Giovanni in Italia, Ferdinando in Polonia. La Germania del nord ribolle, gli Inglesi preparano lo sbarco di Walcheren e Prussia e Russia aspettano di vedere chi vince.",
		"durata": "Otto turni mensili, da marzo a ottobre 1809.",
		"mese": 2, "anno": 1809, "turni": 8,
		"aree": [2, 3],
		"lati": {"FR": 0, "H": 0, "B": 0, "I": 0, "N": 0, "R": 0, "Wu": 0, "Ba": 0, "S": 0, "D": 0, "Sz": 0, "Ha": 0, "He": 0, "Br": 0,
			"AU": 1, "EN": 1, "PR": 1, "RU": 1},
		"in_guerra": ["FR", "H", "B", "I", "N", "R", "Wu", "Ba", "S", "D", "Ha", "He", "Br", "AU", "PR", "EN"],
		"neutrali": ["PR", "RU"],
		"controllo": {"Venice": 0, "Innsbruck": 0, "Danzig": 0, "Stettin": 0, "Thorn": 0, "Warsaw": 0, "Posen": 0},
		"vietate": {"Berlin": "PR"},
		"fonti": {"0": {"iniziali": true}, "1": {"patria": true}},
		"fonti_naz": {"EN": {"hex": ["Antwerp+o"], "citta": ["London"], "porti_propri": true}},
		"sempre_riforniti": ["Br", "He"],
		"solo_capi_turno1": true,
		"rinforzi_persi": true,
		"mare": {"lato": 1, "naz": ["EN"], "max_sp": 99, "max_capi": -1, "da": "costa", "a": "costa_libera", "esagoni": ["London", "Antwerp+o", "Antwerp", "Amsterdam"]},
		"schieramento": [
			G("Paris", ["FR:Napoleon"]), G("Dresden", ["FR:Bernadotte"], "FR:S 2I 1C"), G("Florence", ["FR:Murat"], "FR:N 4I"),
			G("Venice", ["FR:Eugene"], "FR:I 3I 1C"), G("Warsaw", ["FR:Poniatowski"], "FR:Po 2I 1C"),
			G("Ratisbon", ["FR:Davout"], "FR 4I 6C"),
			G("Ulm+e", ["FR:@0"], "FR 4I"),
			G("Trieste+s", ["FR:Marmont"], "FR 2I; FR:Da 1I"),
			G("Ulm", ["FR:Massena"], "FR 8I"),
			G("Strasbourg", [], "FR 2I 2GI 1GC"), G("Mainz", [], "FR 1I 1C"),
			G("Antwerp", [], "FR 1I"), G("Bremen", [], "FR 1I"), G("Danzig", [], "FR 1I"), G("Hamburg", [], "FR 1I"),
			G("Hanover", [], "FR 1I"), G("Stettin", [], "FR 1I"), G("Stralsund", [], "FR 1I"), G("Thorn", [], "FR 1I"),
			G("Cassel", ["FR:Jerome:W"], "FR:W 3I"), G("Amsterdam", ["FR:@0:H"], "FR:H 4I 1C"), G("Munich", ["FR:@0:B"], "FR:B 5I 1C"),
			G("Frankfurt", [], "FR:R 1I; FR:Pt 1I"), G("Stuttgart", [], "FR:Wu 2I"), G("Baden", [], "FR:R 1I"), G("Lubeck", [], "FR:D 1I"),
			G("Vienna+o", ["AU:Charles", "AU:Hiller", "AU:Louis"], "AU 25I 4C"),
			G("Leoben", ["AU:John", "AU:@0"], "AU 8I 6L 2C"),
			G("Prague+o", ["AU:@0", "AU:@0"], "AU 9I 1C"),
			G("Lublin", ["AU:Ferdinand"], "AU 7I 1C"),
			G("Vienna", ["AU:@0"], "AU 2I"), G("Budapest", [], "AU 3I"), G("Innsbruck", [], "AU 3L"),
			G("Olmutz", [], "AU 1L"),
		],
		"ogni_turno": [G("Strasbourg", [], "FR 1I")],
		"rinforzi_data": rd,
		"alleanze": {"da": 2, "esiti": {
			"0": [{"e": "lato", "naz": "RU", "lato": 0, "se": {"t": "non", "test": {"t": "flag", "k": "russia"}}},
				{"e": "attiva", "codici": ["RU"], "se": {"t": "non", "test": {"t": "flag", "k": "russia"}}},
				{"e": "schiera", "gruppi": russi, "se": {"t": "non", "test": {"t": "flag", "k": "russia"}}, "t": "La Russia dichiara guerra all'Austria"},
				{"e": "flag", "k": "russia"}],
			"7": [{"e": "lato", "naz": "RU", "lato": 1, "se": {"t": "non", "test": {"t": "flag", "k": "russia"}}},
				{"e": "attiva", "codici": ["RU"], "se": {"t": "non", "test": {"t": "flag", "k": "russia"}}},
				{"e": "schiera", "gruppi": russi, "se": {"t": "non", "test": {"t": "flag", "k": "russia"}}, "t": "La Russia dichiara guerra alla Francia"},
				{"e": "flag", "k": "russia"},
				{"e": "schiera", "gruppi": [G("Prague", ["PR:Brunswick"], "PR:Br 1I"), G("Brunswick", ["PR:@0"], "PR:Br 1I"), G("Cassel+e", ["PR:@0"], "PR:He 1I")], "t": "La Germania del nord insorge"}],
			"7b": [{"e": "attiva", "codici": ["PR"]}, {"e": "flag", "k": "prussia"},
				{"e": "schiera", "gruppi": [G("Berlin", ["PR:Blucher", "PR:Kleist", "PR:Yorck"], "PR 6I 2L 1C")], "t": "La Prussia dichiara guerra alla Francia!"},
				{"e": "perdi", "sub": ["B", "R", "S", "Wu"], "n": 1, "t": "Disertano i satelliti tedeschi"}]},
			"fine": ["0b", "7b"]},
		"punti_regole": [{"lato": 0, "stati": ["AU"]}, {"lato": 1, "satelliti": true}],
		"punti_citta": [{}, {"Venice": 1}],
		"vittoria_cond": [{"vince": 0, "quando": "fine", "test": {"t": "controlla", "lato": 0, "citta": ["Vienna", "Prague", "Cassel"], "libere": true},
			"perche": "Napoleone controlla Vienna, Praga e Cassel: pace di Schönbrunn."}],
		"vince_default": 1,
		"perche_default": "Vienna, Praga o Cassel non sono in mano francese: l'Austria ha resistito.",
		"obiettivi": [{"Vienna": 12, "Prague": 8, "Cassel": 4, "Budapest": 2, "Olmutz": 2},
			{"Munich": 4, "Ratisbon": 3, "Dresden": 3, "Warsaw": 3, "Cassel": 4, "Ulm": 2, "Venice": 3}],
		"ia": {"difendi": [{"Cassel": 4, "Munich": 3}, {"Vienna": 10, "Prague": 6}]},
		"vittoria": "Il Francese vince se a fine ottobre controlla Vienna, Praga e Cassel, tutte non assediate; altrimenti vince la Coalizione. Al primo turno i Francesi muovono solo i capi. Punti città: Francia 1 per città maggiore austriaca, Coalizione 1 per città maggiore dei satelliti francesi (Venezia compresa). Alleanze: con 0 la Russia entra in guerra contro l'Austria (5I 1C a Grodno per il Francese); con 7 la Russia contro la Francia e insorgono Brunswick e Assia; con il secondo 7 la Prussia dichiara guerra e disertano Bavaresi, Renani, Sassoni e Württemberghesi. Nessuno entra a Berlino finché la Prussia non è in guerra. A luglio 8 PF inglesi sbarcano vicino ad Anversa (Walcheren) e si muovono via mare da e per Londra.",
		"margine": 0,
	}

# =============================================================================================
# VII. La campagna di Russia 1812 (e XIII. The Final Glory: 1812-1814 collegati)

static func _russia(collegato: bool) -> Dictionary:
	var d := {
		"id": "1812g" if collegato else "1812",
		"titolo": "The Final Glory 1812-14" if collegato else "Russia 1812",
		"sottotitolo": "Russia, Germania e Francia collegate" if collegato else "The Campaign in Russia",
		"descrizione": ("La campagna di Russia, poi la Germania nel 1813 e la Francia nel 1814 in un'unica partita: se Napoleone non vince in Russia, la guerra continua con l'area 2 dal marzo 1813 e la Spagna dal gennaio 1814." if collegato else "Maggio 1812: oltre mezzo milione di uomini sono ammassati sul Niemen. Davout a Danzica, Napoleone a Dresda, gli alleati austriaci e prussiani sulle ali. Barclay e Bagration aspettano dall'altra parte, e dietro di loro c'è l'inverno russo."),
		"durata": ("Trentadue turni mensili, da maggio 1812 a dicembre 1814." if collegato else "Otto turni mensili, da maggio a dicembre 1812."),
		"mese": 4, "anno": 1812, "turni": 32 if collegato else 8,
		"aree": [3, 4],
		"lati": {"FR": 0, "PR": 0, "AU": 0, "S": 0, "Ha": 0, "He": 0, "Br": 0, "D": 0, "B": 0, "R": 0, "Wu": 0, "Ba": 0, "I": 0, "N": 0, "H": 0, "Sz": 0,
			"RU": 1, "Sw": 1, "EN": 1, "SP": 1, "Pt": 1},
		"in_guerra": ["FR", "PR", "S", "Ha", "He", "Br", "D", "RU"],
		"neutrali": ["Sw"],
		"fonti": {"0": {"iniziali": true}, "1": {"patria": true, "tutte": true, "perdute": true}},
		"fonti_naz": {"AU": {"patria": true}, "PR": {"patria": true}},
		"morale": [{"naz": "RU", "tipi": ["I", "C"], "area": 4, "val": 3}],
		"porta": {"Davout": 15},
		"rinforzi_regola": "vicina",
		"schieramento": [
			G("Dresden", ["FR:Napoleon", "FR:@0"], "FR:I 2I; FR:N 1I; FR:R 2I"),
			G("Danzig", ["FR:Davout"], "FR 12I 1C; FR:R 2I; FR:Sz 1I"),
			G("Posen", ["FR:Bessieres"], "FR 6GI 1GC; FR:Po 2I; FR:R 1I"),
			G("Thorn", ["FR:Ney"], "FR 5I 1C; FR:Da 1I; FR:Wu 3I"),
			G("Thorn+e", ["FR:Eugene"], "FR 3I 1C"),
			G("Thorn+s", ["FR:Murat"], "FR 4C"),
			G("Thorn+n", ["FR:@0"], "FR:B 5I 1C; FR:I 4I 1C; FR:Pt 1I; FR:Po 1C"),
			G("Danzig>", ["FR:@0"], "FR 6I"),
			G("Warsaw+e", ["FR:Poniatowski", "FR:@0", "FR:Jerome:W", "FR:@0"], "FR:Po 6I 2C; FR:S 3I 1C; FR:W 3I 1C"),
			G("Stettin", ["FR:Victor"], "FR 2I; FR:Po 1I; FR:R 3I"),
			G("Konigsberg", ["FR:@0", "PR:Yorck"], "FR:Po 1I; FR:W 1I; PR 4I 1C"),
			G("Hanover", [], "FR:W 1I"), G("Lubeck", [], "FR:D 2I"),
			G("Lublin", ["AU:Schwarzenberg"], "AU 5I 2C"),
			G("Vilna+o", ["RU:Barclay", "RU:Constantine"], "RU 3I 3GI 1GC"),
			G("Brest-Litovsk+e", ["RU:Bagration"], "RU 8I 2C 2CC"),
			G("Grodno+e", ["RU:Docturov"], "RU 4I 1C 2CC"),
			G("Pinsk+o", ["RU:Tormazov"], "RU 7I 2C"),
			G("Kovno+e", ["RU:Wittgenstein"], "RU 4I"),
			G("Vilna", ["RU:Bennigsen"], "RU 3I"),
			G("Kovno", ["RU:@0"], "RU 3I 1C"),
			G("Moscow", [], "RU 2I"), G("Riga", [], "RU 2I"),
			G("Kharkov", [], "RU 1I"), G("Kiev", [], "RU 1I"), G("Minsk", [], "RU 1I"), G("Vitebsk", [], "RU 1I"),
		],
		"ogni_turno": [
			G("Dresden", [], "FR 1I", {"regola": "persi", "a": "1813-02"}),
			G("Warsaw", [], "FR:Po 1I", {"rimpiazzo": true, "regola": "persi"}),
			G("Dresden", [], "FR:* 1I", {"rimpiazzo": true, "regola": "persi"}),
			G("Moscow", [], "RU 2I", {"a": "1812-12" if collegato else "1812-12"}),
			G("Kiev", [], "RU 1I", {"a": "1812-12"}),
			G("Moscow", [], "RU 1CC", {"rimpiazzo": true}),
		],
		"rinforzi_data": {
			"1812-08": [G("Kiev", ["RU:@0"], "RU 5I 2C")],
			"1812-09": [G("Moscow", ["RU:Kutusov"]), G("St Petersburg", ["RU:@0"], "RU 5I")],
			"1812-10": [G("Danzig", [], "FR 2C", {"regola": "persi"}), G("Moscow", [], "RU 2CC"), G("Kiev", [], "RU 1CC")],
		},
		"alleanze": {"da": "1812-11", "esiti": {
			"0": [{"e": "schiera", "gruppi": [G("Lublin", [], "AU 1I")], "t": "Rinforzi austriaci per Napoleone"}],
			"7": [{"e": "elimina", "naz": ["AU", "PR"], "t": "Austriaci e Prussiani abbandonano Napoleone"},
				{"e": "rimuovi_capo", "nomi": ["Napoleon"], "t": "Napoleone torna a Parigi per il colpo di stato di Malet"}]},
			"fine": ["7"]},
		"punti_regole": [{"lato": 0, "aree": [4]}, {"lato": 1, "aree": [3, 4]}],
		"punti_citta": [{}, {}],
		"vittoria_cond": [
			{"vince": 0, "quando": "fine", "test": {"t": "e", "tests": [{"t": "controlla", "lato": 0, "citta": ["Warsaw", "Smolensk"], "libere": true}, {"t": "controlla", "lato": 0, "citta": ["Moscow", "St Petersburg"], "min": 1, "libere": true}]},
				"perche": "Napoleone tiene Varsavia, Smolensk e Mosca o San Pietroburgo: lo Zar chiede la pace."},
			{"vince": 1, "quando": "fine", "test": {"t": "nessuna_area", "lato": 0, "area": 4}, "perche": "Non resta un solo punto forza francese nelle città russe."},
		],
		"vince_default": -1,
		"perche_default": "Nessuno ha raggiunto le sue condizioni: pareggio.",
		"obiettivi": [{"Vilna": 4, "Kovno": 3, "Minsk": 4, "Vitebsk": 4, "Smolensk": 8, "Moscow": 10, "Riga": 3, "St Petersburg": 5, "Grodno": 3, "Brest-Litovsk": 3},
			{"Vilna": 3, "Minsk": 3, "Warsaw": 4, "Konigsberg": 3, "Danzig": 2}],
		"ia": {"difendi": [{"Warsaw": 5, "Smolensk": 4}, {"Moscow": 10, "Smolensk": 6, "St Petersburg": 6}]},
		"vittoria": "Il Francese vince se a fine dicembre 1812 controlla Varsavia, Smolensk e Mosca o San Pietroburgo, tutte non assediate; la Coalizione vince se non resta nessun punto forza francese non assediato nelle città dell'area 4 (la Russia); altrimenti pareggio. I Russi regolari nell'area 4 hanno morale 3 (patriottismo), i cosacchi 0; Davout porta fino a 15 PF. Alleanze solo da novembre: con 0 un PF austriaco in più per Napoleone; con 7 Austriaci e Prussiani disertano e Napoleone torna a Parigi.",
		"margine": 0,
	}
	if collegato:
		_collega_1813_1814(d)
	return d

## XIII. The Final Glory: dal marzo 1813 l'area 2 e le regole del 1813, dal gennaio 1814 l'area 1
static func _collega_1813_1814(d: Dictionary) -> void:
	var n13 := _nazioni()
	var rd: Dictionary = d["rinforzi_data"]
	rd["1812-12"] = [{"ritira": {"unita": [["FR", "S", "*", 99], ["FR", "N", "*", 99], ["FR", "Sz", "*", 99], ["FR", "B", "*", 99]]}, "lato": 0}]
	rd["1813-01"] = [G("Milan", [], "FR:I 2I"), G("Stuttgart", [], "FR:Wu 2I"), G("Frankfurt", [], "FR:R 1I"), G("Cassel", [], "FR:W 1I"),
		G("Munich", [], "FR:B 4I 1C", {"anche_neutrali": true, "lato": 0}), G("Florence", [], "FR:N 4I", {"anche_neutrali": true, "lato": 0}),
		G("Dresden", [], "FR:S 2I", {"anche_neutrali": true, "lato": 0}), G("Geneva", [], "FR:Sz 4I", {"anche_neutrali": true, "lato": 0})]
	rd["1813-03"] = n13["schieramento"].filter(func(g): return str(g["capi"]).contains("AU:") or (not g["unita"].is_empty() and g["unita"][0][0] == "AU"))
	for g in rd["1813-03"]:
		g["lato"] = 1
		g["anche_neutrali"] = true
	rd["1813-04"] = [G("Mainz", ["FR:Marmont", "FR:Soult", "FR:Napoleon"], "FR 18I 2GI 1GC"), G("Stralsund", ["RU:Bernadotte:Sw"], "RU:Sw 5I 1C", {"anche_neutrali": true, "lato": 1})]
	rd["1813-05"] = [G("Mainz", [], "FR 2I"), G("Hanover", [], "FR:W 2I"), G("Milan", [], "FR:I 1I"), G("Stuttgart", [], "FR:Wu 1I"),
		G("Prague", [], "AU 1C", {"anche_neutrali": true, "lato": 1}), G("Berlin", [], "PR 1C")]
	rd["1813-06"] = [G("Mainz", [], "FR 8I"), G("Milan", [], "FR:I 3I"), G("Stuttgart", [], "FR:Wu 1I"),
		G("Prague", [], "AU 1C", {"anche_neutrali": true, "lato": 1}), G("Berlin", [], "PR 1C")]
	rd["1813-07"] = [G("Mainz", [], "FR 10I 6GI 6C")]
	rd["1813-08"] = [G("Mainz", ["FR:@0"], "FR 2I 1C")]
	rd["1813-09"] = [G("Mainz", [], "FR 4I")]
	for m in ["1813-10", "1813-11", "1813-12"]:
		rd[m] = [G("Mainz", [], "FR 2I")]
	var n14 := _1814()
	rd["1814-01"] = [G("Paris", ["FR:Joseph"], "FR 8I"), G("Bayonne", ["FR:Soult"], "FR 11I 2C"), G("Barcelona>", [], "FR 7I 1C")]
	rd["1814-01"].append_array(n14["schieramento"].filter(func(g): return str(g["capi"]).contains("EN:") or str(g["capi"]).contains("SP:") or (not g["unita"].is_empty() and g["unita"][0][0] in ["EN", "SP"])))
	rd["1814-02"] = [G("Prague", ["AU:Bellegarde"])]
	d["ogni_turno"].append_array([
		G("Prague", [], "AU 2I 2L", {"da": "1813-04", "a": "1813-12", "anche_neutrali": true, "lato": 1}),
		G("Berlin", [], "PR 2I 2L", {"da": "1813-04", "a": "1813-12", "se": {"t": "flag", "k": "prussia"}}),
		G("Brest-Litovsk", [], "RU 2I 1C 1CC", {"da": "1813-01", "a": "1814-08"}),
		G("Paris", [], "FR 3I", {"da": "1814-01", "a": "1814-08"}), G("Lyon", [], "FR 1I", {"da": "1814-01", "a": "1814-08"}),
		G("Paris", [], "FR 1GI", {"da": "1814-01", "a": "1814-08", "rimpiazzo": true}),
		G("Prague", [], "AU 1I 1L", {"da": "1814-01", "a": "1814-08"}),
		G("Berlin", [], "PR 1I 1L", {"da": "1814-01", "a": "1814-08", "se": {"t": "flag", "k": "prussia"}}),
		G("London", [], "EN 2I", {"da": "1814-01", "a": "1814-08"}),
		G("San Sebastian", [], "EN:Pt 1I; SP 1I", {"da": "1814-01", "a": "1814-08"}),
	])
	# la Prussia entra in guerra quando la Coalizione prende Königsberg o Berlino
	d["eventi"] = [
		{"id": "prussia_k", "se": {"t": "e", "tests": [{"t": "non", "test": {"t": "flag", "k": "prussia"}}, {"t": "occupa", "lato": 1, "citta": ["Konigsberg"], "libere": true, "rif": true}]},
			"effetti": [{"e": "lato", "naz": "PR", "lato": 1}, {"e": "flag", "k": "prussia"},
				{"e": "schiera", "gruppi": [G("Konigsberg", ["PR:Blucher", "PR:Bulow", "PR:Kleist", "PR:Yorck", "PR:@0"], "PR 10I 3C 8L")], "t": "La Prussia passa alla Coalizione!"}]},
		{"id": "prussia_b", "se": {"t": "e", "tests": [{"t": "non", "test": {"t": "flag", "k": "prussia"}}, {"t": "occupa", "lato": 1, "citta": ["Berlin"], "libere": true, "rif": true}]},
			"effetti": [{"e": "lato", "naz": "PR", "lato": 1}, {"e": "flag", "k": "prussia"},
				{"e": "schiera", "gruppi": [G("Berlin", ["PR:Blucher", "PR:Bulow", "PR:Kleist", "PR:Yorck", "PR:@0"], "PR 10I 3C 8L")], "t": "La Prussia passa alla Coalizione!"}]},
		{"id": "austria_neutrale", "da": "1813-03", "effetti": [{"e": "lato", "naz": "AU", "lato": 1}, {"e": "neutrale", "codici": ["AU"], "t": "L'Austria si dichiara neutrale"}]},
		{"id": "satelliti_neutrali", "da": "1813-01", "effetti": [{"e": "neutrale", "codici": ["B", "N", "S", "Sz"]}]},
	]
	d["vittoria_cond"] = [
		{"vince": 0, "dal": "1812-12", "test": {"t": "e", "tests": [{"t": "controlla", "lato": 0, "citta": ["Warsaw", "Smolensk"], "libere": true}, {"t": "controlla", "lato": 0, "citta": ["Moscow", "St Petersburg"], "min": 1, "libere": true}]},
			"perche": "Napoleone tiene Varsavia, Smolensk e Mosca o San Pietroburgo: lo Zar chiede la pace."},
		{"vince": 0, "quando": "fine", "test": {"t": "controlla", "lato": 0, "citta": ["Paris"], "libere": true}, "perche": "Parigi è ancora libera a fine 1814: l'Impero sopravvive."},
	]
	d["vince_default"] = 1
	d["perche_default"] = "Parigi è perduta: Napoleone abdica."
	d["in_guerra"].append_array(["B", "R", "Wu", "Ba", "H", "I", "Sw", "Sz", "N", "Ha"])
	d["fasi"] = [
		{"da": "1813-01", "alleanze_1813": n13["alleanze_1813"], "punti_citta": [{"Berlin": 1, "Warsaw": 1}, n13["punti_citta"][1]],
			"punti_regole": [{"lato": 0, "stati": ["RU"]}], "alleanze": null},
		{"da": "1813-03", "aree": [2, 3, 4], "alleanze_1813": n13["alleanze_1813"], "punti_citta": [{"Berlin": 1, "Warsaw": 1}, n13["punti_citta"][1]],
			"punti_regole": [{"lato": 0, "stati": ["RU"]}], "punti_area2_coalizione": true, "alleanze": null,
			"chiusi_se_neutrali": {"AU": ["AU"]}, "aperti_area2": ["AU"],
			"fonti": {"0": {"iniziali": true, "stati": ["FR"], "citta": ["Hanover", "Milan"]}, "1": {"patria": true}}},
		{"da": "1814-01", "aree": [1, 2, 3, 4], "alleanze_1813": n13["alleanze_1813"], "punti_citta": [{"Berlin": 1, "Warsaw": 1}, n13["punti_citta"][1]],
			"punti_regole": [{"lato": 0, "stati": ["RU"]}], "punti_area2_coalizione": true, "alleanze": null,
			"chiusi_se_neutrali": {"AU": ["AU"]}, "aperti_area2": ["AU"],
			"fonti": {"0": {"stati": ["FR", "I"], "tutte": true, "citta": ["Hanover", "Milan"]}, "1": {"patria": true}},
			"fonti_naz": {"EN": {"costa_propria": true, "porti_propri": true}, "SP": {"stati": ["SP"], "tutte": true}},
			"mare": {"lato": 1, "naz": ["EN"], "max_sp": 2, "max_capi": 1, "da": "porto", "a": "porto_libero"}},
	]
	d["obiettivi"] = [{"Smolensk": 6, "Moscow": 8, "Vilna": 3, "Minsk": 3, "Warsaw": 4, "Berlin": 4, "Dresden": 4, "Leipzig": 3, "Paris": 4},
		{"Vilna": 3, "Warsaw": 4, "Konigsberg": 4, "Berlin": 5, "Dresden": 4, "Leipzig": 4, "Mainz": 3, "Paris": 10}]
	d["ia"] = {"difendi": [{"Warsaw": 4, "Dresden": 4, "Paris": 10}, {"Moscow": 8, "Berlin": 4}]}
	d["vittoria"] = "Prima si gioca la campagna di Russia: il Francese vince subito se a fine dicembre 1812 (o in un turno successivo) tiene Varsavia, Smolensk e Mosca o San Pietroburgo. Altrimenti la guerra continua: da gennaio 1813 valgono le alleanze del 1813 (Austria e Svezia neutrali, i satelliti esitano), da marzo 1813 entra in gioco l'area 2, da gennaio 1814 anche la Spagna. La Prussia passa alla Coalizione quando questa prende Königsberg o Berlino. A fine dicembre 1814 il Francese vince se tiene Parigi non assediata, altrimenti vince la Coalizione."

# =============================================================================================
# IX. Napoleone alle strette: 1814

static func _1814() -> Dictionary:
	return {
		"id": "1814",
		"titolo": "Francia 1814",
		"sottotitolo": "Napoleon at Bay",
		"descrizione": "Gennaio 1814: dopo Lipsia mezzo milione di soldati di Spagna, Inghilterra, Austria, Prussia e Russia è pronto a invadere la Francia. Napoleone, con pochi coscritti e la Guardia, deve difendere Parigi fino a maggio.",
		"durata": "Cinque turni mensili, da gennaio a maggio 1814.",
		"mese": 0, "anno": 1814, "turni": 5,
		"aree": [1, 2],
		"lati": {"FR": 0, "I": 0, "H": 0,
			"AU": 1, "PR": 1, "RU": 1, "EN": 1, "SP": 1, "Pt": 1, "Sz": 1, "B": 1, "Wu": 1, "Ba": 1, "R": 1, "He": 1, "Br": 1, "Ha": 1, "S": 1, "Sw": 1, "N": 1},
		"in_guerra": ["FR", "I", "H", "AU", "PR", "EN", "SP", "Pt", "Sz", "B", "Wu", "Ba", "R"],
		"controllo": {"Frankfurt": 0, "Wurzburg": 0, "Geneva": 0, "Neuchatel": 0, "Cologne": 0, "Mainz": 0},
		"fonti": {"0": {"stati": ["FR", "I"], "tutte": true}},
		"fonti_naz": {"AU": {"citta": ["Munich", "Munster"]}, "PR": {"citta": ["Munich", "Munster"]}, "RU": {"citta": ["Munich", "Munster"]},
			"SP": {"stati": ["SP"], "tutte": true}, "EN": {"stati": ["SP", "H"], "tutte": true, "porti_propri": true}},
		"rinforzi_regola": "vicina",
		"mare": {"lato": 1, "naz": ["EN"], "max_sp": 2, "max_capi": 1, "da": "porto", "a": "porto_libero"},
		"schieramento": [
			G("Paris", ["FR:Napoleon", "FR:Joseph"], "FR 6I 1GI"),
			G("Bayonne", ["FR:Soult"], "FR 11I 2C"),
			G("Coblenz", ["FR:Marmont", "FR:Ney"], "FR 2GI 1C"),
			G("Strasbourg", ["FR:Victor"], "FR 2I 1C"),
			G("Venice", ["FR:Eugene"], "FR:I 8I 1C"),
			G("Rheims", ["FR:@0"], "FR 2I 1GI"),
			G("Liege", ["FR:@0"], "FR 2I 1C"),
			G("Antwerp", ["FR:@0"], "FR 3I"),
			G("Barcelona+n", ["FR:@0"], "FR 6I 1C"),
			G("Mainz", [], "FR 3I"), G("Amsterdam", [], "FR 2I"), G("Namur", [], "FR 1GC"),
			G("Brussels", [], "FR 1I"), G("Cologne", ["FR:Jerome:W"], "FR 1I"), G("Geneva", [], "FR 1I"),
			G("Lyon", [], "FR 1I"), G("Neuchatel", [], "FR 1I"), G("Toulouse", [], "FR 1I"), G("Wurzburg", [], "FR 1I"),
			G("Milan", [], "FR:I 1I"), G("Metz", [], "FR:Po 1I"),
			G("Barcelona", ["SP:Cuesta", "EN:@0"], "SP 5I 1C; EN 4I"),
			G("San Sebastian", ["SP:Blake", "EN:Wellington", "EN:Beresford", "EN:Hill"], "SP 2I; EN 5I 1C; EN:K 1I; EN:Pt 6I"),
			G("Amsterdam>", ["EN:@0"], "EN 2I"),
			G("Zurich>", ["AU:Schwarzenberg", "AU:@0"], "AU 9I 5L 2C"),
			G("Trieste", ["AU:Hiller"], "AU 7I 3L 1C"),
			G("Ulm", ["AU:@0"], "AU 4L 1C"),
			G("Baden", ["AU:@0"], "AU 3L"),
			G("Florence", [], "AU 5L"),
			G("Innsbruck", [], "AU 1I 1L"),
			G("Geneva+e", [], "AU 2I"),
			G("Coblenz+e", ["PR:Blucher", "PR:Yorck"], "PR 3I 1L"),
			G("Amsterdam+e", ["PR:Bulow"], "PR 3I 2L 1C"),
			G("Munster", ["PR:Kleist", "RU:@0"], "PR 1I 1L 1C; RU 5I 2C 1CC"),
			G("Munich+o", ["PR:@0", "RU:Barclay", "RU:Constantine", "RU:Wittgenstein"], "PR 2I; RU 3I 4GI 1C 1GC 2CC"),
			G("Frankfurt+e", ["PR:@0:He", "RU:@0"], "PR:He 2I; RU 4I 1C 1CC"),
			G("Frankfurt", ["RU:@0"], "RU 5I 1C 1CC"),
		],
		"assedi": [["Frankfurt", 1]],
		"ogni_turno": [
			G("Paris", [], "FR 3I", {"regola": "persi"}), G("Lyon", [], "FR 1I", {"regola": "persi"}),
			G("Barcelona", [], "SP 1I"), G("London", [], "EN 1I"), G("San Sebastian", [], "EN:Pt 1I"),
			G("Munich", [], "AU 1I 1L; RU 1I"), G("Munster", [], "PR 1I 1L; RU 1I"),
			G("Amsterdam", ["EN:@0"], "EN 1L", {"una_volta": true, "se": {"t": "controlla", "lato": 1, "citta": ["Amsterdam"]}}),
			G("Antwerp", [], "EN 1L", {"una_volta": true, "se": {"t": "controlla", "lato": 1, "citta": ["Antwerp"]}}),
			G("Brussels", [], "EN:H 1I", {"una_volta": true, "se": {"t": "controlla", "lato": 1, "citta": ["Brussels"]}}),
		],
		"rinforzi_data": {
			"1814-01": [G("Paris", [], "FR 1GI 1C", {"regola": "persi"}),
				G("Munster", ["RU:Bernadotte:Sw", "PR:@0"], "RU:Sw 3I 1C; PR 1L; PR:S 3I; PR:Br 1I")],
			"1814-02": [G("Paris", [], "FR 3GI 1C", {"regola": "persi"}), G("Trieste", ["AU:Bellegarde"], "AU 2I 1L 1C"),
				G("London", [], "EN 2I"), G("Munster", [], "PR 1I")],
		},
		"eventi": [
			{"id": "partigiani", "lato": 0, "se": {"t": "entra_stato", "lato": 1, "stati": ["FR"]},
				"effetti": [{"e": "partigiani", "naz": "FR", "stato": "FR", "n": 2, "t": "La Francia invasa: si formano bande di partigiani"}, {"e": "flag", "k": "partigiani"}]},
		],
		"ogni_turno_partigiani": {"naz": "FR", "stato": "FR"},
		"punti_citta": [{}, {}],
		"vittoria_cond": [{"vince": 1, "quando": "fine", "test": {"t": "occupa", "lato": 1, "citta": ["Paris"], "libere": true, "rif": true},
			"perche": "Gli Alleati sono a Parigi: Napoleone abdica a Fontainebleau."}],
		"vince_default": 0,
		"perche_default": "Parigi resiste fino a maggio 1814.",
		"obiettivi": [{"Frankfurt": 2, "Brussels": 2, "Liege": 2}, {"Paris": 14, "Lyon": 3, "Rheims": 3, "Metz": 2, "Strasbourg": 2, "Bayonne": 2, "Toulouse": 2}],
		"ia": {"difendi": [{"Paris": 14, "Lyon": 3, "Rheims": 3}, {}]},
		"vittoria": "La Coalizione vince se a fine maggio 1814 ha almeno un punto forza rifornito e non assediato a Parigi; altrimenti vince la Francia. Niente alleanze. Quando il nemico entra in Francia nascono 2 PF di partigiani (si rimpiazzano se eliminati). Gli Inglesi spostano ogni turno 2 PF e un capo via mare fra i porti non francesi; la rivolta olandese dà rinforzi ad Amsterdam, Anversa e Bruxelles liberate.",
		"margine": 0,
	}

# =============================================================================================
# X. La campagna di Waterloo: 1815

static func _waterloo() -> Dictionary:
	return {
		"id": "1815",
		"titolo": "Waterloo 1815",
		"sottotitolo": "The Waterloo Campaign — i Cento Giorni",
		"descrizione": "Giugno 1815: Napoleone è tornato dall'Elba. Wellington e Blücher sono in Belgio, gli Austriaci si radunano sul Reno e in Italia, i Russi arriveranno ad agosto. Bisogna colpire subito, fra gli Anglo-olandesi e i Prussiani.",
		"durata": "Sette turni mensili, da giugno a dicembre 1815.",
		"mese": 5, "anno": 1815, "turni": 7,
		"aree": [2],
		"lati": {"FR": 0, "N": 0,
			"AU": 1, "PR": 1, "RU": 1, "EN": 1, "I": 1, "H": 1, "Sz": 1, "B": 1, "Wu": 1, "Ba": 1, "R": 1, "He": 1, "Br": 1, "Ha": 1, "S": 1},
		"in_guerra": ["FR", "N", "AU", "PR", "EN", "I", "H", "Sz", "B", "Wu", "Ba", "R"],
		"controllo": {"Geneva": 0, "Brussels": 1, "Namur": 1, "Liege": 1, "Antwerp": 1, "Mainz": 1, "Coblenz": 1, "Cologne": 1},
		"fonti": {"0": {"stati": ["FR", "I"], "tutte": true}},
		"fonti_naz": {"AU": {"citta": ["Munich", "Milan"]}, "EN": {"citta": ["Antwerp"], "porti_propri": true},
			"PR": {"citta": ["Liege", "Mainz", "Munster"]}, "RU": {"citta": ["Frankfurt", "Wurzburg"]}},
		"rinforzi_regola": "adiacente",
		"mare": {"lato": 1, "naz": ["EN"], "max_sp": 2, "max_capi": 1, "da": "porto", "a": "porto_libero"},
		"solo_fm_turno1": true,
		"demoralizzazione_napoleone": true,
		"schieramento": [
			G("Paris+n", ["FR:Napoleon", "FR:Soult", "FR:Ney"], "FR 6I 3GI 1GC"),
			G("Lille", ["FR:@0"], "FR 4I"), G("Metz", ["FR:@0"], "FR 3I"),
			G("Lyon", ["FR:@0"], "FR 4I 1C"), G("Strasbourg", ["FR:@0"], "FR 4I 1C"),
			G("Amiens", ["FR:Jerome:W"], "FR 5I"), G("Rheims", [], "FR 4C"), G("Tours", [], "FR 2I"),
			G("Geneva", [], "FR 2I; FR:Sz 1I"), G("Marseilles", [], "FR 1I"), G("Paris", ["FR:Davout"]),
			G("Florence", ["FR:Murat"], "FR:N 8I 1C"),
			G("Munich", ["AU:Schwarzenberg", "AU:Ferdinand"], "AU 10I 10L 4C"),
			G("Milan", ["AU:Bellegarde"], "AU 8I 2L 2C"),
			G("Zurich", ["AU:@0"], "AU 7L 1C"), G("Ulm", ["AU:@0"], "AU 7L 1C"),
			G("Florence>", ["AU:@0"], "AU 4I 1C"),
			G("Baden", [], "AU 1I"), G("Stuttgart", [], "AU 1I"), G("Wurzburg", [], "AU 1I"),
			G("Brussels", ["EN:Wellington", "EN:Uxbridge", "PR:Brunswick"], "EN 5I 2L 2C; EN:K 1I; EN:H 5I 1C; PR:Br 1I"),
			G("Antwerp", [], "EN 2I 1L"),
			G("Namur", ["PR:Blucher", "PR:@0", "PR:@0"], "PR 9I 6L 2C"),
			G("Liege", ["PR:Bulow"], "PR 3I 2L 1C"),
			G("Coblenz", ["PR:Kleist"], "PR 3I 2L 1C"),
			G("Mainz", ["PR:Hohenlohe"], "PR:He 3I"),
		],
		"ogni_turno": [
			G("Paris", [], "FR 4I"), G("Lyon", [], "FR 1I"),
			G("Munich", [], "AU 1I 1L"), G("London", [], "EN 2I"), G("Munster", [], "PR 1I 1L"),
			G("Brussels", [], "FR:H 1I", {"lato": 0, "se": {"t": "e", "tests": [{"t": "controlla", "lato": 0, "citta": ["Brussels"]}, {"t": "non", "test": {"t": "flag", "k": "olanda_finita"}}]}}),
		],
		"rinforzi_data": {
			"1815-08": [G("Munster", ["PR:@0"], "PR 2I 2L 1C"),
				G("Frankfurt", ["RU:Barclay", "RU:@0"], "RU 10I 2C 2CC"),
				G("Wurzburg", ["RU:Constantine", "RU:@0"], "RU 6I 4GI 1C 1GC 2CC")],
		},
		"eventi": [
			{"id": "olanda_fr", "lato": 0, "se": {"t": "controlla", "lato": 0, "citta": ["Brussels"]},
				"effetti": [{"e": "elimina", "coppie": [["EN", "H"]], "t": "Gli Olandesi lasciano Wellington"}, {"e": "flag", "k": "olanda_fr"}]},
			{"id": "olanda_fine", "lato": 1, "se": {"t": "e", "tests": [{"t": "flag", "k": "olanda_fr"}, {"t": "controlla", "lato": 1, "citta": ["Brussels"]}]},
				"effetti": [{"e": "elimina", "coppie": [["FR", "H"]], "t": "Gli Olandesi abbandonano Napoleone"}, {"e": "flag", "k": "olanda_finita"}]},
			{"id": "partigiani", "lato": 0, "se": {"t": "entra_stato", "lato": 1, "stati": ["FR"]},
				"effetti": [{"e": "partigiani", "naz": "FR", "stato": "FR", "n": 2, "t": "La Francia invasa: si formano bande di partigiani"}, {"e": "flag", "k": "partigiani"}]},
		],
		"ogni_turno_partigiani": {"naz": "FR", "stato": "FR"},
		"punti_citta": [{}, {}],
		"vittoria_cond": [{"vince": 1, "test": {"t": "occupa", "lato": 1, "citta": ["Paris"], "libere": true, "rif": true},
			"perche": "Gli Alleati entrano a Parigi: seconda abdicazione."}],
		"vince_default": 0,
		"perche_default": "Parigi resiste fino a dicembre 1815: un'impresa quasi impossibile.",
		"obiettivi": [{"Brussels": 8, "Namur": 4, "Liege": 4, "Antwerp": 4, "Coblenz": 3, "Mainz": 3},
			{"Paris": 16, "Lille": 2, "Metz": 2, "Rheims": 2, "Lyon": 2, "Strasbourg": 2}],
		"ia": {"difendi": [{"Paris": 16, "Lyon": 3}, {"Brussels": 6, "Antwerp": 3}]},
		"vittoria": "La Coalizione vince subito, alla fine di qualunque turno, se ha un punto forza rifornito e non assediato a Parigi; altrimenti vince la Francia a dicembre (è difficilissimo: conviene giocarlo due volte scambiandosi i lati e vedere chi tiene Parigi più a lungo). A giugno i Francesi muovono solo con la marcia forzata. Se una forza con Napoleone è demoralizzata, i Francesi regolari passano a morale 1 per sempre. Bruxelles francese porta via gli Olandesi a Wellington e dà 1 PF olandese a Napoleone ogni turno.",
		"margine": 0,
	}

# =============================================================================================
# XI. La guerra di Spagna 1808-1814 e XII. Spagna 1811-1814

static func _penisola(dal_1811: bool) -> Dictionary:
	var d := {
		"id": "1811" if dal_1811 else "1808",
		"titolo": "Spagna 1811-14" if dal_1811 else "Guerra di Spagna 1808-14",
		"sottotitolo": "Spain: 1811-1814" if dal_1811 else "The Peninsular War",
		"descrizione": ("Giugno 1811: i Francesi hanno quasi vinto, ma Wellington è imprendibile dietro Lisbona, i guerriglieri tagliano le strade e Napoleone porta via truppe per la Russia." if dal_1811 else "Maggio 1808: Giuseppe Bonaparte è re di Spagna e la Spagna insorge. Le guarnigioni francesi sono sparse da Lisbona a Barcellona; arriveranno Napoleone, poi Wellington e i suoi Portoghesi, e sei anni di guerriglia."),
		"durata": ("Trentacinque turni mensili, da giugno 1811 ad aprile 1814." if dal_1811 else "Settantadue turni mensili, da maggio 1808 ad aprile 1814."),
		"mese": 5 if dal_1811 else 4, "anno": 1811 if dal_1811 else 1808, "turni": 35 if dal_1811 else 72,
		"aree": [1, 2],
		"lati": {"FR": 0, "SP": 1, "Pt": 1, "EN": 1},
		"in_guerra": ["FR", "SP", "Pt", "EN"],
		"fonti": {"0": {"citta": ["Bayonne", "Toulouse"]}},
		"fonti_naz": {"SP": {"stati": ["SP"], "tutte": true}, "EN": {"stati": ["Pt"], "tutte": true, "citta": ["Gibraltar"], "costa_propria": true}},
		"gibilterra": true,
		"madrid_milizia": true,
		"mare": {"lato": 1, "naz": ["EN"], "max_sp": 2, "max_capi": -1, "da": "costa", "a": "costa_libera"},
		"rinforzi_regola": "vicina",
		"punti_citta": [{}, {}],
		"vittoria_cond": [
			{"vince": 0, "test": {"t": "occupa", "lato": 0, "area": 1, "eccetto": ["Gibraltar"]}, "perche": "Un presidio francese in ogni città della penisola: la Spagna è sottomessa."},
			{"vince": 1, "test": {"t": "e", "tests": [{"t": "non", "test": {"t": "occupa", "lato": 0, "area": 1, "min": 1}}, {"t": "occupa", "lato": 1, "citta": ["Bayonne", "Toulouse"], "libere": true}, {"t": "controlla", "lato": 1, "citta": ["Gibraltar"]}]},
				"perche": "I Francesi sono cacciati dalla penisola e Wellington tiene Bayonne e Tolosa."},
			{"vince": 0, "quando": "fine", "test": {"t": "e", "tests": [{"t": "occupa", "lato": 0, "citta": ["Bayonne", "Toulouse"], "libere": true}, {"t": "occupa", "lato": 0, "area": 1, "min": 1, "libere": true}]},
				"perche": "Ad aprile 1814 i Francesi tengono Bayonne, Tolosa e una città della penisola."},
		],
		"vince_default": -1,
		"perche_default": "Nessuno ha raggiunto le sue condizioni: pareggio.",
		"obiettivi": [{"Madrid": 6, "Lisbon": 8, "Seville": 4, "Cadiz": 5, "Corunna": 4, "Valencia": 4, "Saragossa": 4, "Oporto": 4, "Granada": 3, "Cartagena": 3, "Badajoz": 3, "Ciudad Rodrigo": 3, "Burgos": 3, "Barcelona": 3, "Toledo": 2},
			{"Madrid": 6, "Burgos": 3, "Bayonne": 5, "Toulouse": 5, "Lisbon": 5, "Badajoz": 3, "Ciudad Rodrigo": 3, "San Sebastian": 3, "Pamplona": 2}],
		"ia": {"difendi": [{"Bayonne": 4, "Madrid": 4}, {"Lisbon": 6, "Cadiz": 5, "Gibraltar": 4}]},
		"vittoria": "Il Francese vince subito se ha almeno un punto forza in ogni città della penisola (Gibilterra esclusa); la Coalizione vince subito se non resta un Francese nelle città della penisola, tiene Gibilterra e ha truppe non assediate a Bayonne e Tolosa. A fine aprile 1814 vince il Francese se tiene Bayonne, Tolosa e una città della penisola; altrimenti pareggio. Rimpiazzi a punti (Francia e Inghilterra dal calendario, Spagna e Portogallo dalle loro città libere), comprati automaticamente dalla riserva: milizia e partigiani prima di fanteria e cavalleria. Gli Inglesi spostano 2 PF via mare da costa a costa; Gibilterra non si può attaccare finché c'è fanteria inglese.",
		"margine": 0,
	}
	if not dal_1811:
		d["schieramento"] = [
			G("Madrid", ["FR:Murat"], "FR 5I 1C; FR:Po 1I"), G("Burgos", ["FR:Bessieres"], "FR 3I; FR:Sz 1I"),
			G("Cordoba", ["FR:@0"], "FR 2I; FR:Sz 1I"), G("Lisbon", ["FR:@0"], "FR 4I 1C"), G("Toledo", [], "FR 3I"),
			G("Valencia>", [], "FR 2I"), G("Barcelona", [], "FR 1I; FR:I 1I"), G("Pamplona", [], "FR 1I"),
			G("Corunna", ["SP:Blake"], "SP 5I 1C"), G("Saragossa", ["SP:Pallafox"], "SP 5I 1C"), G("Seville", ["SP:Castanos"], "SP 5I 1C"),
			G("Ciudad Rodrigo", ["SP:Cuesta"], "SP 2I"), G("Valencia", [], "SP 3I"), G("Granada", [], "SP 2I"),
			G("Gibraltar", [], "EN 1I"),
		]
		d["pool"] = {"SP||M": 10, "SP||P": 6, "EN|Pt|I": 8, "EN|Pt|C": 1, "EN||M": 6, "EN||P": 3}
		d["rp"] = {
			"FR": {"lato": 0, "dove": ["Bayonne", "Toulouse", "Bordeaux", "Paris"], "tabella": [["1808-06", "1808-12", 1], ["1809-01", "1809-06", 1], ["1809-07", "1812-06", 2], ["1812-07", "1812-12", 1], ["1813-01", "1813-12", [0, 0, 0, 1, 1, 1]], ["1814-01", "1814-04", [0, 0, 0, 1, 1, 1], -1]]},
			"EN": {"lato": 1, "tabella": [["1808-08", "1810-12", 1], ["1811-01", "1811-12", [1, 1, 1, 2, 2, 2]], ["1812-01", "1812-12", 1], ["1813-01", "1814-04", [0, 0, 0, 1, 1, 1]]]},
			"SP": {"lato": 1, "citta": "SP", "inizio": 20},
			"Pt": {"lato": 1, "citta": "Pt", "inizio": 4},
		}
		var fr := func(g: Dictionary) -> Dictionary:
			g["alt"] = ["Toulouse"]
			return g
		var en_mare := func(t: String, capi: Array) -> Dictionary:
			return {"mare": "ATL", "capi": capi, "unita": U(t), "dove": "porto_libero", "lato": 1}
		d["rinforzi_data"] = {
			"1808-06": [fr.call(G("Bayonne", ["FR:Victor", "FR:@0"], "FR 10I"))],
			"1808-07": [fr.call(G("Bayonne", ["FR:Joseph"])), {"ritira": {"capi": ["Murat"]}, "lato": 0}],
			"1808-08": [en_mare.call("EN 2I", ["EN:Wellington"])],
			"1808-09": [en_mare.call("EN 3I; EN:K 1I", ["EN:Moore", "EN:@0"]), {"mare": "ATL", "capi": ["SP:La Romana"], "unita": U("SP 2I"), "dove": "costa_libera", "lato": 1}],
			"1808-10": [fr.call(G("Bayonne", ["FR:Napoleon", "FR:Lannes", "FR:Ney"], "FR 14I 2GI 2C 1GC; FR:I 2I 1C; FR:Po 1I; FR:Pt 1I; FR:R 1I; FR:Sz 1I"))],
			"1808-11": [fr.call(G("Bayonne", ["FR:Soult"], "FR 4I 2C")), en_mare.call("EN 2I", [])],
			"1809-01": [fr.call(G("Bayonne", [], "FR 1I; FR:Po 1I; FR:Sp 1I")), {"ritira": {"capi": ["Napoleon"]}, "lato": 0}],
			"1809-02": [{"ritira": {"unita": [["FR", "", "GI", 1], ["FR", "", "GC", 1]]}, "lato": 0}],
			"1809-03": [fr.call(G("Bayonne", ["FR:@0"])), {"ritira": {"capi": ["Bessieres", "Lannes"], "unita": [["FR", "Pt", "I", 1]]}, "lato": 0}],
			"1809-04": [en_mare.call("EN 1I", ["EN:Beresford", "EN:Uxbridge"])],
			"1810-01": [fr.call(G("Bayonne", ["FR:Bessieres", "FR:Marmont", "FR:Massena"], "FR 3I"))],
			"1810-02": [fr.call(G("Bayonne", [], "FR 3I")), en_mare.call("EN 1I", [])],
			"1810-03": [fr.call(G("Bayonne", [], "FR 6I")), en_mare.call("EN 1I", [])],
			"1810-04": [fr.call(G("Bayonne", [], "FR 4I"))],
			"1810-05": [fr.call(G("Bayonne", [], "FR 6I"))],
			"1810-06": [fr.call(G("Bayonne", [], "FR 4I"))],
			"1811-01": [fr.call(G("Bayonne", [], "FR 1I; FR:N 1I"))],
			"1811-04": [fr.call(G("Bayonne", [], "FR 4I"))],
		}
	else:
		d["mese"] = 5
		d["schieramento"] = [
			G("Ciudad Rodrigo", ["FR:Marmont", "FR:Ney"], "FR 8I 1C"), G("Burgos", ["FR:Bessieres"], "FR 5I 1C"),
			G("Badajoz", ["FR:Soult"], "FR 4I 1C"), G("Madrid", ["FR:Joseph", "FR:@0", "FR:@0", "FR:@0"], "FR 6I 1C; FR:Sp 1I"),
			G("Seville", ["FR:Victor"], "FR 2I; FR:Po 1I"), G("San Sebastian", ["FR:@0"], "FR 4I"),
			G("Barcelona", ["FR:@0:I"], "FR 2I; FR:I 1I 1C"), G("Baylen", [], "FR 2I"), G("Cordoba", [], "FR 2I"),
			G("Granada", [], "FR 2I; FR:R 1I"), G("Toledo", [], "FR 2I"),
			G("Pamplona", [], "FR 1I; FR:N 1I"), G("Saragossa", [], "FR 1I; FR:I 1I"), G("Talavera", [], "FR 1I; FR:R 1I"),
			G("Badajoz+o", ["SP:Blake", "SP:Castanos", "EN:Beresford"], "SP 2I; EN 2I; EN:Pt 2I"),
			G("Corunna", ["SP:Pallafox", "SP:Cuesta"], "SP 2I 1M"), G("Valencia", [], "SP 2I 1M"),
			G("Cadiz", ["EN:@0"], "SP 1I 1M; EN 1I"), G("Cartagena", [], "SP 1I 1M"),
			G("Ciudad Rodrigo+o", ["EN:Wellington"], "EN 4I; EN:K 1I; EN:Pt 2I 1C"),
			G("Lisbon", ["EN:Hill"], "EN 1I; EN 2M"), G("Gibraltar", [], "EN 1I"), G("Oporto", [], "EN 2M"), G("Vimeiro", [], "EN 1M"), G("Lagos", [], "EN 1M"),
		]
		d["pool"] = {"FR||I": 12, "FR||GI": 1, "FR|Po|I": 1, "FR|Sz|I": 1, "FR|I|I": 1, "FR|I|C": 1, "SP||I": 14, "SP||C": 3, "SP||M": 6, "EN||I": 2, "EN|Pt|I": 4}
		d["eventi"] = [{"id": "guerriglia", "effetti": [{"e": "partigiani", "naz": "SP", "stato": "SP", "n": 6}, {"e": "partigiani", "naz": "EN", "stato": "Pt", "n": 3}]}]
		d["rp"] = {
			"FR": {"lato": 0, "dove": ["Bayonne", "Toulouse", "Bordeaux"], "tabella": [["1811-06", "1812-06", 2], ["1812-07", "1812-12", 1], ["1813-01", "1813-12", [0, 0, 0, 1, 1, 1]], ["1814-01", "1814-04", [0, 0, 0, 1, 1, 1], -1]]},
			"EN": {"lato": 1, "tabella": [["1811-06", "1811-12", [1, 1, 1, 2, 2, 2]], ["1812-01", "1812-12", 1], ["1813-01", "1814-04", [0, 0, 0, 1, 1, 1]]]},
			"SP": {"lato": 1, "citta": "SP", "inizio": 7},
			"Pt": {"lato": 1, "citta": "Pt", "inizio": 6},
		}
		d["rinforzi_data"] = {"1811-07": [G("Bayonne", [], "FR 4I", {"alt": ["Toulouse"]})]}
	var rd: Dictionary = d["rinforzi_data"]
	var agg := {
		"1812-04": [{"ritira": {"capi": ["Bessieres", "Ney", "Victor"], "unita": [["FR", "", "I", 3], ["FR", "sat", "*", 2]]}, "lato": 0},
			{"mare": "ATL", "capi": [], "unita": U("EN 1I 1C; EN:K 1I"), "dove": "porto_libero", "lato": 1}],
		"1812-08": [G("Bayonne", [], "FR 3I", {"alt": ["Toulouse"]})],
		"1813-02": [{"ritira": {"capi": ["Soult"], "unita": [["FR", "", "I", 3], ["FR", "", "C", 1]]}, "lato": 0}],
		"1813-07": [G("Bayonne", ["FR:Soult"], "FR 2I", {"alt": ["Toulouse"]})],
		"1813-12": [{"ritira": {"unita": [["FR", "", "I", 3], ["FR", "R", "*", 99], ["FR", "Sz", "*", 99]]}, "lato": 0}],
		"1814-01": [{"ritira": {"unita": [["FR", "", "I", 4], ["FR", "sat", "C", 1]]}, "lato": 0}],
	}
	for k in agg:
		if not rd.has(k):
			rd[k] = []
		rd[k].append_array(agg[k])
	return d
