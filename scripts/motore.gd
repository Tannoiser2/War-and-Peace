## Il motore delle regole di War and Peace (regole base 6a/7a edizione).
## Tutto lo stato sta nel dizionario `s` (salvabile in JSON); i dadi sono deterministici a partire
## dal seme, così le partite online si riproducono uguali su tutti i dispositivi applicando le stesse
## decisioni nello stesso ordine.
class_name Motore
extends RefCounted

var s := {}
var scen := {}
## eventi dell'ultima azione, per l'interfaccia (dadi, battaglie, movimenti)
var eventi: Array = []

static var catalogo := {}

static func carica_catalogo() -> void:
	if not catalogo.is_empty():
		return
	var f := FileAccess.open("res://assets/pedine/catalogo.json", FileAccess.READ)
	catalogo = JSON.parse_string(f.get_as_text())

# =============================================================================================
# Nuova partita

func nuova(cfg: Dictionary) -> void:
	Mappa.carica()
	carica_catalogo()
	scen = Scenari.dati(cfg.get("scen", "1805"))
	s = {
		"scen": scen["id"], "turno": 1, "mese": int(scen["mese"]), "anno": int(scen["anno"]),
		"lato": 0, "fase": "", "seme": int(cfg.get("seed", 1)), "rs": int(cfg.get("seed", 1)) % 2147483647 + 1,
		"unita": {}, "capi": {}, "prossimo": 1,
		"controllo": {}, "assedi": {}, "trincee": {}, "pv": [0, 0],
		"in_guerra": scen["in_guerra"].duplicate(), "aperti": [], "alleanza": "", "batt": [], "cb": {},
		"log": [], "esito": {}, "sp_inizio": {}, "rifornimento": {}, "opzioni": cfg.get("opzioni", {}),
		"azioni": 0, "coinvolti_capi": {},
	}
	_aggiorna_aperti()
	# controllo iniziale delle città: quello della regione (se in guerra), poi le eccezioni
	for h in Mappa.esagoni:
		if Mappa.ha_citta(h):
			var st := Mappa.stato(h)
			if scen["lati"].has(st) and st in s["in_guerra"]:
				s["controllo"][h] = int(scen["lati"][st])
	for nome in scen.get("controllo", {}):
		s["controllo"][Mappa.hex(nome)] = int(scen["controllo"][nome])
	for gruppo in scen["schieramento"]:
		_schiera(gruppo)
	for h in s["controllo"].keys():
		_aggiorna_controllo(h)
	_log("[b]%s[/b] — %s %d" % [scen["titolo"], Dati.MESI[s["mese"]], s["anno"]])
	_inizia_segmento()

func _schiera(gruppo: Dictionary) -> void:
	var h := Mappa.hex(gruppo["hex"])
	if h == "":
		push_error("città sconosciuta " + str(gruppo["hex"]))
		return
	for c in gruppo["capi"]:
		var p: PackedStringArray = str(c).split(":")
		_nuovo_capo(p[0], p[1], h)
	for u in gruppo["unita"]:
		_nuova_unita(u[0], u[1], u[2], int(u[3]), h)

func _nuovo_capo(naz: String, nome: String, h: String) -> String:
	for c in catalogo["capi"]:
		if c["naz"] == naz and c["nome"] == nome and not _capo_usato(c["img"]):
			var id := "c%d" % s["prossimo"]
			s["prossimo"] += 1
			s["capi"][id] = {"nome": nome, "n": naz, "s": c["sub"] if c["sub"] != "I?" else "", "v": int(c["val"]),
				"h": h, "mp": 0, "fuori": 0, "morto": false, "img": c["img"]}
			return id
	push_error("capo non trovato %s %s" % [naz, nome])
	return ""

func _capo_usato(img: String) -> bool:
	for id in s["capi"]:
		if s["capi"][id]["img"] == img:
			return true
	return false

func _nuova_unita(naz: String, sub: String, tipo: String, sp: int, h: String, dentro := false) -> String:
	# si fonde con un'unità uguale nello stesso esagono
	for id in s["unita"]:
		var u: Dictionary = s["unita"][id]
		if u["h"] == h and u["n"] == naz and u["s"] == sub and u["t"] == tipo and u["in"] == dentro and u["mo"] == false:
			u["sp"] += sp
			return id
	var id := "u%d" % s["prossimo"]
	s["prossimo"] += 1
	s["unita"][id] = {"n": naz, "s": sub, "t": tipo, "sp": sp, "h": h, "mo": false, "in": dentro}
	return id

## Riunisce le unità uguali nello stesso esagono (dopo i movimenti)
func _compatta() -> void:
	var chiavi := {}
	for id in s["unita"].keys():
		var u: Dictionary = s["unita"][id]
		if u["sp"] <= 0:
			s["unita"].erase(id)
			continue
		var k := "%s|%s|%s|%s|%s" % [u["h"], u["n"], u["s"], u["t"], u["in"]]
		if chiavi.has(k):
			s["unita"][chiavi[k]]["sp"] += u["sp"]
			s["unita"].erase(id)
		else:
			chiavi[k] = id

# =============================================================================================
# Utilità

func dado() -> int:
	s["rs"] = (int(s["rs"]) * 1103515245 + 12345) % 2147483648
	return int(s["rs"] / 65536) % 6 + 1

func _log(t: String) -> void:
	s["log"].append(t)
	if s["log"].size() > 400:
		s["log"] = s["log"].slice(-300)
	eventi.append({"k": "log", "t": t})

func lato_di(naz: String) -> int:
	return int(scen["lati"].get(naz, -1))

func lato_unita(u: Dictionary) -> int:
	return lato_di(u["n"])

func nome_lato(l: int) -> String:
	return Dati.LATI[l]

func inverno() -> bool:
	return int(s["mese"]) in Dati.INVERNO

func finita() -> bool:
	return s["fase"] == "finita"

func _aggiorna_aperti() -> void:
	s["aperti"] = s["in_guerra"].duplicate()

## Un esagono è percorribile da un lato se il suo stato è in guerra (i neutrali sono chiusi)
func aperto(h: String) -> bool:
	return Mappa.stato(h) in s["aperti"]

func unita_in(h: String, lato := -1, solo_fuori := false) -> Array:
	var out := []
	for id in s["unita"]:
		var u: Dictionary = s["unita"][id]
		if u["h"] == h and (lato < 0 or lato_unita(u) == lato) and not (solo_fuori and u["in"]):
			out.append(id)
	return out

func capi_in(h: String, lato := -1) -> Array:
	var out := []
	for id in s["capi"]:
		var c: Dictionary = s["capi"][id]
		if c["h"] == h and (lato < 0 or lato_di(c["n"]) == lato):
			out.append(id)
	return out

func sp_in(h: String, lato: int, solo_fuori := false, solo_dentro := false) -> int:
	var t := 0
	for id in s["unita"]:
		var u: Dictionary = s["unita"][id]
		if u["h"] == h and lato_unita(u) == lato:
			if solo_fuori and u["in"]:
				continue
			if solo_dentro and not u["in"]:
				continue
			t += int(u["sp"])
	return t

func sp_lato(lato: int) -> int:
	var t := 0
	for id in s["unita"]:
		if lato_unita(s["unita"][id]) == lato:
			t += int(s["unita"][id]["sp"])
	return t

func sp_naz(naz: String) -> int:
	var t := 0
	for id in s["unita"]:
		if s["unita"][id]["n"] == naz:
			t += int(s["unita"][id]["sp"])
	return t

## Esagoni occupati (con punti forza) da un lato
func esagoni_di(lato: int) -> Array:
	var d := {}
	for id in s["unita"]:
		var u: Dictionary = s["unita"][id]
		if lato_unita(u) == lato:
			d[u["h"]] = true
	return d.keys()

func nemico_in(h: String, lato: int) -> bool:
	return sp_in(h, 1 - lato) > 0

## Il nemico è presente fuori dalla città (le unità chiuse dentro non bloccano il passaggio)
func nemico_fuori(h: String, lato: int) -> bool:
	return sp_in(h, 1 - lato, true) > 0

func max_porta(capo_id: String) -> int:
	var n: String = s["capi"][capo_id]["nome"]
	return 12 if n == "Napoleon" or n == "Wellington" else 10

func mp_capo(capo_id: String) -> int:
	var n: String = s["capi"][capo_id]["nome"]
	return 12 if n == "Napoleon" or n == "Wellington" else 10

func controllore(h: String) -> int:
	return int(s["controllo"].get(h, -1))

func _aggiorna_controllo(h: String) -> void:
	if not Mappa.ha_citta(h):
		return
	var a := sp_in(h, 0)
	var b := sp_in(h, 1)
	if a > 0 and b == 0:
		s["controllo"][h] = 0
	elif b > 0 and a == 0:
		s["controllo"][h] = 1

