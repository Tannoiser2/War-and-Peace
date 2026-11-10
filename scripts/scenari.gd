## Scenari.
## - 1805: "The Sun of Austerlitz" dal libretto ufficiale degli scenari (6ª/7ª edizione).
## - 1813: "Struggle of Nations", dalla scheda ufficiale dello scenario (7ª edizione).
## Negli schieramenti: "Città" = nella città, "Città>" = in un esagono vicino, "Città+n" = a nord;
## i capi "NAZ:@0" sono capi generici di valore 0; un terzo campo dà lo stato minore del capo.
class_name Scenari
extends RefCounted

const ELENCO := ["1805", "1813"]

static func dati(id: String) -> Dictionary:
	match id:
		"1805":
			return _austerlitz()
		"1813":
			return _nazioni()
	return {}

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
