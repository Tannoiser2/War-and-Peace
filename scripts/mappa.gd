## La mappa esagonale (Europa), estratta dal tabellone originale: terreno, fiumi, città,
## stati e aree della mappa. Caricata una volta sola e condivisa.
class_name Mappa
extends RefCounted

static var dati := {}
static var esagoni := {}
static var per_nome := {}
static var larg := 4096.0
static var alt := 3226.0
static var W := 64.2

static func carica() -> void:
	if not esagoni.is_empty():
		return
	var f := FileAccess.open("res://assets/mappa/mappa.json", FileAccess.READ)
	dati = JSON.parse_string(f.get_as_text())
	esagoni = dati["esagoni"]
	larg = float(dati["larg"])
	alt = float(dati["alt"])
	W = float(dati["W"])
	for k in esagoni:
		var e: Dictionary = esagoni[k]
		if e.has("c"):
			per_nome[e["c"]["n"]] = k

static func esiste(h: String) -> bool:
	return esagoni.has(h)

static func es(h: String) -> Dictionary:
	return esagoni.get(h, {})

static func pos(h: String) -> Vector2:
	var e: Dictionary = esagoni[h]
	return Vector2(e["x"], e["y"])

static func terreno(h: String) -> String:
	return esagoni[h]["t"]

static func stato(h: String) -> String:
	return esagoni[h]["st"]

static func area(h: String) -> int:
	return int(esagoni[h]["a"])

static func citta(h: String) -> Dictionary:
	return esagoni[h].get("c", {})

static func ha_citta(h: String) -> bool:
	return esagoni[h].has("c")

static func nome_citta(h: String) -> String:
	return esagoni[h].get("c", {}).get("n", "")

static func tipo_citta(h: String) -> String:
	return esagoni[h].get("c", {}).get("tipo", "")

## Capitale o città maggiore
static func citta_maggiore(h: String) -> bool:
	var t := tipo_citta(h)
	return t == "maggiore" or t == "capitale"

static func hex(nome: String) -> String:
	return per_nome.get(nome, "")

## Vicini: array di [esagono, segni] dove "f" = fiume sul lato, "c" = confine
static func vicini(h: String) -> Array:
	return esagoni[h]["v"]

static func adiacenti(a: String, b: String) -> bool:
	for v in esagoni[a]["v"]:
		if v[0] == b:
			return true
	return false

static func fiume_tra(a: String, b: String) -> bool:
	for v in esagoni[a]["v"]:
		if v[0] == b:
			return str(v[1]).contains("f")
	return false

## Costo per entrare in b provenendo da a
static func costo(a: String, b: String) -> int:
	var c: int = Dati.COSTO_TERRENO.get(terreno(b), 1)
	if fiume_tra(a, b):
		c += Dati.COSTO_FIUME
	return c

## Nome leggibile di un esagono: la città se c'è, altrimenti il terreno e la regione
static func nome(h: String) -> String:
	if not esiste(h):
		return "?"
	var n := nome_citta(h)
	if n != "":
		return n
	var st := stato(h)
	var reg: String = Dati.NAZ[st]["nome"] if Dati.NAZ.has(st) else Dati.MINORI.get(st, "")
	return "%s (%s)" % [Dati.NOMI_TERRENO.get(terreno(h), terreno(h)), reg]

## Esagono che contiene un punto della mappa (coordinate in pixel della texture)
static func esagono_in(p: Vector2) -> String:
	# ricerca del centro più vicino fra gli esagoni vicini alla griglia
	var best := ""
	var bd := INF
	var raggio := W * 0.62
	for k in _vicini_spaziali(p):
		var d := pos(k).distance_to(p)
		if d < bd:
			bd = d
			best = k
	return best if bd <= raggio else ""

static var _celle := {}

static func _cella(p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / (W * 2.0)), int(p.y / (W * 2.0)))

static func _vicini_spaziali(p: Vector2) -> Array:
	if _celle.is_empty():
		for k in esagoni:
			var c := _cella(pos(k))
			if not _celle.has(c):
				_celle[c] = []
			_celle[c].append(k)
	var c0 := _cella(p)
	var out := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			out.append_array(_celle.get(c0 + Vector2i(dx, dy), []))
	return out