# =============================================================================================
# Rifornimento (regola M)

## Calcola per il lato gli esagoni in cui le unità di ciascun colore sono rifornite.
## Risultato: {naz: {esagono: true}}
func calcola_rifornimento(lato: int) -> Dictionary:
	var out := {}
	var nazioni := {}
	for id in s["unita"]:
		var u: Dictionary = s["unita"][id]
		if lato_unita(u) == lato:
			nazioni[u["n"]] = true
	for naz in nazioni:
		out[naz] = _rifornimento_naz(naz, lato)
	s["rifornimento"][str(lato)] = out
	return out

func _fonte_citta(h: String, naz: String, lato: int) -> bool:
	if not Mappa.citta_maggiore(h):
		return false
	if controllore(h) != lato:
		return false
	var st := Mappa.stato(h)
	var case_ := [naz]
	case_.append_array(scen.get("fonti_extra", {}).get(naz, []))
	var ok := st in case_
	if not ok and lato_di(st) == lato and naz == "FR" and not Dati.NAZ.has(st):
		ok = true  # satellite della Francia
	if not ok and naz != "FR" and lato_di(st) == lato and not Dati.NAZ.has(st) and st in ["S", "He", "Br"] and naz == "PR":
		ok = true
	if not ok:
		return false
	return sp_in(h, 1 - lato, true) == 0

func _rifornimento_naz(naz: String, lato: int) -> Dictionary:
	var raggiunti := {}
	var fonti := []
	for h in Mappa.esagoni:
		if Mappa.ha_citta(h) and _fonte_citta(h, naz, lato):
			fonti.append(h)
	# unità della stessa nazione già rifornite diventano a loro volta fonti (catena di depositi)
	var sedi := {}
	for id in s["unita"]:
		var u: Dictionary = s["unita"][id]
		if u["n"] == naz:
			sedi[u["h"]] = true
	var usate := {}
	var coda := fonti.duplicate()
	while not coda.is_empty():
		var f: String = coda.pop_back()
		if usate.has(f):
			continue
		usate[f] = true
		var r := _entro(f, 3, lato)
		for h in r:
			if not raggiunti.has(h):
				raggiunti[h] = true
				if sedi.has(h) and not usate.has(h):
					coda.append(h)
	# unità chiuse in una città che è fonte per loro
	for h in sedi:
		if Mappa.ha_citta(h) and Mappa.citta_maggiore(h) and controllore(h) == lato:
			var st := Mappa.stato(h)
			if st == naz or st in scen.get("fonti_extra", {}).get(naz, []):
				raggiunti[h] = true
	return raggiunti

## Esagoni raggiungibili entro mp punti movimento senza attraversare esagoni nemici
## (si può entrare in un esagono nemico ma non proseguire, salvo se i nemici sono chiusi in città)
func _entro(da: String, mp: int, lato: int) -> Dictionary:
	var dist := {da: 0}
	var coda := [da]
	var out := {da: true}
	while not coda.is_empty():
		# coda a priorità semplice (pochi esagoni)
		var best := 0
		for i in coda.size():
			if dist[coda[i]] < dist[coda[best]]:
				best = i
		var h: String = coda[best]
		coda.remove_at(best)
		if h != da and nemico_fuori(h, lato):
			continue
		for v in Mappa.vicini(h):
			var n: String = v[0]
			if not aperto(n):
				continue
			var d: int = dist[h] + Mappa.costo(h, n)
			if d <= mp and d < dist.get(n, 999):
				dist[n] = d
				out[n] = true
				coda.append(n)
	return out

func rifornita(u: Dictionary, lato: int) -> bool:
	var r: Dictionary = s["rifornimento"].get(str(lato), {})
	return r.get(u["n"], {}).has(u["h"])

# =============================================================================================
# Sequenza di gioco

func _inizia_segmento() -> void:
	var l: int = s["lato"]
	_log("[color=#7a2a10]— %s: %s %d —[/color]" % [nome_lato(l), Dati.MESI[s["mese"]], s["anno"]])
	for id in s["unita"]:
		s["unita"][id]["mo"] = false
	for id in s["capi"]:
		s["capi"][id]["mp"] = 0
	calcola_rifornimento(l)
	if s["turno"] > 1:
		_fase_logoramento()
		_fase_alleanze()
	_fase_rinforzi()
	if _controlla_vittoria_immediata():
		return
	s["fase"] = "movimento"

func _fase_logoramento() -> void:
	var l: int = s["lato"]
	var tiro := dado()
	eventi.append({"k": "dado", "titolo": "Logoramento", "dadi": [tiro]})
	var perdite_tot := 0
	var righe := []
	for h in esagoni_di(l):
		var ids := unita_in(h, l)
		var pf := 0
		var tutti_fr := true
		var tutti_casa := true
		var senza := false
		var dentro_assedio := 0
		for id in ids:
			var u: Dictionary = s["unita"][id]
			pf += int(u["sp"])
			if u["n"] != "FR":
				tutti_fr = false
			if not _a_casa(u, h):
				tutti_casa = false
			if not rifornita(u, l):
				senza = true
			if u["in"] and s["assedi"].has(h):
				dentro_assedio = int(s["assedi"][h]["l"])
		if pf < 3:
			continue
		var t := tiro
		if tutti_fr: t -= 1
		if tutti_casa: t -= 1
		if senza: t += 1
		if inverno(): t += 1
		if Mappa.area(h) in [1, 4]: t += 1
		t += dentro_assedio
		var p := Dati.logoramento(t, pf)
		var ast := p < 0
		p = absi(p)
		if p > 0:
			_elimina_sp(ids, p, ast, "")
			perdite_tot += p
			righe.append("%s %d" % [Mappa.nome(h), p])
	if perdite_tot > 0:
		_log("Logoramento (dado %d): perdite %s" % [tiro, ", ".join(righe)])
	else:
		_log("Logoramento (dado %d): nessuna perdita" % tiro)
	_compatta()

func _a_casa(u: Dictionary, h: String) -> bool:
	var st := Mappa.stato(h)
	if u["s"] != "" and u["s"] != "K":
		return st == u["s"]
	return st == u["n"]

func _fase_alleanze() -> void:
	var al: Dictionary = scen.get("alleanza", {})
	if al.is_empty() or s["alleanza"] != "":
		return
	var l: int = s["lato"]
	var tiro := dado()
	var mod := clampi(int(s["pv"][1]) - int(s["pv"][0]), -4, 4)
	var t := clampi(tiro + mod, 0, 7)
	eventi.append({"k": "dado", "titolo": "Alleanze", "dadi": [tiro]})
	var naz: String = Dati.NAZ[al["nazione"]]["nome"]
	if l == int(al["lato"]) and t >= 7:
		s["alleanza"] = "si"
		for st in al["stati"]:
			if not st in s["in_guerra"]:
				s["in_guerra"].append(st)
		_aggiorna_aperti()
		for h in Mappa.esagoni:
			if Mappa.ha_citta(h) and Mappa.stato(h) in al["stati"] and sp_in(h, 1 - l) == 0:
				s["controllo"][h] = l
		for g in al["schieramento"]:
			_schiera(g)
		_log("[b]Alleanze[/b] (dado %d, modificato %d): la %s entra in guerra con la Coalizione!" % [tiro, t, naz])
		eventi.append({"k": "annuncio", "t": "La %s entra in guerra!" % naz})
	elif l != int(al["lato"]) and t <= 0:
		s["alleanza"] = "no"
		_log("[b]Alleanze[/b] (dado %d, modificato %d): la %s resterà neutrale." % [tiro, t, naz])
		eventi.append({"k": "annuncio", "t": "La %s resterà neutrale" % naz})
	else:
		_log("Alleanze (dado %d, modificato %d): nessun effetto." % [tiro, t])

func _fase_rinforzi() -> void:
	var l: int = s["lato"]
	var lista: Array = scen.get("rinforzi", {}).get(str(s["turno"]), [])
	for g in lista:
		var h := Mappa.hex(g["hex"])
		var naz: String = g["unita"][0][0] if not g["unita"].is_empty() else str(g["capi"][0]).split(":")[0]
		if lato_di(naz) != l:
			continue
		if nemico_fuori(h, l) or controllore(h) != l:
			# città occupata: i rinforzi arrivano nella città amica più vicina
			h = _citta_amica_vicina(h, l)
			if h == "":
				continue
		_schiera_in(g, h)
		_log("Rinforzi a %s." % Mappa.nome(h))
	# capi feriti che tornano
	for id in s["capi"]:
		var c: Dictionary = s["capi"][id]
		if c["h"] == "" and not c["morto"] and lato_di(c["n"]) == l and int(c["fuori"]) > 0 and int(c["fuori"]) <= int(s["turno"]):
			var dove := _hex_amico_per_capo(c["n"], l)
			if dove != "":
				c["h"] = dove
				c["fuori"] = 0
				_log("%s rientra in servizio a %s." % [c["nome"], Mappa.nome(dove)])

