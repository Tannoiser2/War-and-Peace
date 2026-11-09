## Scenari. Il libretto degli scenari non è nel modulo TTS: questo scenario è RICOSTRUITO sulla
## storia della campagna del 1805 (schieramenti, rinforzi e vittoria) e va sostituito con quello
## ufficiale quando sarà disponibile. Il formato è pensato per aggiungere gli altri scenari.
class_name Scenari
extends RefCounted

const ELENCO := ["1805"]

static func dati(id: String) -> Dictionary:
	match id:
		"1805":
			return _austerlitz()
	return {}

static func _austerlitz() -> Dictionary:
	return {
		"id": "1805",
		"titolo": "Austerlitz 1805",
		"sottotitolo": "la Terza Coalizione",
		"descrizione": "Settembre 1805: la Grande Armée lascia le coste della Manica e passa il Reno. Mack è avanzato in Baviera fino a Ulm, l'arciduca Carlo difende il Veneto, i Russi di Kutusov marciano dalla Galizia. Napoleone deve chiudere la guerra prima dell'inverno; la Prussia osserva e potrebbe entrare in guerra.",
		"mese": 8, "anno": 1805, "turni": 5,
		# a che lato appartiene ogni nazione e stato minore (regioni della mappa e pedine)
		"lati": {"FR": 0, "B": 0, "Wu": 0, "Ba": 0, "I": 0, "Ha": 0, "Sz": 0, "R": 0, "H": 0,
			"AU": 1, "RU": 1, "PR": 1, "S": 1, "He": 1, "Br": 1},
		# nazioni in guerra all'inizio; le altre sono neutrali (i loro territori sono chiusi)
		"in_guerra": ["FR", "B", "Wu", "Ba", "I", "Ha", "Sz", "R", "H", "AU", "RU"],
		# i Russi si riforniscono anche dalle città maggiori austriache
		"fonti_extra": {"RU": ["AU"]},
		# controllo iniziale diverso da quello della regione
		"controllo": {"Ulm": 1},
		"schieramento": [
			{"hex": "Strasbourg", "capi": ["FR:Napoleon", "FR:Lannes", "FR:Murat"],
				"unita": [["FR", "", "GI", 3], ["FR", "", "GC", 1], ["FR", "", "I", 6], ["FR", "", "C", 4]]},
			{"hex": "Baden", "capi": ["FR:Soult", "FR:Ney"], "unita": [["FR", "", "I", 12], ["FR", "", "C", 1]]},
			{"hex": "Mainz", "capi": ["FR:Davout"], "unita": [["FR", "", "I", 6], ["FR", "", "C", 1]]},
			{"hex": "Wurzburg", "capi": ["FR:Marmont"], "unita": [["FR", "", "I", 4], ["FR", "B", "I", 4], ["FR", "B", "C", 1]]},
			{"hex": "Hanover", "capi": ["FR:Bernadotte"], "unita": [["FR", "", "I", 4], ["FR", "", "C", 1]]},
			{"hex": "Milan", "capi": ["FR:Massena"], "unita": [["FR", "", "I", 8], ["FR", "I", "I", 2], ["FR", "", "C", 1]]},
			{"hex": "Mantua", "capi": ["FR:Leader A"], "unita": [["FR", "", "I", 2]]},
			{"hex": "Ulm", "capi": ["AU:Mack", "AU:Ferdinand"], "unita": [["AU", "", "I", 12], ["AU", "", "C", 3]]},
			{"hex": "Innsbruck", "capi": ["AU:John"], "unita": [["AU", "", "I", 4], ["AU", "", "L", 1]]},
			{"hex": "Venice", "capi": ["AU:Charles", "AU:Bellegarde"], "unita": [["AU", "", "I", 14], ["AU", "", "C", 3]]},
			{"hex": "Vienna", "capi": ["AU:Leader C"], "unita": [["AU", "", "I", 2], ["AU", "", "L", 3]]},
			{"hex": "Prague", "capi": [], "unita": [["AU", "", "L", 2]]},
			{"hex": "Budapest", "capi": [], "unita": [["AU", "", "L", 2]]},
			{"hex": "Lemberg", "capi": ["RU:Kutusov", "RU:Bagration"], "unita": [["RU", "", "I", 8], ["RU", "", "CC", 2]]},
			{"hex": "Brest-Litovsk", "capi": ["RU:Buxhowden"], "unita": [["RU", "", "I", 6], ["RU", "", "C", 1]]},
		],
		# rinforzi per turno (1 = primo turno)
		"rinforzi": {
			"2": [{"hex": "Brest-Litovsk", "capi": ["RU:Constantine"], "unita": [["RU", "", "GI", 2], ["RU", "", "GC", 1]]},
				{"hex": "Vienna", "capi": [], "unita": [["AU", "", "L", 2]]}],
			"3": [{"hex": "Brest-Litovsk", "capi": ["RU:Bennigsen"], "unita": [["RU", "", "I", 6], ["RU", "", "CC", 1]]},
				{"hex": "Strasbourg", "capi": ["FR:Augereau"], "unita": [["FR", "", "I", 4]]},
				{"hex": "Vienna", "capi": [], "unita": [["AU", "", "L", 2]]}],
			"4": [{"hex": "Vienna", "capi": [], "unita": [["AU", "", "L", 2]]}],
		},
		# la Prussia entra in guerra con la Coalizione con un 7 modificato nella fase delle alleanze
		# della Coalizione; con uno 0 modificato dei Francesi resta neutrale per sempre
		"alleanza": {"nazione": "PR", "stati": ["PR", "S", "He", "Br"], "lato": 1,
			"schieramento": [
				{"hex": "Berlin", "capi": ["PR:Brunswick"], "unita": [["PR", "", "I", 8], ["PR", "", "C", 2]]},
				{"hex": "Magdeburg", "capi": ["PR:Ruchel"], "unita": [["PR", "", "I", 5], ["PR", "", "C", 1]]},
				{"hex": "Breslau", "capi": ["PR:Hohenlohe"], "unita": [["PR", "", "I", 6], ["PR", "", "C", 1]]},
				{"hex": "Dresden", "capi": ["PR:Leader A"], "unita": [["PR", "S", "I", 3], ["PR", "S", "C", 1]]},
			]},
		# punti vittoria per le città controllate a fine partita
		"obiettivi": [
			{"Vienna": 4, "Venice": 2, "Ulm": 1, "Munich": 1, "Prague": 1, "Innsbruck": 1},
			{"Milan": 2, "Strasbourg": 2, "Munich": 1, "Ulm": 1, "Mainz": 1},
		],
		"vittoria": "Alla fine di gennaio 1806 si sommano i punti delle battaglie vinte e delle città obiettivo controllate. I Francesi vincono se hanno almeno 3 punti più della Coalizione; la Coalizione vince se ne ha di più dei Francesi; altrimenti è un pareggio (una pace di compromesso). Vittoria immediata della Coalizione se Napoleone muore; vittoria immediata francese se i Francesi controllano Vienna e Venezia e all'Austria restano meno di 8 punti forza.",
		"margine": 3,
	}