func _schiera_in(g: Dictionary, h: String) -> void:
	var g2 := g.duplicate()
	g2["hex"] = Mappa.nome_citta(h)
	_schiera(g2)

func _citta_amica_vicina(h0: String, l: int) -> String:
	var best := ""
	var bd := INF
	for h in Mappa.esagoni:
		if Mappa.citta_maggiore(h) and controllore(h) == l and not nemico_fuori(h, l):
			var d := Mappa.pos(h).distance_to(Mappa.pos(h0))
			if d < bd:
				bd = d
				best = h
	return best

func _hex_amico_per_capo(naz: String, l: int) -> String:
	var r: Dictionary = s["rifornimento"].get(str(l), {}).get(naz, {})
	for id in s["unita"]:
		var u: Dictionary = s["unita"][id]
		if u["n"] == naz and r.has(u["h"]):
			return u["h"]
	for id in s["unita"]:
		if s["unita"][id]["n"] == naz:
			return s["unita"][id]["h"]
	return ""

func _fine_segmento() -> void:
	_compatta()
	for h in s["controllo"].keys():
		_aggiorna_controllo(h)
	if s["lato"] == 0:
		s["lato"] = 1
	else:
		if int(s["turno"]) >= int(scen["turni"]):
			_fine_partita()
			return
		s["lato"] = 0
		s["turno"] += 1
		s["mese"] += 1
		if s["mese"] >= 12:
			s["mese"] = 0
			s["anno"] += 1
	_inizia_segmento()

# =============================================================================================
# Richieste e azioni

## La decisione che il gioco aspetta ora: {k, lato, ...}
func richiesta() -> Dictionary:
	match s["fase"]:
		"movimento":
			return {"k": "movimento", "lato": s["lato"]}
		"dichiara":
			return {"k": "dichiara", "lato": s["lato"]}
		"battaglie":
			return _richiesta_battaglie()
	return {}

func applica(d: Dictionary) -> bool:
	eventi.clear()
	var rq := richiesta()
	if rq.is_empty():
		return false
	var ok := false
	match str(d.get("a", "")):
		"muovi":
			ok = rq["k"] == "movimento" and _muovi(d)
		"trincea":
			ok = rq["k"] == "movimento" and _trincea(str(d.get("h", "")))
		"fine":
			if rq["k"] == "movimento":
				_fine_movimento()
				ok = true
			elif rq["k"] == "dichiara":
				_inizia_battaglie()
				ok = true
		"attacco":
			ok = rq["k"] == "dichiara" and _dichiara(str(d.get("da", "")), str(d.get("su", "")))
		"annulla":
			ok = rq["k"] == "dichiara" and _annulla(str(d.get("su", "")))
		"scelta":
			ok = rq["k"] in ["citta", "assalto", "continua", "resta"] and _scelta(rq, str(d.get("v", "")))
	if ok:
		s["azioni"] += 1
	return ok

# =============================================================================================
# Movimento (regole J, K, L)

## Gruppo che si muove: capo (opzionale) e unità con i punti forza portati.
## Restituisce i limiti: mp del capo rimasti, mp delle truppe, ecc.
func info_gruppo(capo: String, porta: Dictionary) -> Dictionary:
	var out := {"ok": true, "errore": "", "mp_capo": 0, "mp_truppe": 99, "fanteria": false, "sp": 0, "cav": 0, "da": ""}
	var l: int = s["lato"]
	var h := ""
	if capo != "":
		if not s["capi"].has(capo):
			return {"ok": false, "errore": "capo inesistente"}
		var c: Dictionary = s["capi"][capo]
		if lato_di(c["n"]) != l or c["h"] == "":
			return {"ok": false, "errore": "capo non disponibile"}
		h = c["h"]
		out["mp_capo"] = mp_capo(capo) - int(c["mp"])
		if _assediato(h, l) and _dentro_capo(capo):
			return {"ok": false, "errore": "assediato"}
	for id in porta:
		if not s["unita"].has(id):
			return {"ok": false, "errore": "unità inesistente"}
		var u: Dictionary = s["unita"][id]
		var n := int(porta[id])
		if n <= 0 or n > int(u["sp"]):
			return {"ok": false, "errore": "punti forza non validi"}
		if lato_unita(u) != l:
			return {"ok": false, "errore": "unità nemica"}
		if u["mo"]:
			return {"ok": false, "errore": "unità già mossa"}
		if u["in"] and s["assedi"].has(u["h"]):
			return {"ok": false, "errore": "unità assediata"}
		if h == "":
			h = u["h"]
		elif u["h"] != h:
			return {"ok": false, "errore": "unità in esagoni diversi"}
		out["sp"] += n
		if Dati.e_cavalleria(u["t"]):
			out["cav"] += n
			out["mp_truppe"] = mini(out["mp_truppe"], 4)
		else:
			out["fanteria"] = true
			out["mp_truppe"] = mini(out["mp_truppe"], 3)
			if capo == "":
				return {"ok": false, "errore": "la fanteria si muove solo con un capo"}
			var c2: Dictionary = s["capi"][capo]
			if c2["n"] != u["n"]:
				return {"ok": false, "errore": "la fanteria segue solo capi del suo colore"}
	if capo != "" and not porta.is_empty():
		if int(s["capi"][capo]["mp"]) > 0:
			return {"ok": false, "errore": "il capo ha già mosso: non può raccogliere truppe"}
		if out["sp"] > max_porta(capo):
			return {"ok": false, "errore": "troppi punti forza per un capo (massimo %d)" % max_porta(capo)}
		# cavalleria con capo: il limite della cavalleria
	if porta.is_empty():
		out["mp_truppe"] = 0
	out["da"] = h
	if h == "":
		return {"ok": false, "errore": "niente da muovere"}
	return out

func _dentro_capo(_capo: String) -> bool:
	return true

func _assediato(h: String, l: int) -> bool:
	return s["assedi"].has(h) and int(s["assedi"][h]["lato"]) != l

## Esagoni raggiungibili dal gruppo: {esagono: {"mp": costo, "fm": punti di marcia forzata necessari, "via": precedente}}
func raggiungibili(capo: String, porta: Dictionary, fm_max := 3) -> Dictionary:
	var g := info_gruppo(capo, porta)
	if not g["ok"]:
		return {}
	var l: int = s["lato"]
	var da: String = g["da"]
	var limite_truppe: int = g["mp_truppe"] + (fm_max if not porta.is_empty() else 0)
	var limite: int
	if porta.is_empty():
		limite = g["mp_capo"]
	elif capo == "":
		limite = limite_truppe
	else:
		limite = mini(g["mp_capo"], limite_truppe)
	var dist := {da: 0}
	var via := {da: ""}
	var coda := [da]
	var forza: int = g["sp"]
	var puo_travolgere := not porta.is_empty() and _gruppo_rifornito(porta)
	while not coda.is_empty():
		var bi := 0
		for i in coda.size():
			if dist[coda[i]] < dist[coda[bi]]:
				bi = i
		var h: String = coda[bi]
		coda.remove_at(bi)
		for v in Mappa.vicini(h):
			var n: String = v[0]
			if not aperto(n):
				continue
			var c := Mappa.costo(h, n)
			if nemico_fuori(n, l):
				# travolgimento (overrun)
				if not puo_travolgere:
					continue
				var t := _travolge(n, forza, int(g["cav"]))
				if t < 0:
					continue
				if Mappa.ha_citta(n) and sp_in(n, 1 - l, true) > 0:
					pass
				c += t
			var d: int = dist[h] + c
			if d <= limite and d < dist.get(n, 999):
				dist[n] = d
				via[n] = h
				coda.append(n)
	var out := {}
	for h in dist:
		if h == da:
			continue
		var fm := 0
		if not porta.is_empty() and dist[h] > g["mp_truppe"]:
			fm = dist[h] - g["mp_truppe"]
		# non si può terminare in una città dopo averla travolta
		out[h] = {"mp": dist[h], "fm": fm, "via": via[h]}
	return out

## Costo aggiuntivo del travolgimento: 0 con 6:1, 1 con 4:1 (5:1 in montagna o trincea), -1 se impossibile
func _travolge(h: String, forza: int, cav: int) -> int:
	var l: int = s["lato"]
	var dif := sp_in(h, 1 - l, true)
	if dif <= 0:
		return 0
	var cav_dif := 0
	for id in unita_in(h, 1 - l, true):
		if Dati.e_cavalleria(s["unita"][id]["t"]):
			cav_dif += int(s["unita"][id]["sp"])
	if cav_dif > 0 and cav < cav_dif:
		return -1
	var minimo := 4
	if Mappa.terreno(h) == "montagna" or s["trincee"].has(h):
		minimo = 5
	if forza >= dif * 6:
		return 0
	if forza >= dif * minimo:
		return 1
	return -1

func _gruppo_rifornito(porta: Dictionary) -> bool:
	var l: int = s["lato"]
	for id in porta:
		if not rifornita(s["unita"][id], l):
			return false
	return true

func percorso(rag: Dictionary, a: String) -> Array:
	var out := []
	var h := a
	while h != "" and rag.has(h):
		out.push_front(h)
		h = rag[h]["via"]
	return out

## d = {a:"muovi", capo, porta:{id:sp}, verso, fm}
func _muovi(d: Dictionary) -> bool:
	var capo := str(d.get("capo", ""))
	var porta: Dictionary = {}
	for k in d.get("porta", {}):
		porta[str(k)] = int(d["porta"][k])
	var verso := str(d.get("verso", ""))
	var fm := clampi(int(d.get("fm", 0)), 0, 3)
	var g := info_gruppo(capo, porta)
	if not g["ok"]:
		return false
	var rag := raggiungibili(capo, porta, fm)
	if not rag.has(verso):
		return false
	var l: int = s["lato"]
	var strada := percorso(rag, verso)
	var da: String = g["da"]
	var costo_tot: int = rag[verso]["mp"]
	var serve_fm: int = rag[verso]["fm"]
	# separa i punti forza portati in nuove unità
	var mobili := []
	for id in porta:
		mobili.append(_separa(id, int(porta[id])))
	var arrivo := verso
	var nota := ""
	if serve_fm > 0:
		var tiro := dado()
		var t := tiro
		var tutti_fr := true
		var tutti_guardia := true
		var senza := false
		for id in mobili:
			var u: Dictionary = s["unita"][id]
			if u["n"] != "FR" or u["s"] != "":
				tutti_fr = false
			if u["t"] != "GI" and u["t"] != "GC":
				tutti_guardia = false
			if not rifornita(u, l):
				senza = true
		if tutti_fr and tutti_guardia: t -= 2
		elif tutti_fr: t -= 1
		if senza: t += 1
		if Mappa.area(da) in [1, 4]: t += 1
		if inverno(): t += 1
		var r := Dati.marcia(t, fm)
		var ottenuti: int = r[0]
		eventi.append({"k": "dado", "titolo": "Marcia forzata +%d" % fm, "dadi": [tiro]})
		nota = " (marcia forzata: dado %d, +%d%s)" % [tiro, ottenuti, "*" if r[1] else ""]
		if r[1]:
			_elimina_sp(mobili, 1, false, "")
		if ottenuti < serve_fm:
			# si ferma all'ultimo esagono raggiungibile
			var limite: int = g["mp_truppe"] + ottenuti
			arrivo = da
			for h in strada:
				if rag[h]["mp"] <= limite:
					arrivo = h
			strada = strada.slice(0, strada.find(arrivo) + 1)
			costo_tot = rag[arrivo]["mp"] if rag.has(arrivo) else 0
	# travolgimenti lungo la strada
	var ultimo := da
	for h in strada:
		if nemico_fuori(h, l):
			var forza := 0
			for id in mobili:
				if s["unita"].has(id):
					forza += int(s["unita"][id]["sp"])
			var cav := 0
			for id in mobili:
				if s["unita"].has(id) and Dati.e_cavalleria(s["unita"][id]["t"]):
					cav += int(s["unita"][id]["sp"])
			if _travolge(h, forza, cav) < 0:
				arrivo = ultimo
				break
			var elim := sp_in(h, 1 - l, true)
			for id in unita_in(h, 1 - l, true):
				s["unita"].erase(id)
			_log("[b]Travolgimento[/b] a %s: eliminati %d punti forza nemici." % [Mappa.nome(h), elim])
			_ricolloca_capi(h, 1 - l)
			s["trincee"].erase(h)
		ultimo = h
		if h == arrivo:
			break
	# sposta
	for id in mobili:
		if s["unita"].has(id):
			s["unita"][id]["h"] = arrivo
			s["unita"][id]["mo"] = true
			s["unita"][id]["in"] = false
	if capo != "":
		s["capi"][capo]["h"] = arrivo
		var spesi: int = costo_tot
		if rag.has(arrivo):
			spesi = rag[arrivo]["mp"]
		elif arrivo == da:
			spesi = 0
		s["capi"][capo]["mp"] = int(s["capi"][capo]["mp"]) + spesi
		if not porta.is_empty():
			# chi ha portato truppe non può più raccoglierne: le truppe restano "mosse"
			pass
	if sp_in(da, l) == 0:
		s["trincee"].erase(da)
	_aggiorna_controllo(arrivo)
	var chi: String = s["capi"][capo]["nome"] if capo != "" else "Cavalleria"
	var quanti := 0
	for id in mobili:
		if s["unita"].has(id):
			quanti += int(s["unita"][id]["sp"])
	_log("%s%s: %s » %s%s" % [chi, (" con %d PF" % quanti) if quanti > 0 else "", Mappa.nome(da), Mappa.nome(arrivo), nota])
	eventi.append({"k": "mossa", "da": da, "a": arrivo, "strada": strada})
	return true

func _separa(id: String, n: int) -> String:
	var u: Dictionary = s["unita"][id]
	if n >= int(u["sp"]):
		return id
	u["sp"] = int(u["sp"]) - n
	var nid := "u%d" % s["prossimo"]
	s["prossimo"] += 1
	s["unita"][nid] = {"n": u["n"], "s": u["s"], "t": u["t"], "sp": n, "h": u["h"], "mo": false, "in": u["in"]}
	return nid

func _ricolloca_capi(h: String, lato: int) -> void:
	for id in capi_in(h, lato):
		var c: Dictionary = s["capi"][id]
		var dove := _hex_amico_vicino(h, c["n"], lato)
		c["h"] = dove
		if dove == "":
			c["fuori"] = int(s["turno"]) + 1
			_log("%s resta senza truppe e si ritira." % c["nome"])

func _hex_amico_vicino(h0: String, naz: String, lato: int) -> String:
	var best := ""
	var bd := INF
	for id in s["unita"]:
		var u: Dictionary = s["unita"][id]
		if u["h"] != h0 and lato_unita(u) == lato and (u["n"] == naz or best == ""):
			if s["assedi"].has(u["h"]) and u["in"]:
				continue
			var d := Mappa.pos(u["h"]).distance_to(Mappa.pos(h0))
			if u["n"] != naz:
				d += 100000.0
			if d < bd:
				bd = d
				best = u["h"]
	return best

func _trincea(h: String) -> bool:
	var l: int = s["lato"]
	if not Mappa.esiste(h) or s["trincee"].has(h):
		return false
	if Mappa.citta_maggiore(h):
		return false
	var tot := 0
	for id in unita_in(h, l, true):
		if s["unita"][id]["mo"]:
			continue
		tot += int(s["unita"][id]["sp"])
	if tot < 3:
		return false
	for id in unita_in(h, l, true):
		s["unita"][id]["mo"] = true
	s["trincee"][h] = l
	_log("Trincee a %s." % Mappa.nome(h))
	return true

func puo_trincerare(h: String) -> bool:
	var l: int = s["lato"]
	if s["fase"] != "movimento" or s["trincee"].has(h) or Mappa.citta_maggiore(h):
		return false
	var tot := 0
	for id in unita_in(h, l, true):
		if not s["unita"][id]["mo"]:
			tot += int(s["unita"][id]["sp"])
	return tot >= 3

func _fine_movimento() -> void:
	_compatta()
	for h in s["controllo"].keys():
		_aggiorna_controllo(h)
	s["fase"] = "dichiara"
	s["batt"] = []
	_log("Fine del movimento.")
	# fotografia delle forze a inizio combattimento (per i punti vittoria)
	s["sp_inizio"] = {}
	var l: int = s["lato"]
	for h in esagoni_di(1 - l):
		var nap := false
		for id in capi_in(h, 1 - l):
			if s["capi"][id]["nome"] == "Napoleon":
				nap = true
		s["sp_inizio"][h] = {"sp": sp_in(h, 1 - l), "nap": nap}
	if attacchi_possibili().is_empty():
		_fine_combattimento()

# =============================================================================================
# Combattimento (regole N, O, P, Q, R, S)

## Coppie [da, su] possibili per il lato attivo
func attacchi_possibili() -> Array:
	var l: int = s["lato"]
	var out := []
	for h in esagoni_di(l):
		if sp_in(h, l, true) <= 0:
			continue
		for v in Mappa.vicini(h):
			var n: String = v[0]
			if sp_in(n, 1 - l) > 0:
				out.append([h, n])
		# nemici chiusi in città nello stesso esagono: assalto o assedio
		if sp_in(h, 1 - l, false, true) > 0:
			out.append([h, h])
	return out

func _dichiara(da: String, su: String) -> bool:
	var l: int = s["lato"]
	var ok := false
	for p in attacchi_possibili():
		if p[0] == da and p[1] == su:
			ok = true
	if not ok:
		return false
	for b in s["batt"]:
		if b["dif"] == su:
			return false
	s["batt"].append({"att": da, "dif": su, "la": l, "ld": 1 - l, "fine": false, "tipo": "campo",
		"ha": [da], "hd": [su], "dem": [0, 0], "pre": false, "esito": "", "rapporti": []})
	_log("Attacco dichiarato: %s » %s" % [Mappa.nome(da), Mappa.nome(su)])
	return true

func _annulla(su: String) -> bool:
	for i in s["batt"].size():
		if s["batt"][i]["dif"] == su:
			s["batt"].remove_at(i)
			return true
	return false

func _inizia_battaglie() -> void:
	if s["batt"].is_empty():
		_fine_combattimento()
		return
	s["fase"] = "battaglie"
	s["cb"] = {"r": 1, "i": 0, "passo": "pre"}
	s["coinvolti_capi"] = {}
	_avanza_battaglie()

## Prossima richiesta durante la risoluzione delle battaglie
func _richiesta_battaglie() -> Dictionary:
	var cb: Dictionary = s["cb"]
	if cb.is_empty() or int(cb["i"]) >= s["batt"].size():
		return {}
	var b: Dictionary = s["batt"][int(cb["i"])]
	match cb["passo"]:
		"citta":
			return {"k": "citta", "lato": b["ld"], "b": cb["i"], "opzioni": ["fuori", "dentro"]}
		"assalto":
			return {"k": "assalto", "lato": b["la"], "b": cb["i"], "opzioni": ["assalto", "assedio", "rinuncia"]}
		"continua":
			return {"k": "continua", "lato": b["la"], "b": cb["i"], "opzioni": ["continua", "interrompi"]}
		"resta":
			return {"k": "resta", "lato": b["ld"], "b": cb["i"], "opzioni": ["resta", "ritirati"]}
	return {}

func _scelta(rq: Dictionary, v: String) -> bool:
	if not v in rq.get("opzioni", []):
		return false
	var cb: Dictionary = s["cb"]
	var b: Dictionary = s["batt"][int(cb["i"])]
	match rq["k"]:
		"citta":
			if v == "dentro":
				_entra_in_citta(b)
			b["pre"] = true
			if sp_in(b["dif"], b["ld"], true) == 0 and sp_in(b["dif"], b["ld"], false, true) > 0:
				cb["passo"] = "assalto"
				return true
			cb["passo"] = "risolvi"
		"assalto":
			if v == "assalto":
				b["tipo"] = "assalto"
				cb["passo"] = "risolvi"
			elif v == "assedio":
				_metti_assedio(b)
				b["fine"] = true
				cb["passo"] = "prossima"
			else:
				b["fine"] = true
				_log("Attacco a %s annullato." % Mappa.nome(b["dif"]))
				cb["passo"] = "prossima"
		"continua":
			if v == "interrompi":
				b["fine"] = true
				_log("Battaglia di %s interrotta." % Mappa.nome(b["dif"]))
				cb["passo"] = "prossima"
			else:
				cb["passo"] = "resta" if b["tipo"] == "campo" else "rinforzi"
		"resta":
			if v == "ritirati":
				_ritirata_lato(b, b["ld"], true)
				_dopo_ritirata(b)
				cb["passo"] = "prossima"
			else:
				cb["passo"] = "rinforzi"
	_avanza_battaglie()
	return true

## Fa avanzare la macchina delle battaglie fino alla prossima decisione
func _avanza_battaglie() -> void:
	var guard := 0
	while s["fase"] == "battaglie" and guard < 500:
		guard += 1
		var cb: Dictionary = s["cb"]
		var i := int(cb["i"])
		if i >= s["batt"].size():
			# fine del round: si ricomincia con le battaglie ancora aperte
			var aperte := false
			for b in s["batt"]:
				if not b["fine"]:
					aperte = true
			if not aperte:
				_fine_combattimento()
				return
			cb["r"] = int(cb["r"]) + 1
			cb["i"] = 0
			cb["passo"] = "pre"
			continue
		var b: Dictionary = s["batt"][i]
		if b["fine"] or (cb["passo"] == "prossima"):
			cb["i"] = i + 1
			cb["passo"] = "pre"
			continue
		match cb["passo"]:
			"pre":
				# la battaglia finisce se uno dei due esagoni originali è vuoto
				if not _battaglia_viva(b):
					b["fine"] = true
					cb["passo"] = "prossima"
					continue
				if int(cb["r"]) == 1 and not b["pre"]:
					if b["att"] == b["dif"]:
						b["pre"] = true
						if s["assedi"].has(b["dif"]):
							b["tipo"] = "assalto"
							cb["passo"] = "risolvi"
							continue
						cb["passo"] = "assalto"
						return
					if Mappa.ha_citta(b["dif"]) and controllore(b["dif"]) == int(b["ld"]) and not s["assedi"].has(b["dif"]):
						cb["passo"] = "citta"
						return
					if sp_in(b["dif"], b["ld"], true) == 0 and sp_in(b["dif"], b["ld"], false, true) > 0:
						b["pre"] = true
						cb["passo"] = "assalto"
						return
					b["pre"] = true
				cb["passo"] = "risolvi"
			"risolvi":
				_risolvi_round(b)
				if not _battaglia_viva(b):
					_dopo_ritirata(b)
					b["fine"] = true
					cb["passo"] = "prossima"
					continue
				# assalto: i difensori con morale zero si arrendono
				if b["tipo"] == "assalto" and _morale_lato(b, int(b["ld"])) <= 0:
					var n := sp_in(b["dif"], b["ld"], false, true)
					for id in unita_in(b["dif"], b["ld"]):
						if s["unita"][id]["in"]:
							s["unita"].erase(id)
					_log("La guarnigione di %s si arrende (%d PF)." % [Mappa.nome(b["dif"]), n])
					_capi_catturati(b["dif"], int(b["ld"]))
					s["assedi"].erase(b["dif"])
					_aggiorna_controllo(b["dif"])
					b["fine"] = true
					cb["passo"] = "prossima"
					continue
				cb["passo"] = "continua"
				return
			"rinforzi":
				_rinforzi_battaglia(b)
				# ritirata obbligatoria con morale zero (solo battaglia campale)
				if b["tipo"] == "campo":
					for lato in [int(b["la"]), int(b["ld"])]:
						if _morale_lato(b, lato) <= 0 and _sp_battaglia(b, lato) > 0:
							_log("Morale a zero: %s si ritira." % LATI_FORZE(lato))
							_ritirata_lato(b, lato, false)
				if not _battaglia_viva(b):
					_dopo_ritirata(b)
					b["fine"] = true
				cb["passo"] = "prossima"

static func LATI_FORZE(l: int) -> String:
	return "le forze francesi" if l == 0 else "le forze alleate"

func _battaglia_viva(b: Dictionary) -> bool:
	var la := int(b["la"])
	var ld := int(b["ld"])
	if b["tipo"] == "assalto":
		return sp_in(b["dif"], ld, false, true) > 0 and _sp_battaglia(b, la) > 0
	return sp_in(b["att"], la, true) > 0 and sp_in(b["dif"], ld, true) > 0

## Unità impegnate di un lato in una battaglia
func _impegnate(b: Dictionary, lato: int) -> Array:
	var out := []
	var hexes: Array = b["ha"] if lato == int(b["la"]) else b["hd"]
	for h in hexes:
		for id in unita_in(h, lato):
			var u: Dictionary = s["unita"][id]
			if b["tipo"] == "assalto":
				if lato == int(b["ld"]) and h == b["dif"]:
					if u["in"]:
						out.append(id)
				elif not u["in"]:
					out.append(id)
			elif not u["in"]:
				out.append(id)
	return out

func _sp_battaglia(b: Dictionary, lato: int) -> int:
	var t := 0
	for id in _impegnate(b, lato):
		t += int(s["unita"][id]["sp"])
	return t

func _morale_lato(b: Dictionary, lato: int) -> int:
	var conta := {}
	var dentro: bool = b["tipo"] == "assalto" and lato == int(b["ld"])
	for id in _impegnate(b, lato):
		var u: Dictionary = s["unita"][id]
		var m := Dati.morale(u["n"], u["s"], u["t"])
		if dentro and m == 0:
			m = 1
		conta[m] = conta.get(m, 0) + int(u["sp"])
	if conta.is_empty():
		return 0
	var best := -1
	var bn := -1
	for m in conta:
		if conta[m] > bn or (conta[m] == bn and m < best):
			bn = conta[m]
			best = m
	var dem := int(b["dem"][0 if lato == int(b["la"]) else 1])
	return maxi(0, best - dem)

## Il capo che comanda: nell'esagono con più punti forza impegnati, dello stesso colore della maggioranza
func _capo_battaglia(b: Dictionary, lato: int) -> String:
	var per_hex := {}
	var per_naz := {}
	for id in _impegnate(b, lato):
		var u: Dictionary = s["unita"][id]
		per_hex[u["h"]] = per_hex.get(u["h"], 0) + int(u["sp"])
		per_naz[u["n"]] = per_naz.get(u["n"], 0) + int(u["sp"])
	if per_hex.is_empty():
		return ""
	var hb := ""
	for h in per_hex:
		if hb == "" or per_hex[h] > per_hex[hb]:
			hb = h
	var nb := ""
	for n in per_naz:
		if nb == "" or per_naz[n] > per_naz[nb]:
			nb = n
	var best := ""
	for id in capi_in(hb, lato):
		var c: Dictionary = s["capi"][id]
		if c["n"] == nb and (best == "" or int(c["v"]) > int(s["capi"][best]["v"])):
			best = id
	return best

func _rifornimento_battaglia(lato: int) -> void:
	calcola_rifornimento(lato)

func _forza_effettiva(b: Dictionary, lato: int) -> int:
	var l_att: int = s["lato"]
	var tot := 0
	var senza := 0
	for id in _impegnate(b, lato):
		var u: Dictionary = s["unita"][id]
		if lato == l_att and not rifornita(u, lato):
			senza += int(u["sp"])
		else:
			tot += int(u["sp"])
	tot += int(ceil(senza / 2.0))
	if b["tipo"] == "assalto" and lato == int(b["ld"]):
		tot *= 2
	return tot

func _risolvi_round(b: Dictionary) -> void:
	_rifornimento_battaglia(int(b["la"]))
	_rifornimento_battaglia(int(b["ld"]))
	var la := int(b["la"])
	var ld := int(b["ld"])
	var fa := _forza_effettiva(b, la)
	var fd := _forza_effettiva(b, ld)
	var grande := la if fa >= fd else ld
	var piccola := 1 - grande
	var fg := maxi(fa, fd)
	var fp := mini(fa, fd)
	var rap := Dati.rapporto(fg, fp)
	var cg := _capo_battaglia(b, grande)
	var cp := _capo_battaglia(b, piccola)
	var vg := int(s["capi"][cg]["v"]) if cg != "" else 0
	var vp := int(s["capi"][cp]["v"]) if cp != "" else 0
	var mg := _morale_lato(b, grande)
	var mp := _morale_lato(b, piccola)
	var mods := []
	var mod := vg - vp + mg - mp
	mods.append(["Comando", vg - vp])
	mods.append(["Morale", mg - mp])
	if b["tipo"] == "campo":
		var tm := 0
		var t: int = Dati.MOD_TERRENO.get(Mappa.terreno(b["dif"]), 0)
		if Mappa.fiume_tra(b["att"], b["dif"]):
			t += Dati.MOD_FIUME
		if s["trincee"].has(b["dif"]) and int(s["trincee"][b["dif"]]) == ld:
			t += 1
		# il terreno favorisce chi viene attaccato
		tm = t if ld == grande else -t
		if tm != 0:
			mods.append(["Terreno", tm])
		mod += tm
	mod = clampi(mod, -4, 4)
	var d1 := dado()
	var d2 := dado()
	var tiro := clampi(d1 + d2 + mod, 2, 12)
	var rg := "0"
	var rp := "0"
	if rap == "4:1":
		rp = "D3"
	else:
		var r: Array = Dati.CRT[rap][tiro - 2]
		rg = r[0]
		rp = r[1]
	var piccola_sp := _sp_battaglia(b, piccola)
	var pp := Dati.perdita(rp, piccola_sp)
	if rap == "4:1":
		rg = "1" if pp > 1 else "0"
	var pg := Dati.perdita(rg, piccola_sp)
	_elimina_battaglia(b, grande, pg, rg.begins_with("D"), cg)
	_elimina_battaglia(b, piccola, pp, rp.begins_with("D"), cp)
	b["dem"][0 if grande == la else 1] = int(b["dem"][0 if grande == la else 1]) + Dati.demoralizzazione(rg)
	b["dem"][0 if piccola == la else 1] = int(b["dem"][0 if piccola == la else 1]) + Dati.demoralizzazione(rp)
	for lato in [la, ld]:
		var c := _capo_battaglia(b, lato)
		for id in s["capi"]:
			if s["capi"][id]["h"] in (b["ha"] if lato == la else b["hd"]):
				s["coinvolti_capi"][id] = true
		if c != "":
			s["coinvolti_capi"][c] = true
	var rep := {"r": s["cb"]["r"], "att": b["att"], "dif": b["dif"], "tipo": b["tipo"],
		"forze": [fa, fd], "grande": grande, "rapporto": rap, "capi": [s["capi"][cg]["nome"] if cg != "" else "—", s["capi"][cp]["nome"] if cp != "" else "—"],
		"mods": mods, "mod": mod, "dadi": [d1, d2], "tiro": tiro, "ris": [rg, rp], "perdite": [pg, pp]}
	b["rapporti"].append(rep)
	eventi.append({"k": "battaglia", "rep": rep})
	_log("[b]Battaglia di %s[/b] (round %d%s): %d contro %d, %s; dadi %d+%d %+d = %d » %s %s / %s %s (perdite %d e %d)" % [
		Mappa.nome(b["dif"]), int(s["cb"]["r"]), ", assalto" if b["tipo"] == "assalto" else "", fa, fd, rap, d1, d2, mod, tiro,
		LATI_BREVI_(grande), rg, LATI_BREVI_(piccola), rp, pg, pp])
	_compatta_battaglia(b)
	for lato in [la, ld]:
		_controlla_capi_soli(b, lato)

static func LATI_BREVI_(l: int) -> String:
	return Dati.LATI_BREVI[l]

func _compatta_battaglia(_b: Dictionary) -> void:
	for id in s["unita"].keys():
		if int(s["unita"][id]["sp"]) <= 0:
			s["unita"].erase(id)

## Elimina n punti forza dalle unità impegnate seguendo le priorità della regola P3
func _elimina_battaglia(b: Dictionary, lato: int, n: int, demor: bool, capo: String) -> void:
	if n <= 0:
		return
	var ids := _impegnate(b, lato)
	var morale := _morale_lato(b, lato) + int(b["dem"][0 if lato == int(b["la"]) else 1])
	var naz: String = s["capi"][capo]["n"] if capo != "" else ""
	_elimina_sp(ids, n, demor and n > 1, naz, morale)

## Elimina n punti forza da un insieme di unità: prima una cavalleria (se richiesto),
## poi preferibilmente quelle con il morale indicato e del colore del capo
func _elimina_sp(ids: Array, n: int, una_cav: bool, naz: String, morale := -1) -> void:
	var resto := n
	if una_cav:
		for id in ids:
			if resto > 0 and s["unita"].has(id) and Dati.e_cavalleria(s["unita"][id]["t"]) and int(s["unita"][id]["sp"]) > 0:
				s["unita"][id]["sp"] = int(s["unita"][id]["sp"]) - 1
				resto -= 1
				break
	var ordinati := ids.duplicate()
	ordinati.sort_custom(func(a, b):
		var ua: Dictionary = s["unita"].get(a, {})
		var ub: Dictionary = s["unita"].get(b, {})
		if ua.is_empty() or ub.is_empty():
			return false
		return _priorita(ua, naz, morale) > _priorita(ub, naz, morale))
	for id in ordinati:
		while resto > 0 and s["unita"].has(id) and int(s["unita"][id]["sp"]) > 0:
			s["unita"][id]["sp"] = int(s["unita"][id]["sp"]) - 1
			resto -= 1
	for id in ids:
		if s["unita"].has(id) and int(s["unita"][id]["sp"]) <= 0:
			s["unita"].erase(id)

func _priorita(u: Dictionary, naz: String, morale: int) -> int:
	var p := 0
	var m := Dati.morale(u["n"], u["s"], u["t"])
	if morale >= 0 and m == morale:
		p += 100
	if naz != "" and u["n"] == naz:
		p += 50
	p -= m * 10
	if u["t"] == "GI" or u["t"] == "GC":
		p -= 30
	p += mini(int(u["sp"]), 20)
	return p

## Se un capo resta senza truppe dopo il combattimento: tiro per le perdite e ricollocazione
func _controlla_capi_soli(b: Dictionary, lato: int) -> void:
	var hexes: Array = b["ha"] if lato == int(b["la"]) else b["hd"]
	for h in hexes:
		if sp_in(h, lato) > 0:
			continue
		for id in capi_in(h, lato):
			var c: Dictionary = s["capi"][id]
			if _ferito(id):
				continue
			if b["tipo"] == "assalto" and h == b["dif"] and lato == int(b["ld"]):
				c["morto"] = true
				c["h"] = ""
				_log("%s è fatto prigioniero." % c["nome"])
			else:
				var dove := _hex_amico_vicino(h, c["n"], lato)
				c["h"] = dove
				if dove == "":
					c["fuori"] = int(s["turno"]) + 1
				_log("%s raggiunge le sue truppe a %s." % [c["nome"], Mappa.nome(dove) if dove != "" else "—"])
				s["coinvolti_capi"].erase(id)

func _capi_catturati(h: String, lato: int) -> void:
	for id in capi_in(h, lato):
		if sp_in(h, lato) == 0:
			s["capi"][id]["morto"] = true
			s["capi"][id]["h"] = ""
			_log("%s è fatto prigioniero." % s["capi"][id]["nome"])

## Tiro per le perdite fra i capi (regola R): true se il capo è uscito di scena
func _ferito(id: String) -> bool:
	var c: Dictionary = s["capi"][id]
	if c["nome"].begins_with("Leader"):
		return false
	var t := dado() + dado()
	if t < 12:
		return false
	var d := dado()
	if d == 6:
		c["morto"] = true
		c["h"] = ""
		_log("[b]%s è ucciso in battaglia![/b]" % c["nome"])
		eventi.append({"k": "annuncio", "t": "%s è caduto in battaglia" % c["nome"]})
		_sostituisci_capo(id)
	else:
		c["h"] = ""
		c["fuori"] = int(s["turno"]) + d
		_log("[b]%s è ferito[/b]: torna fra %d mesi." % [c["nome"], d])
		_sostituisci_capo(id)
	return true

func _sostituisci_capo(_id: String) -> void:
	pass

## Ingresso in città: i migliori punti forza fino alla capienza
func _entra_in_citta(b: Dictionary) -> void:
	var h: String = b["dif"]
	var l := int(b["ld"])
	var cap := Dati.capienza(Mappa.tipo_citta(h))
	var ids := unita_in(h, l, true)
	ids.sort_custom(func(a, c): return Dati.morale(s["unita"][a]["n"], s["unita"][a]["s"], s["unita"][a]["t"]) > Dati.morale(s["unita"][c]["n"], s["unita"][c]["s"], s["unita"][c]["t"]))
	var dentro := 0
	for id in ids:
		var u: Dictionary = s["unita"][id]
		if dentro >= cap:
			break
		var n := mini(int(u["sp"]), cap - dentro)
		var nid := _separa(id, n)
		s["unita"][nid]["in"] = true
		dentro += n
	_log("%d punti forza si chiudono nelle fortificazioni di %s." % [dentro, Mappa.nome(h)])

func _metti_assedio(b: Dictionary) -> void:
	var h: String = b["dif"]
	var la := int(b["la"])
	# gli attaccanti entrano nell'esagono per assediare
	for id in unita_in(b["att"], la, true):
		s["unita"][id]["h"] = h
	for id in capi_in(b["att"], la):
		s["capi"][id]["h"] = h
	s["assedi"][h] = {"l": 0, "lato": la}
	_log("[b]Assedio[/b] di %s." % Mappa.nome(h))

## Rinforzi a fine round: tiro di un dado + capo >= 5 per ogni esagono adiacente
func _rinforzi_battaglia(b: Dictionary) -> void:
	for lato in [int(b["la"]), int(b["ld"])]:
		if not s["opzioni"].get("rinforzi_" + str(lato), true):
			continue
		var gia: Array = b["ha"] if lato == int(b["la"]) else b["hd"]
		var dem_prima := int(b["dem"][0 if lato == int(b["la"]) else 1])
		var sp_dem := _sp_battaglia(b, lato)
		var fresche := 0
		var candidati := {}
		for h0 in [b["att"], b["dif"]]:
			for v in Mappa.vicini(h0):
				var h: String = v[0]
				if h in gia or _impegnato_altrove(h, lato) or sp_in(h, lato, true) == 0 or nemico_fuori(h, lato):
					continue
				if s["assedi"].has(h):
					continue
				candidati[h] = true
		for h in candidati:
			var best := 0
			for id in capi_in(h, lato):
				best = maxi(best, int(s["capi"][id]["v"]))
			var t := dado()
			var n_sp := sp_in(h, lato, true)
			if t + best >= 5:
				fresche += n_sp
				# entra in battaglia: deve essere adiacente al nemico impegnato
				var nemici: Array = b["hd"] if lato == int(b["la"]) else b["ha"]
				var adiac := false
				for n in nemici:
					if Mappa.adiacenti(h, n):
						adiac = true
				var dove: String = h
				if not adiac:
					dove = b["att"] if lato == int(b["la"]) else b["dif"]
					for id in unita_in(h, lato, true):
						s["unita"][id]["h"] = dove
					for id in capi_in(h, lato):
						s["capi"][id]["h"] = dove
				else:
					gia.append(h)
				_log("Rinforzi da %s entrano nella battaglia di %s (dado %d)." % [Mappa.nome(h), Mappa.nome(b["dif"]), t])
		if dem_prima > 0 and fresche >= sp_dem and fresche > 0:
			b["dem"][0 if lato == int(b["la"]) else 1] = 0
			_log("I rinforzi rianimano il morale.")

func _impegnato_altrove(h: String, lato: int) -> bool:
	for b in s["batt"]:
		if b["fine"]:
			continue
		var gia: Array = b["ha"] if lato == int(b["la"]) else b["hd"]
		if h in gia:
			return true
	return false

## Ritirata di tutte le unità impegnate di un lato (regola Q)
func _ritirata_lato(b: Dictionary, lato: int, volontaria: bool) -> void:
	var hexes: Array = (b["ha"] if lato == int(b["la"]) else b["hd"]).duplicate()
	var nemico := 1 - lato
	var cav_n := 0
	for id in _impegnate(b, nemico):
		if Dati.e_cavalleria(s["unita"][id]["t"]):
			cav_n += int(s["unita"][id]["sp"])
	for h in hexes:
		var ids := unita_in(h, lato, true)
		if ids.is_empty():
			continue
		var cav := 0
		var tot := 0
		for id in ids:
			tot += int(s["unita"][id]["sp"])
			if Dati.e_cavalleria(s["unita"][id]["t"]):
				cav += int(s["unita"][id]["sp"])
		if cav_n > cav:
			_elimina_sp(ids, 1, false, "")
			ids = unita_in(h, lato, true)
		var dest := _dest_ritirata(h, lato)
		if dest == "":
			# chiuso: le unità entrano in città se possono, altrimenti sono eliminate
			if Mappa.ha_citta(h) and controllore(h) == lato and sp_in(h, lato, false, true) == 0:
				var cap := Dati.capienza(Mappa.tipo_citta(h))
				var dentro := 0
				for id in ids:
					if dentro + int(s["unita"][id]["sp"]) <= cap:
						s["unita"][id]["in"] = true
						dentro += int(s["unita"][id]["sp"])
					else:
						s["unita"].erase(id)
				_log("Senza via di ritirata: %d PF si chiudono in %s." % [dentro, Mappa.nome(h)])
			else:
				for id in ids:
					s["unita"].erase(id)
				_log("Senza via di ritirata: le truppe a %s sono catturate." % Mappa.nome(h))
				_capi_catturati(h, lato)
			continue
		for id in unita_in(h, lato, true):
			s["unita"][id]["h"] = dest
			s["unita"][id]["mo"] = true
		for id in capi_in(h, lato):
			s["capi"][id]["h"] = dest
		s["trincee"].erase(h)
		_log("%s si ritirano da %s a %s%s." % [Dati.LATI_BREVI[lato], Mappa.nome(h), Mappa.nome(dest), "" if volontaria else " (morale a zero)"])
		eventi.append({"k": "mossa", "da": h, "a": dest, "strada": [h, dest]})
	if lato == int(b["la"]):
		b["ha"] = []
	else:
		b["hd"] = []

## Esagono di ritirata: libero da nemici, non più lontano dalle fonti di rifornimento
func _dest_ritirata(h: String, lato: int) -> String:
	var d0 := _distanza_fonte(h, lato)
	var best := ""
	var bv := INF
	for v in Mappa.vicini(h):
		var n: String = v[0]
		if not aperto(n) or nemico_fuori(n, lato) or _impegnato_altrove(n, lato):
			continue
		var d := _distanza_fonte(n, lato)
		var val := float(d)
		if d > d0:
			val += 1000.0
		if Mappa.ha_citta(n) and controllore(n) == lato:
			val -= 0.5
		val += float(Mappa.costo(h, n)) * 0.1
		if val < bv:
			bv = val
			best = n
	return best

var _cache_dist := {}

func _distanza_fonte(h: String, lato: int) -> int:
	var k := "%d|%d" % [lato, s["azioni"]]
	if not _cache_dist.has(k):
		_cache_dist.clear()
		_cache_dist[k] = _mappa_distanze(lato)
	return _cache_dist[k].get(h, 999)

## Distanza (in punti movimento) di ogni esagono dalla città-fonte amica più vicina
func _mappa_distanze(lato: int) -> Dictionary:
	var dist := {}
	var coda := []
	for h in Mappa.esagoni:
		if Mappa.citta_maggiore(h) and controllore(h) == lato and not nemico_fuori(h, lato):
			var st := Mappa.stato(h)
			if lato_di(st) == lato:
				dist[h] = 0
				coda.append(h)
	var i := 0
	while i < coda.size():
		var h: String = coda[i]
		i += 1
		for v in Mappa.vicini(h):
			var n: String = v[0]
			var d: int = dist[h] + 1
			if d < dist.get(n, 999):
				dist[n] = d
				coda.append(n)
	return dist

## Dopo che un lato ha lasciato un esagono originale: avanzata del vincitore e punti vittoria
func _dopo_ritirata(b: Dictionary) -> void:
	var la := int(b["la"])
	var ld := int(b["ld"])
	if b["tipo"] == "assalto":
		_aggiorna_controllo(b["dif"])
		return
	# chi ha vinto?
	var vinc := -1
	var vuoto := ""
	var da := ""
	if sp_in(b["dif"], ld, true) == 0 and sp_in(b["att"], la, true) > 0:
		vinc = la
		vuoto = b["dif"]
		da = b["att"]
	elif sp_in(b["att"], la, true) == 0 and sp_in(b["dif"], ld, true) > 0:
		vinc = ld
		vuoto = b["att"]
		da = b["dif"]
	if vinc < 0:
		return
	# avanzata (le unità senza rifornimento non avanzano)
	var mosse := 0
	calcola_rifornimento(vinc)
	for id in unita_in(da, vinc, true):
		if rifornita(s["unita"][id], vinc):
			s["unita"][id]["h"] = vuoto
			s["unita"][id]["mo"] = true
			mosse += int(s["unita"][id]["sp"])
	if mosse > 0:
		for id in capi_in(da, vinc):
			s["capi"][id]["h"] = vuoto
		eventi.append({"k": "mossa", "da": da, "a": vuoto, "strada": [da, vuoto]})
		_log("%s avanzano a %s." % [Dati.LATI_BREVI[vinc], Mappa.nome(vuoto)])
		s["trincee"].erase(vuoto)
		# punti vittoria: si entra in un esagono che aveva almeno 5 PF nemici
		var info: Dictionary = s["sp_inizio"].get(vuoto, {})
		if vinc == la and int(info.get("sp", 0)) >= 5 and sp_in(vuoto, ld, false, true) == 0:
			var pv := 2 if (vinc == 1 and info.get("nap", false)) else 1
			s["pv"][vinc] = int(s["pv"][vinc]) + pv
			_log("[b]%s: +%d punti vittoria[/b]" % [Dati.LATI_BREVI[vinc], pv])
			eventi.append({"k": "annuncio", "t": "Vittoria a %s: +%d PV" % [Mappa.nome(vuoto), pv]})
	_aggiorna_controllo(vuoto)

func _fine_combattimento() -> void:
	var l: int = s["lato"]
	# perdite fra i capi
	for id in s.get("coinvolti_capi", {}).keys():
		if s["capi"].has(id) and s["capi"][id]["h"] != "":
			_ferito(id)
	s["coinvolti_capi"] = {}
	# assedi del lato attivo
	calcola_rifornimento(l)
	for h in s["assedi"].keys():
		var a: Dictionary = s["assedi"][h]
		if int(a["lato"]) != l:
			continue
		var dentro := sp_in(h, 1 - l, false, true)
		if dentro == 0:
			s["assedi"].erase(h)
			_aggiorna_controllo(h)
			continue
		var fuori := 0
		for id in unita_in(h, l, true):
			if rifornita(s["unita"][id], l):
				fuori += int(s["unita"][id]["sp"])
		if fuori < dentro:
			_log("L'assedio di %s è rotto." % Mappa.nome(h))
			s["assedi"].erase(h)
			var dest := _dest_ritirata(h, l)
			for id in unita_in(h, l, true):
				if dest != "":
					s["unita"][id]["h"] = dest
			for id in capi_in(h, l):
				if dest != "":
					s["capi"][id]["h"] = dest
			for id in unita_in(h, 1 - l):
				s["unita"][id]["in"] = false
			continue
		a["l"] = mini(int(a["l"]) + 1, 5)
		var t := dado()
		eventi.append({"k": "dado", "titolo": "Assedio di %s" % Mappa.nome(h), "dadi": [t]})
		if t <= int(a["l"]):
			for id in unita_in(h, 1 - l):
				if s["unita"][id]["in"]:
					s["unita"].erase(id)
			_capi_catturati(h, 1 - l)
			s["assedi"].erase(h)
			_aggiorna_controllo(h)
			_log("[b]%s si arrende[/b] dopo %d mesi d'assedio (dado %d)." % [Mappa.nome(h), int(a["l"]), t])
			eventi.append({"k": "annuncio", "t": "%s si arrende" % Mappa.nome(h)})
		else:
			_log("Assedio di %s: livello %d, la città resiste (dado %d)." % [Mappa.nome(h), int(a["l"]), t])
	# le unità chiuse in città senza assedio tornano fuori
	for id in s["unita"]:
		var u: Dictionary = s["unita"][id]
		if u["in"] and not s["assedi"].has(u["h"]) and not nemico_in(u["h"], lato_unita(u)):
			u["in"] = false
	s["batt"] = []
	s["cb"] = {}
	_compatta()
	if _controlla_vittoria_immediata():
		return
	_fine_segmento()

# =============================================================================================
# Vittoria

func punti(lato: int) -> Dictionary:
	var ob: Dictionary = scen["obiettivi"][lato]
	var citta := 0
	var elenco := []
	for nome in ob:
		var h := Mappa.hex(nome)
		if controllore(h) == lato:
			citta += int(ob[nome])
			elenco.append(nome)
	return {"battaglie": int(s["pv"][lato]), "citta": citta, "tot": int(s["pv"][lato]) + citta, "elenco": elenco}

func _controlla_vittoria_immediata() -> bool:
	for id in s["capi"]:
		var c: Dictionary = s["capi"][id]
		if c["nome"] == "Napoleon" and c["morto"]:
			_chiudi(1, "Napoleone è morto: la Coalizione vince.")
			return true
	if scen["id"] == "1805":
		if controllore(Mappa.hex("Vienna")) == 0 and controllore(Mappa.hex("Venice")) == 0 and sp_naz("AU") < 8:
			_chiudi(0, "Vienna e Venezia sono francesi e l'esercito austriaco è distrutto: pace di Presburgo!")
			return true
	if sp_lato(0) == 0:
		_chiudi(1, "L'esercito francese è distrutto.")
		return true
	if sp_lato(1) == 0:
		_chiudi(0, "Gli eserciti alleati sono distrutti.")
		return true
	return false

func _fine_partita() -> void:
	var p0 := punti(0)
	var p1 := punti(1)
	var m := int(scen.get("margine", 3))
	if p0["tot"] >= p1["tot"] + m:
		_chiudi(0, "Francesi %d, Coalizione %d." % [p0["tot"], p1["tot"]])
	elif p1["tot"] > p0["tot"]:
		_chiudi(1, "Coalizione %d, Francesi %d." % [p1["tot"], p0["tot"]])
	else:
		_chiudi(-1, "Francesi %d, Coalizione %d: pace di compromesso." % [p0["tot"], p1["tot"]])

func _chiudi(vince: int, perche: String) -> void:
	s["fase"] = "finita"
	s["esito"] = {"vince": vince, "perche": perche}
	var t: String = "Pareggio" if vince < 0 else "Vince: " + Dati.LATI[vince]
	_log("[b]FINE: %s.[/b] %s" % [t, perche])
	eventi.append({"k": "fine", "vince": vince, "perche": perche})

# =============================================================================================
# Salvataggio

func esporta() -> Dictionary:
	return s.duplicate(true)

func importa(st: Dictionary) -> void:
	Mappa.carica()
	carica_catalogo()
	s = _normalizza(st)
	scen = Scenari.dati(s["scen"])

static func _normalizza(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _normalizza(v[k])
		return out
	if v is Array:
		var out := []
		for x in v:
			out.append(_normalizza(x))
		return out
	if v is float and v == floor(v) and absf(v) < 9.0e15:
		return int(v)
	return v
