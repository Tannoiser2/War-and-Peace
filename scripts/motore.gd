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
		"azioni": 0, "coinvolti_capi": {}, "neutrali": scen.get("neutrali", []).duplicate(),
		"alleanze_fatte": [],
		"lati_x": {}, "pool": scen.get("pool", {}).duplicate(), "fatti": {}, "riserva": [], "navi": {},
		"blocchi": {}, "all_n": {}, "flag": {}, "mare_usato": {}, "fonti_perse": [], "occ_inizio": {},
	}
	_carica_scen()
	Mappa.inverno = inverno()
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
	for g in scen.get("in_mare", []):
		_in_riserva(g)
	for fl in scen.get("flotte", []):
		_nuova_flotta(fl)
	# città controllate all'inizio (per le fonti "iniziali")
	s["iniziali"] = {}
	for h in s["controllo"]:
		s["iniziali"][h] = int(s["controllo"][h])
	# assedi e trincee iniziali
	for a in scen.get("assedi", []):
		var ha := Mappa.hex(a[0])
		for id in unita_in(ha):
			if lato_unita(s["unita"][id]) != int(a[1]):
				s["unita"][id]["in"] = true
		s["assedi"][ha] = {"l": 0, "lato": int(a[1])}
	for t in scen.get("trincee", []):
		var ht := _risolvi_hex(t[0])
		if ht != "":
			s["trincee"][ht] = int(t[1])
	for h in s["controllo"].keys():
		_aggiorna_controllo(h)
	for h in Mappa.esagoni:
		if Mappa.ha_citta(h) and sp_in(h, 0) > 0:
			s["occ_inizio"][h] = true
	_log("[b]%s[/b] — %s %d" % [scen["titolo"], Dati.MESI[s["mese"]], s["anno"]])
	_inizia_segmento()

## Lo scenario in vigore alla data corrente: le "fasi" (scenari collegati) cambiano aree, regole
## e alleanze da una certa data in poi
func _carica_scen() -> void:
	var base := Scenari.dati(str(s.get("scen", scen.get("id", ""))))
	for fa in base.get("fasi", []):
		if _data_raggiunta(str(fa["da"])):
			for k in fa:
				if k != "da":
					base[k] = fa[k]
	scen = base

func _data_raggiunta(d: String) -> bool:
	var p := d.split("-")
	var a := int(p[0])
	var me := int(p[1]) - 1
	return int(s["anno"]) * 12 + int(s["mese"]) >= a * 12 + me

## Esagono di uno schieramento: "Città", "Città+n" (un vicino a nord), "Città>" (un vicino libero)
func _risolvi_hex(nome: String) -> String:
	if nome.begins_with("#"):
		return nome.substr(1)
	if nome.begins_with("@capo:"):
		for id in s["capi"]:
			if s["capi"][id]["nome"] == nome.substr(6) and s["capi"][id]["h"] != "":
				return s["capi"][id]["h"]
		return ""
	if nome == "@nord":
		for h in Mappa.esagoni:
			if Mappa.es(h).get("nord", false) and sp_in(h, 0) == 0:
				return h
		return ""
	var base := nome.trim_suffix("+n").trim_suffix(">").trim_suffix("+e").trim_suffix("+o").trim_suffix("+s")
	var h := Mappa.hex(base)
	if h == "" or base == nome:
		return h
	var best := ""
	var bv := INF
	for v in Mappa.vicini(h):
		var n: String = v[0]
		if Mappa.ha_citta(n):
			continue
		var p := Mappa.pos(n) - Mappa.pos(h)
		var val := 0.0
		if nome.ends_with("+n"):
			val = p.y
		elif nome.ends_with("+s"):
			val = -p.y
		elif nome.ends_with("+e"):
			val = -p.x
		elif nome.ends_with("+o"):
			val = p.x
		else:
			val = float(unita_in(n).size()) * 10.0 + (0.0 if Mappa.stato(n) == Mappa.stato(h) else 5.0) + (50.0 if not aperto(n) else 0.0)
		if val < bv:
			bv = val
			best = n
	return best if best != "" else h

func _schiera(gruppo: Dictionary) -> void:
	var h := _risolvi_hex(str(gruppo["hex"]))
	if h == "":
		push_error("città sconosciuta " + str(gruppo["hex"]))
		return
	for c in gruppo["capi"]:
		var p: PackedStringArray = str(c).split(":")
		_nuovo_capo(p[0], p[1], h, p[2] if p.size() > 2 else "")
	for u in gruppo["unita"]:
		_nuova_unita(u[0], u[1], u[2], int(u[3]), h)

## nome "@0" o "@1": un capo generico ("Leader") di quel valore; sub: stato minore del capo.
## Un capo con nome già in gioco non viene duplicato (se è fuori mappa rientra nel nuovo esagono).
func _nuovo_capo(naz: String, nome: String, h: String, sub := "") -> String:
	var generico := nome.begins_with("@")
	var val := int(nome.substr(1)) if generico else -1
	if not generico:
		for id in s["capi"]:
			var c0: Dictionary = s["capi"][id]
			if c0["nome"] == nome and c0["n"] == naz:
				if c0["morto"]:
					return ""
				if c0["h"] == "" and h != "" and not c0.has("mare"):
					c0["h"] = h
					c0["fuori"] = 0
					c0.erase("ritirato")
				return id
	for giro in [0, 1, 2]:
		for c in catalogo["capi"]:
			if c["naz"] != naz:
				continue
			if giro == 0 and _capo_usato(c["img"]):
				continue
			if generico:
				if not str(c["nome"]).begins_with("Leader"):
					continue
				# poi si riusa una pedina generica già in gioco, infine anche di altro valore
				if giro < 2 and int(c["val"]) != val:
					continue
			elif giro > 0 or c["nome"] != nome:
				continue
			var id := "c%d" % s["prossimo"]
			s["prossimo"] += 1
			var sc: String = c["sub"] if c["sub"] != "I?" else ""
			if sub != "":
				sc = sub
			s["capi"][id] = {"nome": c["nome"] if not generico else "Leader", "n": naz, "s": sc,
				"v": int(c["val"]) if not generico else val,
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
	if s.get("lati_x", {}).has(naz):
		return int(s["lati_x"][naz])
	return int(scen["lati"].get(naz, -1))

## 2 = neutrale (le sue unità non muovono, non combattono e bloccano il passaggio)
func lato_unita(u: Dictionary) -> int:
	if u["s"] != "" and s.get("neutrali", []).has(u["s"]):
		return 2
	if s.get("neutrali", []).has(u["n"]) and not u["s"] in scen.get("attivi_sub", []):
		return 2
	return lato_di(u["n"])

func lato_capo(c: Dictionary) -> int:
	if c["s"] != "" and s.get("neutrali", []).has(c["s"]):
		return 2
	if s.get("neutrali", []).has(c["n"]) and not c["s"] in scen.get("attivi_sub", []):
		return 2
	return lato_di(c["n"])

func nome_lato(l: int) -> String:
	return Dati.LATI[l]

func inverno() -> bool:
	return int(s["mese"]) in Dati.INVERNO

func finita() -> bool:
	return s["fase"] == "finita"

func _aggiorna_aperti() -> void:
	s["aperti"] = s["in_guerra"].duplicate()

## Un esagono è percorribile se il suo stato è in guerra (i neutrali sono chiusi). Negli scenari
## con "chiusi_se_neutrali" tutto è aperto tranne gli stati di una nazione ancora neutrale.
func aperto(h: String) -> bool:
	if not Mappa.esiste(h):
		return false
	if scen.has("aree") and not Mappa.area(h) in scen["aree"]:
		return false
	var st := Mappa.stato(h)
	# città vietate finché una nazione non è in guerra (es. Berlino nel 1809)
	var viet: Dictionary = scen.get("vietate", {})
	if Mappa.ha_citta(h) and viet.has(Mappa.nome_citta(h)) and s["neutrali"].has(viet[Mappa.nome_citta(h)]):
		return false
	if scen.has("chiusi_se_neutrali"):
		var ch: Dictionary = scen["chiusi_se_neutrali"]
		for code in ch:
			if s["neutrali"].has(code) and st in ch[code]:
				if Mappa.area(h) == 2 and st in scen.get("aperti_area2", []):
					continue
				return false
		return true
	if st in scen.get("aperti_lato", {}).get(str(s["lato"]), []) and not s["in_guerra"].has(st):
		return true
	return st in s["aperti"]

## Si può entrare nell'esagono? Niente stati chiusi né esagoni con unità neutrali
func entrabile(h: String, porta: Dictionary = {}) -> bool:
	if sp_in(h, 2) > 0:
		return false
	# milizia e partigiani non lasciano il loro paese; i partigiani non stanno con altre unità
	var partig := false
	for id in porta:
		var u: Dictionary = s["unita"].get(id, {})
		if u.is_empty():
			continue
		if u["t"] in ["M", "P"] and Mappa.stato(h) != casa_milizia(u):
			return false
		if u["t"] == "P":
			partig = true
	if partig and (not unita_in(h).is_empty()):
		return false
	if not partig and not porta.is_empty() and _partigiani_in(h, s["lato"]):
		return false
	if aperto(h):
		return true
	# permessi speciali (es. i Polacchi possono attraversare l'Austria neutrale, ma non le sue città)
	var perm: Dictionary = scen.get("permessi", {})
	if porta.is_empty() or Mappa.ha_citta(h):
		return false
	for id in porta:
		var u: Dictionary = s["unita"].get(id, {})
		if u.is_empty() or not perm.has(u["s"]) or not Mappa.stato(h) in perm[u["s"]]:
			return false
	return true

## Il paese di milizia e partigiani (la milizia inglese rappresenta quella portoghese)
func casa_milizia(u: Dictionary) -> String:
	if u["s"] != "":
		return u["s"]
	return {"EN": "Pt", "SP": "SP", "FR": "FR", "AU": "AU", "PR": "PR", "RU": "RU"}.get(u["n"], u["n"])

func _partigiani_in(h: String, lato: int) -> bool:
	for id in unita_in(h, lato):
		if s["unita"][id]["t"] == "P":
			return true
	return false

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
		if c["h"] == h and (lato < 0 or lato_capo(c) == lato):
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
		if lato_unita(u) == lato and u["h"] != "":
			d[u["h"]] = true
	return d.keys()

func nemico_in(h: String, lato: int) -> bool:
	return sp_in(h, 1 - lato) > 0

## Il nemico è presente fuori dalla città (le unità chiuse dentro non bloccano il passaggio)
func nemico_fuori(h: String, lato: int) -> bool:
	return sp_in(h, 1 - lato, true) > 0

func max_porta(capo_id: String) -> int:
	var n: String = s["capi"][capo_id]["nome"]
	if scen.get("porta", {}).has(n):
		return int(scen["porta"][n])
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
	var prima := controllore(h)
	if a > 0 and b == 0:
		s["controllo"][h] = 0
	elif b > 0 and a == 0:
		s["controllo"][h] = 1
	# una fonte "iniziale" presa dal nemico non torna più fonte
	if prima >= 0 and controllore(h) != prima and int(s.get("iniziali", {}).get(h, -1)) == prima and not h in s["fonti_perse"]:
		s["fonti_perse"].append(h)

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

## Regole delle fonti di rifornimento della nazione: quelle dello scenario per la nazione,
## altrimenti quelle del lato, altrimenti le regole standard (città maggiori della patria)
func _spec_fonti(naz: String, lato: int) -> Dictionary:
	if scen.get("fonti_naz", {}).has(naz):
		return scen["fonti_naz"][naz]
	if scen.has("fonti"):
		return scen["fonti"].get(str(lato), {})
	return {}

## Una città (o un esagono) è libera per il rifornimento: in mano al lato, senza nemici fuori
## dalle mura e non assediata dal nemico
func _libera(h: String, lato: int) -> bool:
	if controllore(h) != lato and Mappa.ha_citta(h):
		return false
	if sp_in(h, 1 - lato, true) > 0:
		return false
	if s["assedi"].has(h) and int(s["assedi"][h]["lato"]) != lato:
		return false
	return true

func _fonti_naz(naz: String, lato: int) -> Array:
	var sp := _spec_fonti(naz, lato)
	var out := []
	if sp.is_empty() and not scen.has("fonti"):
		for h in Mappa.esagoni:
			if Mappa.ha_citta(h) and _fonte_standard(h, naz, lato):
				out.append(h)
		return out
	var citta: Array = sp.get("citta", [])
	var stati: Array = sp.get("stati", [])
	var tutte: bool = sp.get("tutte", false)
	for h in Mappa.esagoni:
		if not Mappa.ha_citta(h):
			continue
		var ok := false
		var nome := Mappa.nome_citta(h)
		if nome in citta:
			ok = true
		elif Mappa.stato(h) in stati and (tutte or Mappa.citta_maggiore(h)):
			ok = true
		elif sp.get("patria", false) and Mappa.stato(h) == naz and (tutte or Mappa.citta_maggiore(h)):
			ok = true
		elif sp.get("iniziali", false) and (tutte or Mappa.citta_maggiore(h)) and int(s.get("iniziali", {}).get(h, -1)) == lato and not h in s["fonti_perse"]:
			ok = true
		elif sp.get("porti_propri", false) and Mappa.porto(h) and _naz_dentro(h, naz):
			ok = true
		if ok and sp.get("perdute", false) and h in s["fonti_perse"]:
			ok = false
		if ok and _libera(h, lato):
			out.append(h)
	for hs in sp.get("hex", []):
		var hh := _risolvi_hex(str(hs))
		if hh != "" and _libera(hh, lato):
			out.append(hh)
	if sp.get("costa_propria", false):
		for id in s["unita"]:
			var u: Dictionary = s["unita"][id]
			if u["n"] == naz and u["h"] != "" and Mappa.costiero(u["h"]) and not (u["in"] and s["assedi"].has(u["h"])):
				out.append(u["h"])
	if sp.get("nord_siria", false):
		for h in Mappa.esagoni:
			if Mappa.es(h).get("nord", false) and sp_in(h, 1 - lato) == 0:
				out.append(h)
	if sp.get("egitto", "") != "":
		out.append_array(_fonti_egitto(str(sp["egitto"]), lato))
	return out

## Unità non assediate della nazione nell'esagono
func _naz_dentro(h: String, naz: String) -> bool:
	for id in unita_in(h):
		var u: Dictionary = s["unita"][id]
		if u["n"] == naz and not (s["assedi"].has(h) and u["in"]):
			return true
	return false

func _fonte_standard(h: String, naz: String, lato: int) -> bool:
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
	if not ok and naz == "PR" and lato_di(st) == lato and st in ["S", "He", "Br"]:
		ok = true
	if not ok:
		return false
	return sp_in(h, 1 - lato, true) == 0

## Egitto (scenario II): il Cairo per i Francesi, Cairo/Assuan/El Arish e la Siria per i Mamelucchi
func _fonti_egitto(chi: String, lato: int) -> Array:
	var out := []
	var cairo := Mappa.hex("Cairo")
	var assuan := Mappa.hex("Aswan")
	if chi == "fr":
		if _libera(cairo, lato) and controllore(cairo) == lato:
			var bona := false
			for id in s["capi"]:
				var c: Dictionary = s["capi"][id]
				if c["nome"] == "Bonaparte" and c["h"] != "" and Mappa.distanza(c["h"], cairo, 2) <= 1:
					bona = true
			if bona or controllore(assuan) == lato:
				out.append(cairo)
	else:
		for nome in ["Cairo", "Aswan", "El Arish"]:
			var h := Mappa.hex(nome)
			if sp_in(h, 1 - lato) == 0 and not (s["assedi"].has(h) and int(s["assedi"][h]["lato"]) != lato):
				out.append(h)
		if not s["neutrali"].has("TU") and in_guerra_naz("TU"):
			for h in Mappa.esagoni:
				if Mappa.ha_citta(h) and Mappa.stato(h) == "SY" and sp_in(h, 1 - lato) == 0:
					out.append(h)
		if controllore(cairo) == 1 - lato and controllore(assuan) == 1 - lato:
			out.append(Mappa.hex("Bawiti"))
	return out

func in_guerra_naz(naz: String) -> bool:
	return not s["neutrali"].has(naz)

## Esagoni del Nilo riforniti: per i Francesi se il Cairo è loro e libero, per i Mamelucchi se
## Assuan non è in mano francese
func _nilo_rifornito(naz: String, sub: String, lato: int) -> bool:
	if not scen.has("nilo"):
		return false
	var cairo := Mappa.hex("Cairo")
	var assuan := Mappa.hex("Aswan")
	if naz == "FR":
		return controllore(cairo) == lato and _libera(cairo, lato) and int(s["flag"].get("nilo_no", -1)) != int(s["turno"])
	if sub == "Mm":
		return sp_in(assuan, 1 - lato) == 0
	return false

func _rifornimento_naz(naz: String, lato: int) -> Dictionary:
	var raggiunti := {}
	var fonti := _fonti_naz(naz, lato)
	# unità della stessa nazione già rifornite diventano a loro volta fonti (catena di depositi)
	var sedi := {}
	for id in s["unita"]:
		var u: Dictionary = s["unita"][id]
		if u["n"] == naz and u["h"] != "":
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
		if h in fonti or (Mappa.ha_citta(h) and Mappa.citta_maggiore(h) and controllore(h) == lato and (Mappa.stato(h) == naz or Mappa.stato(h) in scen.get("fonti_extra", {}).get(naz, []))):
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
			if not aperto(n) or sp_in(n, 2) > 0:
				continue
			var d: int = dist[h] + Mappa.costo(h, n)
			if d <= mp and d < dist.get(n, 999):
				dist[n] = d
				out[n] = true
				coda.append(n)
	return out

func rifornita(u: Dictionary, lato: int) -> bool:
	# sbarcati dal mare in questo segmento, unità neutrali, primo turno di alcuni scenari
	if u.get("sb", false) or lato == 2:
		return true
	if int(s["turno"]) == 1 and lato in scen.get("riforniti_turno1", []):
		return true
	if u["t"] in ["P"] or (u["s"] != "" and u["s"] in scen.get("sempre_riforniti", [])):
		return true
	if u["h"] != "" and Mappa.nilo(u["h"]) and _nilo_rifornito(u["n"], u["s"], lato):
		return true
	var r: Dictionary = s["rifornimento"].get(str(lato), {})
	return r.get(u["n"], {}).has(u["h"])

# =============================================================================================
# Sequenza di gioco

func _inizia_segmento() -> void:
	_carica_scen()
	var l: int = s["lato"]
	_log("[color=#7a2a10]— %s: %s %d —[/color]" % [nome_lato(l), Dati.MESI[s["mese"]], s["anno"]])
	for id in s["unita"]:
		s["unita"][id]["mo"] = false
		s["unita"][id].erase("sb")
	for id in s["capi"]:
		s["capi"][id]["mp"] = 0
	for id in s["navi"]:
		s["navi"][id]["mp"] = 0
		s["navi"][id].erase("int")
	s["mare_usato"] = {}
	_ripara_navi(int(s["lato"]))
	Mappa.inverno = inverno()
	# Egitto: con meno di 6 PF francesi al Cairo il Nilo può restare senza rifornimento
	if scen.has("nilo") and l == 0 and int(s["turno"]) > 1:
		var cairo := Mappa.hex("Cairo")
		if sp_in(cairo, 0) < 6:
			var t := dado()
			eventi.append({"k": "dado", "titolo": "Rifornimento sul Nilo", "dadi": [t]})
			if t <= 3:
				s["flag"]["nilo_no"] = int(s["turno"])
				_log("Il Nilo non porta rifornimenti ai Francesi questo mese (dado %d)." % t)
	calcola_rifornimento(l)
	if s["turno"] > 1:
		_fase_logoramento()
		_fase_alleanze()
	_eventi_scenario()
	_fase_rinforzi()
	_punti_rimpiazzo()
	if _controlla_vittoria_immediata():
		return
	if _ha_navi(l):
		s["fase"] = "navale"
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
		var mam_soli := false
		var colpibili := []
		for id in ids:
			var u: Dictionary = s["unita"][id]
			if u["t"] == "P":
				continue
			colpibili.append(id)
			pf += int(u["sp"])
			if u["s"] == "Mm" and scen.has("mamelucchi"):
				var con_capo := false
				for c in capi_in(h, l):
					if s["capi"][c]["s"] == "Mm":
						con_capo = true
				if not con_capo:
					mam_soli = true
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
		if tutti_fr and not scen.get("francesi_ridotti", false): t -= 1
		if tutti_casa: t -= 1
		if senza: t += 1
		if inverno(): t += 1
		if Mappa.area(h) in [1, 4]: t += 1
		if mam_soli: t += 2
		t += dentro_assedio
		var p := Dati.logoramento(t, pf)
		var ast := p < 0
		p = absi(p)
		if p > 0:
			_elimina_sp(colpibili, p, ast, "")
			perdite_tot += p
			righe.append("%s %d" % [Mappa.nome(h), p])
	if perdite_tot > 0:
		_log("Logoramento (dado %d): perdite %s" % [tiro, ", ".join(righe)])
	else:
		_log("Logoramento (dado %d): nessuna perdita" % tiro)
	if tiro == 6:
		_logoramento_navale(l)
	_compatta()

func _a_casa(u: Dictionary, h: String) -> bool:
	var st := Mappa.stato(h)
	if u["s"] != "" and u["s"] != "K":
		return st == u["s"]
	return st == u["n"]

func _fase_alleanze() -> void:
	if scen.has("alleanze_1813"):
		_alleanze_1813()
		return
	if scen.has("alleanze"):
		_alleanze_generiche()
		return
	if scen.has("marcatore_alleanza"):
		_alleanza_marcatore()
		return
	_alleanza_semplice()

func _alleanza_semplice() -> void:
	var al: Dictionary = scen.get("alleanza", {})
	if al.is_empty() or s["alleanza"] != "":
		return
	var l: int = s["lato"]
	var tiro := dado()
	var mod := clampi(punti(1)["tot"] - punti(0)["tot"], -4, 4)
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
		for code in al.get("codici", []):
			s["neutrali"].erase(code)
		for g in al.get("schieramento", []):
			_schiera(g)
		_log("[b]Alleanze[/b] (dado %d, modificato %d): la %s entra in guerra con la Coalizione!" % [tiro, t, naz])
		eventi.append({"k": "annuncio", "t": "La %s entra in guerra!" % naz})
	elif l != int(al["lato"]) and t <= 0:
		s["alleanza"] = "no"
		_log("[b]Alleanze[/b] (dado %d, modificato %d): la %s resterà neutrale." % [tiro, t, naz])
		eventi.append({"k": "annuncio", "t": "La %s resterà neutrale" % naz})
	else:
		_log("Alleanze (dado %d, modificato %d): nessun effetto." % [tiro, t])

## Fase delle alleanze degli scenari: chi tira, da quando, modificatori di mese e punti;
## con 0 o con 7 (e con il secondo 0 o 7) si applicano gli effetti dello scenario
func _alleanze_generiche() -> void:
	var al: Dictionary = scen["alleanze"]
	if s["alleanza"] == "finita":
		return
	var l: int = s["lato"]
	if int(s["turno"]) < int(al.get("da", 2)):
		return
	if not l in al.get("chi", [0, 1]):
		return
	if al.has("se") and not _condizione(al["se"]):
		return
	var tiro := dado()
	var mod := clampi(punti(1)["tot"] - punti(0)["tot"], -4, 4)
	mod += int(al.get("mesi", {}).get(str(s["mese"]), 0))
	var t := tiro + mod
	eventi.append({"k": "dado", "titolo": "Alleanze", "dadi": [tiro]})
	var r := ""
	if t <= 0:
		r = "0"
	elif t >= 7:
		r = "7"
	if r == "":
		_log("Alleanze (dado %d, modificato %d): nessun effetto." % [tiro, t])
		return
	var n := int(s["all_n"].get(r, 0))
	s["all_n"][r] = n + 1
	var k := r if n == 0 else r + "b"
	var es: Array = al.get("esiti", {}).get(k, [])
	if es.is_empty() and n > 0:
		es = al.get("esiti", {}).get(r + "+", [])
	_log("[b]Alleanze[/b] (dado %d, modificato %d)." % [tiro, t])
	_effetti(es)
	if k in al.get("fine", ["0", "7"]):
		s["alleanza"] = "finita"

## Egitto: un segnalino d'assedio in Siria sale ogni mese; con un dado non superiore la Turchia
## entra in guerra (a novembre in ogni caso)
func _alleanza_marcatore() -> void:
	var al: Dictionary = scen["marcatore_alleanza"]
	if s["alleanza"] == "finita" or int(s["lato"]) != int(al.get("lato", 1)):
		return
	if int(s["turno"]) < int(al["da"]):
		return
	var liv := int(al["inizio"]) + int(s["turno"]) - int(al["da"])
	var t := dado()
	eventi.append({"k": "dado", "titolo": "La Turchia (segnalino %d)" % liv, "dadi": [t]})
	if t <= liv or int(s["turno"]) >= int(al["forza"]):
		s["alleanza"] = "finita"
		_log("[b]Alleanze[/b]: la Turchia dichiara guerra alla Francia (dado %d, segnalino %d)." % [t, liv])
		_effetti(al["effetti"])
	else:
		_log("Alleanze: la Turchia resta neutrale (dado %d, segnalino %d)." % [t, liv])

## Eventi dello scenario controllati a ogni segmento: condizione e effetti (una volta sola)
func _eventi_scenario() -> void:
	var lista: Array = scen.get("eventi", [])
	for i in lista.size():
		var ev: Dictionary = lista[i]
		var k := "ev_%s" % str(ev.get("id", i))
		if s["fatti"].has(k) and not ev.get("ripeti", false):
			continue
		if ev.has("lato") and int(ev["lato"]) != int(s["lato"]):
			continue
		if ev.has("da") and int(s["turno"]) < int(ev["da"]):
			continue
		if not _condizione(ev.get("se", {})):
			continue
		s["fatti"][k] = true
		_effetti(ev.get("effetti", []))

## Applica una lista di effetti (alleanze ed eventi)
func _effetti(lista: Array) -> void:
	for e in lista:
		if e.has("se") and not _condizione(e["se"]):
			continue
		match str(e.get("e", "")):
			"guerra":
				for st in e["stati"]:
					if not st in s["in_guerra"]:
						s["in_guerra"].append(st)
				_aggiorna_aperti()
				var lg := int(e.get("lato", 1))
				for h in Mappa.esagoni:
					if Mappa.ha_citta(h) and Mappa.stato(h) in e["stati"] and sp_in(h, 1 - lg) == 0:
						s["controllo"][h] = lg
			"pace":
				for st in e["stati"]:
					s["in_guerra"].erase(st)
				_aggiorna_aperti()
			"attiva":
				for code in e["codici"]:
					s["neutrali"].erase(code)
			"neutrale":
				for code in e["codici"]:
					if not code in s["neutrali"]:
						s["neutrali"].append(code)
			"lato":
				s["lati_x"][str(e["naz"])] = int(e["lato"])
			"schiera":
				for g in e["gruppi"]:
					_schiera(g)
			"elimina":
				for id in s["unita"].keys():
					var u: Dictionary = s["unita"][id]
					var via: bool = u["n"] in e.get("naz", []) or (u["s"] != "" and u["s"] in e.get("sub", []))
					for cp in e.get("coppie", []):
						if u["n"] == cp[0] and u["s"] == cp[1]:
							via = true
					if via:
						s["unita"].erase(id)
				for id in s["capi"]:
					var c: Dictionary = s["capi"][id]
					if (c["n"] in e.get("naz", []) and c["s"] == "") or (c["s"] != "" and c["s"] in e.get("sub", [])):
						c["h"] = ""
						c["morto"] = true
			"defezione":
				_defezione({"defezione": e["mappa"]})
			"perdi":
				for sub in e["sub"]:
					for id in s["unita"].keys():
						var u: Dictionary = s["unita"][id]
						if u["s"] == sub and u["n"] == "FR":
							u["sp"] = int(u["sp"]) - int(e.get("n", 1))
							if int(u["sp"]) <= 0:
								s["unita"].erase(id)
							break
			"rimuovi_capo":
				for id in s["capi"]:
					if s["capi"][id]["nome"] in e["nomi"]:
						s["capi"][id]["h"] = ""
						s["capi"][id]["fuori"] = 0
						s["capi"][id]["ritirato"] = true
			"vittoria":
				_chiudi(int(e["lato"]), str(e.get("perche", "")))
				return
			"flag":
				s["flag"][str(e["k"])] = e.get("v", true)
			"rinforzi":
				for g in e["gruppi"]:
					_arrivo(g, int(s["lato"]))
			"partigiani":
				_nuovi_partigiani(str(e["naz"]), str(e["stato"]), int(e["n"]))
		if e.has("t"):
			_log("[b]%s[/b]" % str(e["t"]))
			eventi.append({"k": "annuncio", "t": str(e["t"])})

## Condizioni usate da eventi, rinforzi e vittoria
func _condizione(c: Dictionary) -> bool:
	if c.is_empty():
		return true
	var l := int(c.get("lato", 0))
	match str(c.get("t", "")):
		"e":
			for x in c["tests"]:
				if not _condizione(x):
					return false
			return true
		"o":
			for x in c["tests"]:
				if _condizione(x):
					return true
			return false
		"non":
			return not _condizione(c["test"])
		"controlla", "occupa":
			var n := 0
			var lista: Array = _citta_cond(c)
			for h in lista:
				if c.has("naz"):
					for id in unita_in(h, l):
						if s["unita"][id]["n"] == c["naz"] and s["unita"][id]["s"] == str(c.get("sub", "")):
							n += 1
							break
				elif _tiene(h, l, str(c["t"]) == "occupa", c.get("libere", false), c.get("rif", false)):
					n += 1
			return n >= int(c.get("min", lista.size())) and (n > 0 or lista.is_empty())
		"nessuna_area":
			for h in Mappa.esagoni:
				if Mappa.ha_citta(h) and Mappa.area(h) == int(c["area"]) and _tiene(h, l, true, true, false):
					return false
			return true
		"maggiore_area":
			for h in Mappa.esagoni:
				if Mappa.citta_maggiore(h) and Mappa.area(h) == int(c["area"]) and controllore(h) == l and not s["assedi"].has(h):
					return true
			return false
		"entra_stato":
			# un'unità del lato è in uno degli stati
			for id in s["unita"]:
				var u: Dictionary = s["unita"][id]
				if lato_unita(u) == l and u["h"] != "" and Mappa.stato(u["h"]) in c["stati"]:
					return true
			return false
		"neutrale":
			return s["neutrali"].has(str(c["naz"]))
		"in_guerra":
			return not s["neutrali"].has(str(c["naz"])) and (lato_di(str(c["naz"])) >= 0)
		"flag":
			return s["flag"].has(str(c["k"]))
		"turno":
			return int(s["turno"]) >= int(c["da"])
		"mosso":
			# unità schierate all'inizio vicino a una città che si sono mosse (es. Praga 1796)
			return s["flag"].has("mosso_" + str(c["citta"]))
	return false

func _citta_cond(c: Dictionary) -> Array:
	var out := []
	for nome in c.get("citta", []):
		var h := Mappa.hex(nome)
		if h != "":
			out.append(h)
	if c.has("stati") or c.has("area"):
		for h in Mappa.esagoni:
			if not Mappa.ha_citta(h):
				continue
			if c.has("stati") and not Mappa.stato(h) in c["stati"]:
				continue
			if c.has("area") and Mappa.area(h) != int(c["area"]):
				continue
			if c.get("maggiori", false) and not Mappa.citta_maggiore(h):
				continue
			if Mappa.nome_citta(h) in c.get("eccetto", []):
				continue
			out.append(h)
	return out

## Il lato tiene la città: controllo (o almeno un punto forza dentro), non assediato, rifornito
func _tiene(h: String, l: int, occupa: bool, libere: bool, rif: bool) -> bool:
	if occupa:
		var n := 0
		for id in unita_in(h, l):
			var u: Dictionary = s["unita"][id]
			if libere and u["in"] and s["assedi"].has(h):
				continue
			if rif and not rifornita(u, l):
				continue
			n += int(u["sp"])
		return n > 0
	if controllore(h) != l:
		return false
	if libere and s["assedi"].has(h):
		return false
	if rif:
		for id in unita_in(h, l):
			if rifornita(s["unita"][id], l):
				return true
		return sp_in(h, l) == 0
	return true

## Rinforzi e rimpiazzi del segmento
func _fase_rinforzi() -> void:
	var l: int = s["lato"]
	var lista: Array = scen.get("rinforzi", {}).get(str(s["turno"]), []).duplicate()
	for g in scen.get("ogni_turno", []):
		if int(s["turno"]) >= int(g.get("da", 1)) and int(s["turno"]) <= int(g.get("a", 999)):
			lista.append(g)
	for g in lista:
		if _lato_gruppo(g) != l:
			continue
		_arrivo(g, l)
	# partigiani eliminati che tornano
	var pg: Dictionary = scen.get("ogni_turno_partigiani", {})
	if not pg.is_empty() and s["flag"].has("partigiani") and lato_di(str(pg["naz"])) == l:
		var k := "%s||P" % pg["naz"]
		var n := int(s["pool"].get(k, 0))
		if n > 0:
			s["pool"][k] = 0
			_nuovi_partigiani(str(pg["naz"]), str(pg["stato"]), n)
	# capi feriti che tornano
	for id in s["capi"]:
		var c: Dictionary = s["capi"][id]
		if c["h"] == "" and not c["morto"] and not c.has("mare") and not c.get("ritirato", false) and not c.get("nave", false) and lato_capo(c) == l and int(c["fuori"]) > 0 and int(c["fuori"]) <= int(s["turno"]):
			var dove := _hex_amico_per_capo(c["n"], l)
			if dove != "":
				c["h"] = dove
				c["fuori"] = 0
				_log("%s rientra in servizio a %s." % [c["nome"], Mappa.nome(dove)])

func _lato_gruppo(g: Dictionary) -> int:
	if g.has("lato"):
		return int(g["lato"])
	var naz := ""
	if not g.get("unita", []).is_empty():
		naz = g["unita"][0][0]
	elif not g.get("capi", []).is_empty():
		naz = str(g["capi"][0]).split(":")[0]
	elif not g.get("flotta", []).is_empty():
		naz = g["flotta"][0][0]
	elif g.has("ritira"):
		naz = "FR"
	if s["neutrali"].has(naz) and not g.get("anche_neutrali", false):
		return -1
	return lato_di(naz)

## Arrivo di un gruppo di rinforzi: dove (città o alternative), se le condizioni sono rispettate,
## i rimpiazzi solo fino ai punti forza persi, i ritiri dello scenario
func _arrivo(g: Dictionary, l: int) -> void:
	if g.has("se") and not _condizione(g["se"]):
		return
	if g.get("una_volta", false):
		var k := "rf_%s_%d" % [str(g.get("hex", "")), hash(str(g))]
		if s["fatti"].has(k):
			return
		s["fatti"][k] = true
	if g.has("ritira"):
		_ritira(g["ritira"])
		return
	if g.has("flotta_mare"):
		for x in g["navi"]:
			for i in int(x[3]):
				_nuova_nave(x[0], x[1], x[2], 1, "", str(g["flotta_mare"]))
		_log("Nuove navi in %s." % Dati.ZONE[str(g["flotta_mare"])]["nome"])
		return
	var unita: Array = g.get("unita", []).duplicate(true)
	if g.get("rimpiazzo", false):
		var resto := []
		for u in unita:
			var k := "%s|%s|%s" % [u[0], u[1], u[2]]
			var sub: String = u[1]
			if sub == "*":
				# un satellite qualsiasi della riserva (non i Polacchi, che hanno il loro deposito)
				k = ""
				for kk in s["pool"]:
					var pp: PackedStringArray = str(kk).split("|")
					if pp[0] == u[0] and pp[1] != "" and pp[1] != "Po" and pp[2] == u[2] and int(s["pool"][kk]) > 0:
						k = kk
						sub = pp[1]
						break
				if k == "":
					continue
			var n := mini(int(u[3]), int(s["pool"].get(k, 0)))
			if n > 0:
				s["pool"][k] = int(s["pool"][k]) - n
				resto.append([u[0], sub, u[2], n])
		unita = resto
		if unita.is_empty():
			return
	var gg := g.duplicate()
	gg["unita"] = unita
	if g.has("mare"):
		gg["zona"] = g["mare"]
		_in_riserva(gg)
		_log("Rinforzi in mare (%s)." % Dati.ZONE.get(str(g["mare"]), {}).get("nome", str(g["mare"])))
		return
	var h := ""
	var regola := str(g.get("regola", scen.get("rinforzi_regola", "persi" if scen.get("rinforzi_persi", false) else "vicina")))
	var candidati: Array = [str(g.get("hex", ""))]
	candidati.append_array(g.get("alt", []))
	for nome in candidati:
		if nome == "":
			continue
		var hh := _risolvi_hex(nome)
		if hh != "" and not nemico_fuori(hh, l) and (controllore(hh) == l or not Mappa.ha_citta(hh) or controllore(hh) < 0):
			h = hh
			break
	if h == "":
		var h0 := _risolvi_hex(candidati[0]) if candidati[0] != "" else ""
		match regola:
			"persi":
				_log("Rinforzi perduti: %s è in mano nemica." % Mappa.nome(h0))
				return
			"adiacente":
				for v in Mappa.vicini(h0):
					if not nemico_in(v[0], l) and aperto(v[0]):
						h = v[0]
						break
			"patria":
				h = _citta_amica_vicina(h0, l, _naz_gruppo_r(g))
			_:
				h = _citta_amica_vicina(h0, l)
		if h == "":
			return
	if g.has("flotta"):
		for fl in g["flotta"]:
			_nuova_nave(fl[0], fl[1], fl[2], int(fl[3]), h, "")
	_schiera_in(gg, h)
	_log("Rinforzi a %s." % Mappa.nome(h))

func _naz_gruppo_r(g: Dictionary) -> String:
	if not g.get("unita", []).is_empty():
		return g["unita"][0][0]
	return ""

## Ritiri richiesti dallo scenario: capi nominati e punti forza di un tipo (dai meno impegnati)
func _ritira(r: Dictionary) -> void:
	for x in r.get("navi", []):
		var n := int(x[3])
		for id in s["navi"].keys():
			if n > 0 and s["navi"][id]["n"] == x[0] and s["navi"][id]["t"] == x[2]:
				s["navi"].erase(id)
				n -= 1
	for nome in r.get("capi", []):
		for id in s["capi"]:
			var c: Dictionary = s["capi"][id]
			if c["nome"] == nome and not c["morto"]:
				c["h"] = ""
				c["fuori"] = 0
				c["ritirato"] = true
		_log("%s lascia il teatro di guerra." % nome)
	for u in r.get("unita", []):
		var n := int(u[3])
		var ids := []
		for id in s["unita"]:
			var x: Dictionary = s["unita"][id]
			var sub_ok: bool = u[1] == "*" or x["s"] == u[1] or (u[1] == "sat" and x["s"] != "" and x["s"] != "K")
			if x["n"] == u[0] and sub_ok and (u[2] == "*" or x["t"] == u[2]) and not (x["in"] and s["assedi"].has(x["h"])):
				ids.append(id)
		# prima le unità lontane dal nemico
		ids.sort_custom(func(a, b): return _vicino_nemico(s["unita"][a]["h"]) < _vicino_nemico(s["unita"][b]["h"]))
		for id in ids:
			if n <= 0:
				break
			var x: Dictionary = s["unita"][id]
			var k := mini(n, int(x["sp"]))
			x["sp"] = int(x["sp"]) - k
			n -= k
			if int(x["sp"]) <= 0:
				s["unita"].erase(id)
		if int(u[3]) - n > 0:
			_log("Ritirati %d PF (%s)." % [int(u[3]) - n, Dati.TIPI.get(u[2], {}).get("nome", u[2])])

func _vicino_nemico(h: String) -> int:
	var l := lato_unita(s["unita"][unita_in(h)[0]]) if not unita_in(h).is_empty() else 0
	var best := 99
	for h2 in esagoni_di(1 - l):
		best = mini(best, Mappa.distanza(h, h2, 6))
	return best

func _schiera_in(g: Dictionary, h: String) -> void:
	for c in g.get("capi", []):
		var p: PackedStringArray = str(c).split(":")
		_nuovo_capo(p[0], p[1], h, p[2] if p.size() > 2 else "")
	for u in g.get("unita", []):
		_nuova_unita(u[0], u[1], u[2], int(u[3]), h)

func _citta_amica_vicina(h0: String, l: int, naz := "") -> String:
	var best := ""
	var bd := INF
	for h in Mappa.esagoni:
		if Mappa.citta_maggiore(h) and controllore(h) == l and not nemico_fuori(h, l) and aperto(h):
			if naz != "" and Mappa.stato(h) != naz:
				continue
			var d := Mappa.pos(h).distance_to(Mappa.pos(h0))
			if d < bd:
				bd = d
				best = h
	return best

func _hex_amico_per_capo(naz: String, l: int) -> String:
	var r: Dictionary = s["rifornimento"].get(str(l), {}).get(naz, {})
	for id in s["unita"]:
		var u: Dictionary = s["unita"][id]
		if u["n"] == naz and u["h"] != "" and r.has(u["h"]):
			return u["h"]
	for id in s["unita"]:
		if s["unita"][id]["n"] == naz and s["unita"][id]["h"] != "":
			return s["unita"][id]["h"]
	return ""

func _fine_segmento() -> void:
	_compatta()
	for h in s["controllo"].keys():
		_aggiorna_controllo(h)
	_sbarca_obbligatorio()
	if _vittoria_cond("subito"):
		return
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
		"navale":
			return {"k": "navale", "lato": s["lato"]}
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
			if rq["k"] == "navale":
				_fine_navale()
				ok = true
			elif rq["k"] == "movimento":
				_fine_movimento()
				ok = true
			elif rq["k"] == "dichiara":
				_inizia_battaglie()
				ok = true
		"attacco":
			ok = rq["k"] == "dichiara" and _dichiara(str(d.get("da", "")), str(d.get("su", "")))
		"mare":
			ok = rq["k"] == "movimento" and _mare(d)
		"sbarca":
			ok = rq["k"] == "movimento" and _sbarca(str(d.get("r", "")), str(d.get("verso", "")))
		"naviga":
			ok = rq["k"] == "navale" and _naviga(d)
		"annulla":
			ok = rq["k"] == "dichiara" and _annulla(str(d.get("su", "")))
		"scelta":
			ok = rq["k"] in ["citta", "assalto", "continua", "resta", "contro"] and _scelta(rq, str(d.get("v", "")))
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
		if lato_capo(c) != l or c["h"] == "" or c.get("nave", false):
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
		if u["t"] == "P":
			if capo != "":
				return {"ok": false, "errore": "i partigiani si muovono da soli"}
			out["partigiani"] = true
			continue
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
	elif int(s["turno"]) == 1 and l == 0 and scen.get("solo_capi_turno1", false):
		return {"ok": false, "errore": "al primo turno si muovono solo i capi"}
	elif int(s["turno"]) == 1 and l == 0 and scen.get("solo_fm_turno1", false):
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
	if g.get("partigiani", false):
		var vic := {}
		for v in Mappa.vicini(da):
			if entrabile(v[0], porta) and not nemico_in(v[0], l):
				vic[v[0]] = {"mp": 1, "fm": 0, "via": da}
		return vic
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
			if not entrabile(n, porta):
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
	if scen.get("no_travolgimento", false) or _partigiani_in(h, 1 - l):
		return -1
	var cav_dif := 0
	for id in unita_in(h, 1 - l, true):
		if Dati.e_cavalleria(s["unita"][id]["t"]):
			cav_dif += int(s["unita"][id]["sp"])
	if cav_dif > 0 and cav < cav_dif:
		return -1
	var minimo := 4
	if Mappa.terreno(h).begins_with("montagna") or s["trincee"].has(h):
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
		elif tutti_fr and not scen.get("francesi_ridotti", false): t -= 1
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
	# fanteria lasciata lungo la strada (regola J6e: depositi per il rifornimento)
	var lascia: Dictionary = d.get("lascia", {})
	var lasciati := 0
	for h in strada:
		if not lascia.has(h) or nemico_in(h, l):
			if h == arrivo:
				break
			continue
		var n := int(lascia[h])
		for id in mobili.duplicate():
			if n <= 0 or not s["unita"].has(id):
				continue
			var u: Dictionary = s["unita"][id]
			if Dati.e_cavalleria(u["t"]) or u["t"] in ["GI", "GC"]:
				continue
			var k := mini(n, int(u["sp"]))
			var nid: String = _separa(id, k) if k < int(u["sp"]) else id
			s["unita"][nid]["h"] = h
			s["unita"][nid]["mo"] = true
			s["unita"][nid]["in"] = false
			if nid == id:
				mobili.erase(id)
			n -= k
			lasciati += k
		_aggiorna_controllo(h)
		if h == arrivo:
			break
	if lasciati > 0:
		nota += " (%d PF lasciati di presidio lungo la strada)" % lasciati
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
	var vio: Dictionary = scen.get("violazione", {})
	if not vio.is_empty() and l == int(vio["lato"]) and not s.get("violato", false):
		for h in strada:
			if Mappa.stato(h) in vio["stati"] and not s["in_guerra"].has(Mappa.stato(h)):
				s["violato"] = true
				_log("[b]Le truppe francesi violano il territorio prussiano[/b]: +1 punto città alla Coalizione.")
				break
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
				# Gibilterra non si attacca finché c'è fanteria inglese dentro
				if scen.get("gibilterra", false) and Mappa.nome_citta(n) == "Gibraltar" and _naz_dentro(n, "EN"):
					continue
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
		"contro":
			return {"k": "contro", "lato": b["ld"], "b": cb["i"], "opzioni": ["contrattacca", "lascia"]}
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
				_log("Battaglia di %s interrotta." % Mappa.nome(b["dif"]))
				# in battaglia campale chi era attaccato può contrattaccare (regola N5)
				if b["tipo"] == "campo" and _battaglia_viva(b) and _sp_battaglia(b, int(b["ld"])) > 0 and _morale_lato(b, int(b["ld"])) > 0:
					cb["passo"] = "contro"
				else:
					b["fine"] = true
					cb["passo"] = "prossima"
			else:
				cb["passo"] = "resta" if b["tipo"] == "campo" else "rinforzi"
		"contro":
			if v == "lascia":
				b["fine"] = true
				cb["passo"] = "prossima"
			else:
				_scambia_ruoli(b)
				_log("[b]Contrattacco[/b] a %s: %s attaccano." % [Mappa.nome(b["dif"]), Dati.LATI_BREVI[int(b["la"])]])
				eventi.append({"k": "annuncio", "t": "Contrattacco a %s" % Mappa.nome(b["dif"])})
				cb["passo"] = "rinforzi"
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
				if int(cb["r"]) == 1 and not b["pre"] and _partigiani_evitano(b):
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

## Il contrattacco: attaccante e difensore si scambiano i ruoli (esagoni, forze impegnate, morale)
func _scambia_ruoli(b: Dictionary) -> void:
	var t: Variant = b["att"]
	b["att"] = b["dif"]
	b["dif"] = t
	t = b["la"]
	b["la"] = b["ld"]
	b["ld"] = t
	t = b["ha"]
	b["ha"] = b["hd"]
	b["hd"] = t
	b["dem"] = [b["dem"][1], b["dem"][0]]
	b["contro"] = int(b.get("contro", 0)) + 1

static func LATI_FORZE(l: int) -> String:
	return "le forze francesi" if l == 0 else "le forze alleate"

## I partigiani attaccati possono evitare il combattimento: in terreno non aperto sempre, in
## terreno aperto solo se il nemico non ha cavalleria (si spostano in un esagono vicino vuoto)
func _partigiani_evitano(b: Dictionary) -> bool:
	var ld := int(b["ld"])
	var ids := unita_in(b["dif"], ld, true)
	if ids.is_empty():
		return false
	for id in ids:
		if s["unita"][id]["t"] != "P":
			return false
	var cav := 0
	for id in unita_in(b["att"], int(b["la"]), true):
		if Dati.e_cavalleria(s["unita"][id]["t"]):
			cav += 1
	var terr := Mappa.terreno(b["dif"])
	if (terr == "pianura" and not Mappa.ha_citta(b["dif"])) and cav > 0:
		return false
	for v in Mappa.vicini(b["dif"]):
		var n: String = v[0]
		if unita_in(n).is_empty() and aperto(n) and Mappa.stato(n) == casa_milizia(s["unita"][ids[0]]):
			for id in ids:
				s["unita"][id]["h"] = n
			_log("I partigiani di %s evitano lo scontro e si spostano a %s." % [Mappa.nome(b["dif"]), Mappa.nome(n)])
			return true
	return false

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
	var capi_nomi := []
	for h in (b["ha"] if lato == int(b["la"]) else b["hd"]):
		for c in capi_in(h, lato):
			capi_nomi.append(s["capi"][c]["nome"])
	for id in _impegnate(b, lato):
		var u: Dictionary = s["unita"][id]
		var m := morale_unita(u, capi_nomi)
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

## Morale di un'unità con le regole dello scenario (morale ridotto, patriottismo russo, capi che
## danno morale ai Francesi come Bonaparte in Italia e in Egitto)
func morale_unita(u: Dictionary, capi_nomi: Array = []) -> int:
	var m := Dati.morale(u["n"], u["s"], u["t"])
	var regolare: bool = u["t"] in ["I", "C"] and (u["s"] == "" or u["s"] == "K")
	for r in scen.get("morale", []):
		if u["n"] != r["naz"] or not u["t"] in r.get("tipi", ["I", "C"]):
			continue
		if r.get("regolari", true) and not regolare:
			continue
		if r.has("area") and (u["h"] == "" or Mappa.area(u["h"]) != int(r["area"])):
			continue
		m = int(r["val"])
	var mc: Dictionary = scen.get("morale_capo", {})
	if not mc.is_empty() and u["n"] == mc["naz"] and regolare:
		var con := false
		for n in capi_nomi:
			if n in mc["capi"]:
				con = true
		m = int(mc["con"]) if con else int(mc["senza"])
	if s["flag"].has("morale_fr_1") and u["n"] == "FR" and regolare:
		m = 1
	return m

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
	if rap == "4:1" and scen.get("no_4a1", false) and fp > 0:
		rap = "2:1"
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
		var terr := Mappa.terreno(b["dif"])
		if inverno() and terr == "palude":
			terr = "pianura"
		var t: int = Dati.MOD_TERRENO.get(terr, 0)
		if Mappa.fiume_tra(b["att"], b["dif"]):
			t += Dati.MOD_FIUME
		if s["trincee"].has(b["dif"]) and int(s["trincee"][b["dif"]]) == ld:
			t += 1
		# il terreno favorisce chi viene attaccato
		tm = t if ld == grande else -t
		if tm != 0:
			mods.append(["Terreno", tm])
		mod += tm
	if b["tipo"] == "assalto" and scen.get("assalto_egitto", false):
		var am := -1 if piccola == ld else 1
		mods.append(["Fortezza", am])
		mod += am
	mod = clampi(mod, -4, 4)
	var d1 := dado()
	var d2 := dado()
	var tiro := clampi(d1 + d2 + mod, 2, 12)
	var rg := "0"
	var rp := "0"
	if rap == "4:1":
		rp = "D3"
	else:
		var r: Array = Dati.crt(rap, tiro)
		rg = r[0]
		rp = r[1]
	var piccola_sp := _sp_battaglia(b, piccola)
	var pp := Dati.perdita(rp, piccola_sp)
	if rap == "4:1":
		rg = "1" if pp > 1 else "0"
	var pg := Dati.perdita(rg, piccola_sp)
	# Egitto: i Francesi possono evitare una perdita con un dado più il valore del capo
	if scen.get("perdite_fr_dado", false):
		for lx in [grande, piccola]:
			var p := pg if lx == grande else pp
			var cx := cg if lx == grande else cp
			if p > 0 and _naz_battaglia(b, lx) == "FR":
				var td := dado() + (int(s["capi"][cx]["v"]) if cx != "" else 0)
				if td >= 5:
					if lx == grande: pg -= 1
					else: pp -= 1
					_log("Fortuna francese (dado %d): una perdita in meno." % td)
	if scen.get("demoralizzazione_napoleone", false):
		for lx in [grande, piccola]:
			var rr := rg if lx == grande else rp
			if rr.begins_with("D") and _naz_battaglia(b, lx) == "FR":
				for h in (b["ha"] if lx == la else b["hd"]):
					for c in capi_in(h, lx):
						if s["capi"][c]["nome"] == "Napoleon" and not s["flag"].has("morale_fr_1"):
							s["flag"]["morale_fr_1"] = true
							_log("[b]La Guardia è respinta: il morale francese crolla[/b] (morale 1 per il resto della partita).")
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

func _naz_battaglia(b: Dictionary, lato: int) -> String:
	var conta := {}
	for id in _impegnate(b, lato):
		var u: Dictionary = s["unita"][id]
		conta[u["n"]] = int(conta.get(u["n"], 0)) + int(u["sp"])
	var best := ""
	for n in conta:
		if best == "" or conta[n] > conta[best]:
			best = n
	return best

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
				_al_pool(s["unita"][id], 1)
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
			_al_pool(s["unita"][id], 1)
			resto -= 1
	for id in ids:
		if s["unita"].has(id) and int(s["unita"][id]["sp"]) <= 0:
			s["unita"].erase(id)

## Punti forza eliminati: vanno nella riserva della nazione (per i rimpiazzi)
func _al_pool(u: Dictionary, n: int) -> void:
	var k := "%s|%s|%s" % [u["n"], u["s"], u["t"]]
	s["pool"][k] = int(s["pool"].get(k, 0)) + n

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
	_navi_porti_caduti()
	if _controlla_vittoria_immediata():
		return
	_fine_segmento()

# =============================================================================================
# Vittoria

func punti(lato: int) -> Dictionary:
	var ob: Dictionary = scen.get("punti_citta", scen["obiettivi"])[lato]
	var citta := 0
	var elenco := []
	for nome in ob:
		var h := Mappa.hex(nome)
		if controllore(h) == lato:
			citta += int(ob[nome])
			elenco.append(nome)
	if lato == 1 and s.get("violato", false):
		citta += 1
		elenco.append("territorio prussiano violato")
	for rg in scen.get("punti_regole", []):
		if int(rg["lato"]) != lato:
			continue
		for h in Mappa.esagoni:
			if not Mappa.ha_citta(h) or controllore(h) != lato or (rg.get("maggiori", true) and not Mappa.citta_maggiore(h)):
				continue
			if rg.has("aree") and not Mappa.area(h) in rg["aree"]:
				continue
			if rg.has("stati") and not Mappa.stato(h) in rg["stati"]:
				continue
			if rg.get("satelliti", false) and (Dati.NAZ.has(Mappa.stato(h)) or lato_di(Mappa.stato(h)) != 1 - lato):
				continue
			if Mappa.nome_citta(h) in elenco:
				continue
			citta += 1
			elenco.append(Mappa.nome_citta(h))
	if lato == 1 and scen.get("punti_area2_coalizione", false):
		for h in s["controllo"]:
			if Mappa.area(h) == 2 and controllore(h) == 1 and not elenco.has(Mappa.nome_citta(h)):
				citta += 1
				elenco.append(Mappa.nome_citta(h))
	return {"battaglie": int(s["pv"][lato]), "citta": citta, "tot": int(s["pv"][lato]) + citta, "elenco": elenco}

## Fase delle alleanze dello scenario 1813 (Struggle of Nations)
func _alleanze_1813() -> void:
	var l: int = s["lato"]
	var al: Dictionary = scen["alleanze_1813"]
	var mod_mese: int = int(al["mesi"].get(str(s["mese"]), 0))
	var diff := clampi(punti(1)["tot"] - punti(0)["tot"], -4, 4)
	var mod := mod_mese + diff
	if s["alleanze_fatte"].has("defezione"):
		return
	# i Francesi tirano solo se possono ottenere lo 0 (i satelliti neutrali diventano attivi)
	if l == 0 and (mod >= 0 or s["alleanze_fatte"].has("satelliti")):
		return
	var tiro := dado()
	var t := tiro + mod
	eventi.append({"k": "dado", "titolo": "Alleanze", "dadi": [tiro]})
	if t <= 0 and not s["alleanze_fatte"].has("satelliti"):
		s["alleanze_fatte"].append("satelliti")
		for code in al["satelliti"]:
			s["neutrali"].erase(code)
		_log("[b]Alleanze[/b] (dado %d, modificato %d): Baviera, Napoli, Sassonia e Svizzera combattono con la Francia." % [tiro, t])
		eventi.append({"k": "annuncio", "t": "I satelliti neutrali si schierano con la Francia"})
	elif t >= 7 and not s["alleanze_fatte"].has("austria"):
		s["alleanze_fatte"].append("austria")
		for code in al["entrano"]:
			s["neutrali"].erase(code)
		for h in Mappa.esagoni:
			if Mappa.ha_citta(h) and Mappa.stato(h) == "AU" and sp_in(h, 0) == 0:
				s["controllo"][h] = 1
		_log("[b]Alleanze[/b] (dado %d, modificato %d): l'Austria e la Svezia dichiarano guerra alla Francia!" % [tiro, t])
		eventi.append({"k": "annuncio", "t": "L'Austria e la Svezia entrano in guerra!"})
	elif t >= 7:
		s["alleanze_fatte"].append("defezione")
		_defezione(al)
		_log("[b]Alleanze[/b] (dado %d, modificato %d): i satelliti tedeschi abbandonano Napoleone!" % [tiro, t])
		eventi.append({"k": "annuncio", "t": "I satelliti tedeschi passano alla Coalizione"})
	else:
		_log("Alleanze (dado %d, modificato %d): nessun effetto." % [tiro, t])

func _defezione(al: Dictionary) -> void:
	var cambia: Dictionary = al["defezione"]
	for id in s["unita"].keys():
		var u: Dictionary = s["unita"][id]
		if u["n"] != "FR" or not cambia.has(u["s"]):
			continue
		var nuova: String = cambia[u["s"]]
		var h: String = u["h"]
		var sp := int(u["sp"])
		s["unita"].erase(id)
		if nuova == "":
			continue
		var dove := h
		if sp_in(h, 0) > 0:
			dove = ""
			for v in Mappa.vicini(h):
				if sp_in(v[0], 0) == 0 and sp_in(v[0], 2) == 0:
					dove = v[0]
					break
		if dove != "":
			_nuova_unita(nuova, "", "L", sp, dove)
	for id in s["capi"]:
		var c: Dictionary = s["capi"][id]
		if c["n"] == "FR" and cambia.has(c["s"]):
			c["h"] = ""
			c["morto"] = true

func _controlla_vittoria_immediata() -> bool:
	if finita():
		return true
	if sp_lato(0) == 0:
		_chiudi(1, "L'esercito francese è distrutto.")
		return true
	if sp_lato(1) == 0 and sp_lato(2) == 0 and s["riserva"].is_empty():
		_chiudi(0, "Gli eserciti alleati sono distrutti.")
		return true
	return _vittoria_cond("subito")

## Condizioni di vittoria dello scenario. quando = "subito" (a fine segmento o combattimento),
## "fine" (a fine partita)
func _vittoria_cond(quando: String) -> bool:
	for v in scen.get("vittoria_cond", []):
		var q := str(v.get("quando", "subito"))
		if q != quando and q != "sempre":
			continue
		if int(s["turno"]) < int(v.get("dal", 0)):
			continue
		if v.has("segmento") and int(v["segmento"]) != int(s["lato"]):
			continue
		if _condizione(v["test"]):
			_chiudi(int(v["vince"]), str(v.get("perche", "")))
			return true
	return false

func _fine_partita() -> void:
	if scen.has("vittoria_cond"):
		if _vittoria_cond("fine"):
			return
		if scen.has("punti_egitto"):
			_fine_egitto()
			return
		var dv := int(scen.get("vince_default", 1))
		_chiudi(dv, str(scen.get("perche_default", "Nessuna condizione di vittoria raggiunta.")))
		return
	if scen.get("vittoria_tipo", "") == "vienna":
		var hv := Mappa.hex("Vienna")
		var fr := 0
		for id in unita_in(hv, 0):
			if not (s["assedi"].has(hv) and int(s["assedi"][hv]["lato"]) == 1 and s["unita"][id]["in"]):
				fr += int(s["unita"][id]["sp"])
		if fr > 0:
			_chiudi(0, "Napoleone è a Vienna con %d punti forza: pace di Presburgo." % fr)
		else:
			_chiudi(1, "Vienna non è in mano francese: la Coalizione resiste.")
		return
	if scen.get("vittoria_tipo", "") == "area3":
		var tenute := []
		for h in Mappa.esagoni:
			if Mappa.citta_maggiore(h) and Mappa.area(h) == 3 and controllore(h) == 0 and not s["assedi"].has(h):
				tenute.append(Mappa.nome_citta(h))
		if tenute.is_empty():
			_chiudi(1, "I Francesi non tengono più nessuna città maggiore libera in Germania (area 3).")
		else:
			_chiudi(0, "I Francesi tengono ancora: %s." % ", ".join(tenute))
		return
	var p0 := punti(0)
	var p1 := punti(1)
	var m := int(scen.get("margine", 3))
	if p0["tot"] >= p1["tot"] + m:
		_chiudi(0, "Francesi %d, Coalizione %d." % [p0["tot"], p1["tot"]])
	elif p1["tot"] > p0["tot"]:
		_chiudi(1, "Coalizione %d, Francesi %d." % [p1["tot"], p0["tot"]])
	else:
		_chiudi(-1, "Francesi %d, Coalizione %d: pace di compromesso." % [p0["tot"], p1["tot"]])

## Egitto: i punti città francesi a fine partita decidono vittoria decisiva, marginale o pareggio
func _fine_egitto() -> void:
	var pe: Dictionary = scen["punti_egitto"]
	var cp := 0
	for nome in pe["citta"]:
		if controllore(Mappa.hex(nome)) == 0:
			cp += int(pe["citta"][nome])
	if pe.has("bonaparte_francia"):
		for id in s["capi"]:
			var c: Dictionary = s["capi"][id]
			if c["nome"] == "Bonaparte" and c["h"] != "" and Mappa.stato(c["h"]) == "FR" and Mappa.ha_citta(c["h"]):
				cp += 1
	cp += int(pe.get("bonus", 0))
	var soglie: Array = pe["soglie"]  # [decisiva FR, marginale FR, pareggio da]
	if cp >= int(soglie[0]):
		_chiudi(0, "Vittoria decisiva francese: %d punti città." % cp)
	elif cp >= int(soglie[1]):
		_chiudi(0, "Vittoria marginale francese: %d punti città." % cp)
	elif cp >= int(soglie[2]):
		_chiudi(-1, "Pareggio: %d punti città." % cp)
	elif cp >= 3:
		_chiudi(1, "Vittoria marginale della Coalizione: i Francesi hanno solo %d punti città." % cp)
	else:
		_chiudi(1, "Vittoria decisiva della Coalizione: i Francesi hanno solo %d punti città." % cp)

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
	if not s.has("neutrali"):
		s["neutrali"] = []
	if not s.has("alleanze_fatte"):
		s["alleanze_fatte"] = []
	Mappa.inverno = inverno()

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

# =============================================================================================
# Movimento via mare degli scenari (inglesi da porto a porto, russi nel Baltico...)
# scen["mare"] = {lato, naz, max_sp, max_capi, da: "porto"/"costa", a: "porto_libero"/"porto_amico"/
#   "costa_libera", citta (solo queste), assediati (si parte anche da città assediate), estate (non d'inverno)}

func regole_mare() -> Dictionary:
	var m: Dictionary = scen.get("mare", {})
	if m.is_empty() or int(m.get("lato", 1)) != int(s["lato"]):
		return {}
	if m.get("estate", false) and inverno():
		return {}
	if m.has("anni") and not int(s["anno"]) in m["anni"]:
		return {}
	return m

func _mare_naz_ok(u: Dictionary, m: Dictionary) -> bool:
	return u["n"] in m.get("naz", ["EN"]) and (u["s"] == "" or m.get("satelliti", true))

## Esagoni raggiungibili via mare da un esagono con il gruppo indicato
func destinazioni_mare(capo: String, porta: Dictionary) -> Array:
	var m := regole_mare()
	if m.is_empty():
		return []
	var l: int = s["lato"]
	var da := ""
	var sp := 0
	for id in porta:
		var u: Dictionary = s["unita"].get(id, {})
		if u.is_empty() or u["mo"] or lato_unita(u) != l or not _mare_naz_ok(u, m):
			return []
		if u["in"] and s["assedi"].has(u["h"]) and not m.get("assediati", false):
			return []
		if da != "" and u["h"] != da:
			return []
		da = u["h"]
		sp += int(porta[id])
	if capo != "":
		var c: Dictionary = s["capi"].get(capo, {})
		if c.is_empty() or lato_capo(c) != l or int(c["mp"]) > 0 or not c["n"] in m.get("naz", ["EN"]):
			return []
		if da != "" and c["h"] != da:
			return []
		da = c["h"]
	if da == "" or (sp == 0 and capo == ""):
		return []
	var usato: Dictionary = s["mare_usato"]
	if int(usato.get("sp", 0)) + sp > int(m.get("max_sp", 2)):
		return []
	if capo != "" and int(m.get("max_capi", -1)) >= 0 and int(usato.get("capi", 0)) + 1 > int(m["max_capi"]):
		return []
	if not _punto_mare(da, str(m.get("da", "porto")), l, m, true):
		return []
	var out := []
	for h in Mappa.esagoni:
		if h != da and _punto_mare(h, str(m.get("a", "porto_libero")), l, m, false):
			out.append(h)
	return out

func _punto_mare(h: String, tipo: String, l: int, m: Dictionary, partenza: bool) -> bool:
	if not Mappa.costiero(h) or not aperto(h) and not partenza:
		return false
	if m.has("citta") and not Mappa.nome_citta(h) in m["citta"]:
		return false
	if m.has("zone"):
		var ok := false
		for z in Mappa.zone(h):
			if z in m["zone"]:
				ok = true
		if not ok:
			return false
	match tipo:
		"porto":
			return Mappa.porto(h)
		"costa":
			return true
		"porto_amico":
			return Mappa.porto(h) and controllore(h) == l and not nemico_fuori(h, l)
		"porto_libero":
			return Mappa.porto(h) and controllore(h) != 1 - l and not nemico_in(h, l)
		"costa_libera":
			return not nemico_in(h, l)
	return false

func _mare(d: Dictionary) -> bool:
	var capo := str(d.get("capo", ""))
	var porta: Dictionary = {}
	for k in d.get("porta", {}):
		porta[str(k)] = int(d["porta"][k])
	var verso := str(d.get("verso", ""))
	if not verso in destinazioni_mare(capo, porta):
		return false
	var da := ""
	var sp := 0
	var mobili := []
	for id in porta:
		da = s["unita"][id]["h"]
		sp += int(porta[id])
		mobili.append(_separa(id, int(porta[id])))
	for id in mobili:
		var u: Dictionary = s["unita"][id]
		u["h"] = verso
		u["mo"] = true
		u["in"] = false
		u["sb"] = true
	if capo != "":
		da = s["capi"][capo]["h"]
		s["capi"][capo]["h"] = verso
		s["capi"][capo]["mp"] = mp_capo(capo)
		s["mare_usato"]["capi"] = int(s["mare_usato"].get("capi", 0)) + 1
	s["mare_usato"]["sp"] = int(s["mare_usato"].get("sp", 0)) + sp
	_aggiorna_controllo(verso)
	_log("Via mare: %s%s da %s a %s." % [(s["capi"][capo]["nome"] + " ") if capo != "" else "", ("con %d PF" % sp) if sp > 0 else "", Mappa.nome(da), Mappa.nome(verso)])
	eventi.append({"k": "mossa", "da": da, "a": verso, "strada": [da, verso]})
	return true

# =============================================================================================
# Forze "in mare" (fuori mappa): sbarcano su una costa secondo le regole del gruppo

func _in_riserva(g: Dictionary) -> void:
	var rid := "r%d" % s["prossimo"]
	s["prossimo"] += 1
	var lato := _lato_gruppo(g)
	if g.has("lato"):
		lato = int(g["lato"])
	var r := {"id": rid, "lato": lato, "zona": str(g.get("zona", g.get("mare", ""))), "capi": [], "unita": [],
		"dove": g.get("dove", scen.get("sbarco", "costa_libera")), "vicino": g.get("vicino", [])}
	for c in g.get("capi", []):
		var p: PackedStringArray = str(c).split(":")
		var id := _nuovo_capo(p[0], p[1], "", p[2] if p.size() > 2 else "")
		if id != "":
			s["capi"][id]["h"] = ""
			s["capi"][id]["mare"] = rid
			r["capi"].append(id)
	for u in g.get("unita", []):
		r["unita"].append([u[0], u[1], u[2], int(u[3])])
	# si unisce a un gruppo già in mare nella stessa zona con le stesse regole
	for r2 in s["riserva"]:
		if int(r2["lato"]) == lato and r2["zona"] == r["zona"] and str(r2["dove"]) == str(r["dove"]) and str(r2["vicino"]) == str(r["vicino"]):
			for id in r["capi"]:
				s["capi"][id]["mare"] = r2["id"]
				r2["capi"].append(id)
			r2["unita"].append_array(r["unita"])
			return
	s["riserva"].append(r)

func riserve(lato: int) -> Array:
	var out := []
	for r in s["riserva"]:
		if int(r["lato"]) == lato:
			out.append(r)
	return out

func _riserva(rid: String) -> Dictionary:
	for r in s["riserva"]:
		if r["id"] == rid:
			return r
	return {}

func destinazioni_sbarco(rid: String) -> Array:
	var r := _riserva(rid)
	if r.is_empty() or int(r["lato"]) != int(s["lato"]):
		return []
	var l: int = s["lato"]
	var out := []
	for h in Mappa.esagoni:
		if not Mappa.costiero(h) or not aperto(h):
			continue
		if r["zona"] != "" and not r["zona"] in Mappa.zone(h):
			continue
		if sp_in(h, 2) > 0:
			continue
		var ok := false
		match str(r["dove"]):
			"costa_amica":
				ok = sp_in(h, l) > 0 or (Mappa.ha_citta(h) and controllore(h) == l and not nemico_in(h, l))
			"costa_libera":
				ok = not nemico_in(h, l)
			"porto_libero":
				ok = Mappa.porto(h) and controllore(h) != 1 - l and not nemico_in(h, l)
			"vicino":
				var v: Array = r["vicino"]
				ok = not nemico_in(h, l) and Mappa.distanza(h, Mappa.hex(v[0]), int(v[1])) <= int(v[1])
		if ok:
			out.append(h)
	return out

func _sbarca(rid: String, verso: String) -> bool:
	if not verso in destinazioni_sbarco(rid):
		return false
	var r := _riserva(rid)
	for u in r["unita"]:
		var id := _nuova_unita(u[0], u[1], u[2], int(u[3]), verso)
		s["unita"][id]["mo"] = true
		s["unita"][id]["sb"] = true
	for id in r["capi"]:
		s["capi"][id]["h"] = verso
		s["capi"][id].erase("mare")
		s["capi"][id]["mp"] = mp_capo(id)
	s["riserva"].erase(r)
	_aggiorna_controllo(verso)
	_log("Sbarco a %s." % Mappa.nome(verso))
	eventi.append({"k": "annuncio", "t": "Sbarco a %s" % Mappa.nome(verso)})
	return true

func _sbarca_obbligatorio() -> void:
	pass

## Partigiani nuovi: negli esagoni di foresta, montagna o città del paese senza altre unità,
## i più vicini al nemico
func _nuovi_partigiani(naz: String, stato: String, n: int) -> void:
	var l := lato_di(naz)
	var cand := []
	for h in Mappa.esagoni:
		if Mappa.stato(h) != stato or not aperto(h) or not unita_in(h).is_empty():
			continue
		if not (Mappa.ha_citta(h) or Mappa.terreno(h) in ["foresta", "montagna", "montagna_alta"]):
			continue
		cand.append(h)
	var nem := esagoni_di(1 - l)
	cand.sort_custom(func(a, b):
		var da := 99
		var db := 99
		for x in nem:
			da = mini(da, Mappa.distanza(a, x, 5))
			db = mini(db, Mappa.distanza(b, x, 5))
		return da < db)
	for i in mini(n, cand.size()):
		_nuova_unita(naz, "", "P", 1, cand[i])
		_log("Partigiani a %s." % Mappa.nome(cand[i]))

# =============================================================================================
# Flotte (Grand Campaign Game, sezione F): squadre (S) e trasporti (T), 4 punti movimento,
# intercettazione, combattimento navale, blocco dei porti, trasporto di truppe, logoramento in mare.
# Una nave: {n, s, t, sp, h (porto o costa, "" se in mare), z (zona se in mare), dan, mp}

func _nuova_flotta(fl: Dictionary) -> void:
	var h := ""
	if fl.has("hex"):
		h = _risolvi_hex(str(fl["hex"]))
	for x in fl["navi"]:
		for i in int(x[3]):
			_nuova_nave(x[0], x[1], x[2], 1, h, str(fl.get("zona", "")))
	for c in fl.get("capi", []):
		var p: PackedStringArray = str(c).split(":")
		var id := _nuovo_capo(p[0], p[1], "", p[2] if p.size() > 2 else "")
		if id != "":
			s["capi"][id]["h"] = h
			s["capi"][id]["nave"] = true
			if h == "":
				s["capi"][id]["mare"] = "z:" + str(fl.get("zona", ""))

func _nuova_nave(naz: String, sub: String, tipo: String, sp: int, h: String, zona: String) -> String:
	var id := "n%d" % s["prossimo"]
	s["prossimo"] += 1
	s["navi"][id] = {"n": naz, "s": sub, "t": tipo, "sp": sp, "h": h, "z": zona if h == "" else "", "dan": false, "mp": 0}
	return id

func lato_nave(nv: Dictionary) -> int:
	if s["neutrali"].has(nv["n"]) or (nv["s"] != "" and s["neutrali"].has(nv["s"])):
		return 2
	return lato_di(nv["n"])

func _ha_navi(l: int) -> bool:
	for id in s["navi"]:
		if lato_nave(s["navi"][id]) == l:
			return true
	return false

## Dove si trova una nave: l'esagono o "@ZONA" se in mare
func posto_nave(id: String) -> String:
	var nv: Dictionary = s["navi"][id]
	return nv["h"] if nv["h"] != "" else "@" + str(nv["z"])

func navi_in(posto: String, lato := -1) -> Array:
	var out := []
	for id in s["navi"]:
		if posto_nave(id) == posto and (lato < 0 or lato_nave(s["navi"][id]) == lato):
			out.append(id)
	return out

## Zone di mare di un posto (un porto può toccarne due)
func zone_posto(p: String) -> Array:
	if p.begins_with("@"):
		return [p.substr(1)]
	return Mappa.zone(p)

func forza_navale(ids: Array) -> int:
	var t := 0
	for id in ids:
		var nv: Dictionary = s["navi"].get(id, {})
		if not nv.is_empty() and nv["t"] == "S":
			t += int(nv["sp"])
	return t

func _nelson_con(ids: Array) -> bool:
	for c in s["capi"]:
		var cc: Dictionary = s["capi"][c]
		if cc["nome"] == "Nelson" and cc.get("nave", false) and not cc["morto"] and not cc.get("ritirato", false):
			for id in ids:
				if s["navi"].has(id) and _posto_capo_nave(c) == posto_nave(id) and s["navi"][id]["n"] == "EN":
					return true
	return false

func _posto_capo_nave(c: String) -> String:
	var cc: Dictionary = s["capi"][c]
	if cc["h"] != "":
		return cc["h"]
	return "@" + str(cc.get("mare", "z:")).substr(2)

## Porto bloccato dal nemico per il lato
func bloccato(h: String, lato: int) -> bool:
	return s["blocchi"].has(h) and int(s["blocchi"][h]) != lato

## Costo in punti movimento navali e zone attraversate da un posto all'altro
func percorso_navale(da: String, a: String) -> Dictionary:
	if da == a:
		return {}
	var zda := zone_posto(da)
	var za := zone_posto(a)
	if zda.is_empty() or za.is_empty():
		return {}
	# ricerca sulle zone: entrare in una zona costa 1 (anche uscendo da un porto)
	var best := {}
	for z0 in zda:
		var dist := {z0: 1 if not da.begins_with("@") else 0}
		var prec := {z0: ""}
		var coda := [z0]
		while not coda.is_empty():
			var z: String = coda.pop_front()
			for z2 in Dati.ZONE[z]["con"]:
				if not dist.has(z2):
					dist[z2] = int(dist[z]) + 1
					prec[z2] = z
					coda.append(z2)
		for z1 in za:
			if not dist.has(z1):
				continue
			var c := int(dist[z1])
			if not a.begins_with("@"):
				c += 1 if Mappa.porto(a) else 2
			if best.is_empty() or c < int(best["mp"]):
				var catena := []
				var zz: String = z1
				while zz != "":
					catena.push_front(zz)
					zz = prec[zz]
				best = {"mp": c, "zone": catena}
	return best

## Destinazioni navali di un gruppo di navi (stesso posto) con il carico indicato
func destinazioni_navali(ids: Array, carico: Dictionary = {}) -> Dictionary:
	var l: int = s["lato"]
	var da := ""
	var mp := 0
	for id in ids:
		var nv: Dictionary = s["navi"].get(id, {})
		if nv.is_empty() or lato_nave(nv) != l:
			return {}
		var p := posto_nave(id)
		if da != "" and p != da:
			return {}
		da = p
		mp = maxi(mp, int(nv["mp"]))
	if da == "":
		return {}
	var resto := 4 - mp
	var out := {}
	var posti := []
	for z in Dati.ZONE:
		posti.append("@" + z)
	for h in Mappa.esagoni:
		if Mappa.costiero(h):
			posti.append(h)
	for p in posti:
		if p == da:
			continue
		if not p.begins_with("@"):
			# si entra in un porto proprio o libero, o lo si blocca se ci sono navi nemiche più deboli
			if Mappa.porto(p) and controllore(p) == 1 - l:
				var nem := navi_in(p, 1 - l)
				if nem.is_empty() or forza_navale(ids) < forza_navale(nem) or forza_navale(ids) == 0:
					continue
			if bloccato(p, l) and controllore(p) != l:
				continue
			if not carico.is_empty() and (nemico_fuori(p, l) or not aperto(p) or sp_in(p, 2) > 0):
				continue
		elif not carico.is_empty():
			continue
		var pr := percorso_navale(da, p)
		if pr.is_empty() or int(pr["mp"]) > resto:
			continue
		out[p] = pr
	return out

## Capacità di trasporto: 2 PF di fanteria o 1 di cavalleria per trasporto (doppia in Egitto)
func capacita_trasporti(ids: Array) -> int:
	var n := 0
	for id in ids:
		if s["navi"].has(id) and s["navi"][id]["t"] == "T":
			n += 1
	return n * 2 * int(scen.get("trasporti_x", 1))

func carico_valido(ids: Array, carico: Dictionary, capi: Array) -> bool:
	var da := posto_nave(ids[0]) if not ids.is_empty() else ""
	if da == "" or da.begins_with("@"):
		return carico.is_empty() and capi.is_empty()
	var l: int = s["lato"]
	var peso := 0
	var fanteria := false
	var naz_navi := {}
	for id in ids:
		naz_navi[s["navi"][id]["n"]] = true
	for id in carico:
		var u: Dictionary = s["unita"].get(id, {})
		if u.is_empty() or u["h"] != da or lato_unita(u) != l or u["mo"] or int(carico[id]) > int(u["sp"]) or int(carico[id]) <= 0:
			return false
		if not naz_navi.has(u["n"]):
			return false
		if u["in"] and s["assedi"].has(da):
			return false
		peso += int(carico[id]) * (2 if Dati.e_cavalleria(u["t"]) else 1)
		if not Dati.e_cavalleria(u["t"]):
			fanteria = true
	if peso > capacita_trasporti(ids):
		return false
	# la fanteria si imbarca solo se c'è un capo nell'esagono
	if fanteria and capi_in(da, l).is_empty():
		return false
	for c in capi:
		if not s["capi"].has(c) or s["capi"][c]["h"] != da or lato_capo(s["capi"][c]) != l:
			return false
	return true

## d = {a: "naviga", navi: [id], verso: esagono o "@ZONA", carico: {id: pf}, capi: [id]}
func _naviga(d: Dictionary) -> bool:
	var ids: Array = []
	for x in d.get("navi", []):
		ids.append(str(x))
	if ids.is_empty():
		return false
	var carico: Dictionary = {}
	for k in d.get("carico", {}):
		carico[str(k)] = int(d["carico"][k])
	var capi: Array = []
	for c in d.get("capi", []):
		capi.append(str(c))
	var verso := str(d.get("verso", ""))
	var dest := destinazioni_navali(ids, {"_": 1} if not carico.is_empty() or not capi.is_empty() else {})
	if not dest.has(verso):
		return false
	if not carico_valido(ids, carico, capi):
		return false
	var l: int = s["lato"]
	var da := posto_nave(ids[0])
	# uscita da un porto bloccato: tabella del blocco
	if not da.begins_with("@") and bloccato(da, l):
		var t := dado()
		var r := Dati.tabella_navale(Dati.BLOCCO, t)
		eventi.append({"k": "dado", "titolo": "Forzare il blocco", "dadi": [t]})
		if r != "E":
			_log("Il blocco di %s regge (dado %d)." % [Mappa.nome(da), t])
			for id in ids:
				s["navi"][id]["mp"] = 4
			if r == "F*":
				var nem := navi_in(da, 1 - l)
				_combattimento_navale(nem, ids, "@" + str(Mappa.zone(da)[0]), true)
			return true
		_log("Le navi escono da %s forzando il blocco (dado %d)." % [Mappa.nome(da), t])
	# imbarco
	var a_bordo := []
	for id in carico:
		a_bordo.append(_separa(id, int(carico[id])))
	var pr: Dictionary = dest[verso]
	var flotta := ids.duplicate()
	var arrivo := verso
	var interrotta := false
	# attraversamento delle zone: intercettazioni del nemico
	var zone_attraversate: Array = pr["zone"]
	for z in zone_attraversate:
		if da.begins_with("@") and z == da.substr(1):
			continue
		var esito := _intercetta(flotta, z, da)
		flotta = flotta.filter(func(x): return s["navi"].has(x))
		if esito == "ritirata" or flotta.is_empty():
			interrotta = true
			arrivo = _porto_amico_zona(z, l, da)
			break
	var spesi := int(pr["mp"])
	for id in flotta:
		if interrotta:
			s["navi"][id]["mp"] = 4
		else:
			s["navi"][id]["mp"] = int(s["navi"][id]["mp"]) + spesi
		if arrivo.begins_with("@"):
			s["navi"][id]["h"] = ""
			s["navi"][id]["z"] = arrivo.substr(1)
		elif arrivo != "":
			s["navi"][id]["h"] = arrivo
			s["navi"][id]["z"] = ""
	# Nelson (e i capi sulle squadre) segue la flotta
	for c in s["capi"]:
		var cc: Dictionary = s["capi"][c]
		if cc.get("nave", false) and lato_capo(cc) == l and _posto_capo_nave(c) == da and not flotta.is_empty():
			if arrivo.begins_with("@"):
				cc["h"] = ""
				cc["mare"] = "z:" + arrivo.substr(1)
			elif arrivo != "":
				cc["h"] = arrivo
				cc.erase("mare")
	if flotta.is_empty() or arrivo == "":
		# navi affondate o senza porto: il carico è perduto
		for id in a_bordo:
			s["unita"].erase(id)
		for c in capi:
			_capo_perso_in_mare(c)
		_log("La flotta è perduta in mare: anche le truppe imbarcate sono perdute.")
		_controlla_blocchi()
		return true
	if not arrivo.begins_with("@"):
		# sbarco: le truppe non si muovono più per terra in questo segmento (salvo con Bonaparte)
		var con_bona := false
		for c in capi:
			if s["capi"][c]["nome"] == "Bonaparte" and scen.get("bonaparte_sbarco", false):
				con_bona = true
		var sp_tot := 0
		for id in a_bordo:
			sp_tot += int(s["unita"][id]["sp"])
		for id in a_bordo:
			var u: Dictionary = s["unita"][id]
			u["h"] = arrivo
			u["in"] = false
			u["sb"] = true
			u["mo"] = not (con_bona and sp_tot <= 12)
		for c in capi:
			s["capi"][c]["h"] = arrivo
			if not con_bona:
				s["capi"][c]["mp"] = mp_capo(c)
		_aggiorna_controllo(arrivo)
		# blocco di un porto nemico con navi dentro
		if Mappa.porto(arrivo) and controllore(arrivo) == 1 - l and not navi_in(arrivo, 1 - l).is_empty():
			s["blocchi"][arrivo] = l
			_log("[b]Blocco navale[/b] di %s." % Mappa.nome(arrivo))
		# navi nemiche ferme su una costa (non in porto): combattimento
		elif not Mappa.porto(arrivo) and not navi_in(arrivo, 1 - l).is_empty():
			_combattimento_navale(flotta, navi_in(arrivo, 1 - l), arrivo, false)
	var nome_a: String = Dati.ZONE[arrivo.substr(1)]["nome"] if arrivo.begins_with("@") else Mappa.nome(arrivo)
	var nome_da: String = Dati.ZONE[da.substr(1)]["nome"] if da.begins_with("@") else Mappa.nome(da)
	_log("Flotta (%d navi%s): %s » %s%s." % [flotta.size(), (", %d PF a bordo" % _sp_ids(a_bordo)) if not a_bordo.is_empty() else "", nome_da, nome_a, " (interrotta)" if interrotta else ""])
	eventi.append({"k": "navale", "da": da, "a": arrivo})
	_controlla_blocchi()
	return true

func _sp_ids(ids: Array) -> int:
	var t := 0
	for id in ids:
		if s["unita"].has(id):
			t += int(s["unita"][id]["sp"])
	return t

func _capo_perso_in_mare(c: String) -> void:
	s["capi"][c]["h"] = ""
	s["capi"][c]["morto"] = true
	_log("%s è perduto in mare." % s["capi"][c]["nome"])

## Il porto amico più vicino nella zona (per ritirate e fughe); "" se non ce n'è
func _porto_amico_zona(z: String, l: int, preferito := "") -> String:
	if preferito != "" and not preferito.begins_with("@") and z in Mappa.zone(preferito) and controllore(preferito) == l and not bloccato(preferito, l):
		return preferito
	var best := ""
	var bd := INF
	var rif := Vector2.ZERO
	for h in Mappa.esagoni:
		if Mappa.porto(h) and z in Mappa.zone(h) and controllore(h) == l and not bloccato(h, l) and not nemico_fuori(h, l):
			var d := Mappa.pos(h).length() if preferito == "" or preferito.begins_with("@") else Mappa.pos(h).distance_to(Mappa.pos(preferito))
			if d < bd:
				bd = d
				best = h
	return best

## Intercettazione di una flotta che entra in una zona: le squadre nemiche non bloccate della zona
## tentano (dado + 1 se già in mare + Nelson) e, se riescono, attaccano. Restituisce "" o "ritirata".
func _intercetta(flotta: Array, z: String, origine := "") -> String:
	var l: int = s["lato"]
	var nemici := []
	var in_mare := true
	for id in s["navi"]:
		var nv: Dictionary = s["navi"][id]
		if lato_nave(nv) != 1 - l or nv["t"] != "S" or nv.get("int", false):
			continue
		var p := posto_nave(id)
		if p == origine:
			continue  # chi blocca un porto non intercetta le navi che ne escono
		if p == "@" + z:
			nemici.append(id)
		elif not p.begins_with("@") and z in Mappa.zone(p) and not bloccato(p, 1 - l):
			nemici.append(id)
	if nemici.is_empty():
		return ""
	var mia := forza_navale(flotta)
	var sua := forza_navale(nemici)
	var porta_truppe := false
	for id in flotta:
		if s["navi"][id]["t"] == "T":
			porta_truppe = true
	# il difensore intercetta se è abbastanza forte o se ci sono trasporti da colpire
	if not (sua >= mia * 0.75 or (porta_truppe and sua > 0)):
		return ""
	for id in nemici:
		if posto_nave(id) != "@" + z:
			in_mare = false
	var t := dado()
	var mod := (1 if in_mare else 0) + int(Dati.ZONE.get(z, {}).get("im", 0)) + (1 if _nelson_con(nemici) else 0)
	var r := Dati.tabella_navale(Dati.INSEGUIMENTO, t + mod)
	for id in nemici:
		s["navi"][id]["int"] = true
	eventi.append({"k": "dado", "titolo": "Intercettazione", "dadi": [t]})
	if r != "I":
		_log("Le squadre nemiche non intercettano la flotta in %s (dado %d%+d)." % [Dati.ZONE[z]["nome"], t, mod])
		return ""
	_log("[b]Intercettazione[/b] in %s (dado %d%+d)!" % [Dati.ZONE[z]["nome"], t, mod])
	eventi.append({"k": "annuncio", "t": "Flotta intercettata: %s" % Dati.ZONE[z]["nome"]})
	# le squadre intercettanti vanno in mare
	for id in nemici:
		s["navi"][id]["h"] = ""
		s["navi"][id]["z"] = z
	return _combattimento_navale(nemici, flotta, "@" + z, false)

## Combattimento navale fra due flotte (round ripetuti con inseguimento). Restituisce "ritirata"
## se la flotta b (quella che si muove o è attaccata) deve ritirarsi o è distrutta.
func _combattimento_navale(a: Array, b: Array, posto: String, un_round: bool) -> String:
	var la := lato_nave(s["navi"][a[0]]) if not a.is_empty() else 0
	var lb := 1 - la
	var sconfitte := {la: 0, lb: 0}
	for round_n in 6:
		a = a.filter(func(x): return s["navi"].has(x))
		b = b.filter(func(x): return s["navi"].has(x))
		var fa := forza_navale(a)
		var fb := forza_navale(b)
		if fa == 0 or b.is_empty():
			return "" if fb > 0 or b.is_empty() else "ritirata"
		if fb == 0:
			# trasporti senza scorta
			_trasporti_attaccati(b, posto)
			return "ritirata"
		var grande := a if fa >= fb else b
		var piccola := b if fa >= fb else a
		var lg := la if fa >= fb else lb
		var fg := maxi(fa, fb)
		var fp := mini(fa, fb)
		var rap := Dati.rapporto_navale(fg, fp)
		var mod := 0
		if s["navi"][grande[0]]["n"] == "EN": mod += 1
		if s["navi"][piccola[0]]["n"] == "EN": mod -= 1
		if _nelson_con(grande): mod += 1
		if _nelson_con(piccola): mod -= 1
		var t := dado()
		var ris := Dati.esito_navale(rap, t + mod)
		var rep := {"r": round_n + 1, "posto": posto, "forze": [fg, fp], "lati": [lg, 1 - lg], "rapporto": rap, "dado": t, "mod": mod, "ris": ris}
		eventi.append({"k": "navale_batt", "rep": rep})
		_log("[b]Battaglia navale[/b] (%s, round %d): %d contro %d squadre, %s; dado %d%+d » %s %s / %s %s" % [
			_nome_posto(posto), round_n + 1, fg, fp, rap, t, mod, Dati.LATI_BREVI[lg], ris[0], Dati.LATI_BREVI[1 - lg], ris[1]])
		_danni_navali(grande, str(ris[0]), fp)
		_danni_navali(piccola, str(ris[1]), fp)
		# chi deve ritirarsi
		var perde_g: bool = str(ris[0]) in ["R", "K", "C", "2K", "2C"]
		var perde_p: bool = str(ris[1]) in ["R", "K", "C", "2K", "2C"]
		var ritira_g: bool = str(ris[0]) == "R"
		var ritira_p: bool = str(ris[1]) == "R"
		if perde_g: sconfitte[lg] = int(sconfitte[lg]) + 1
		if perde_p: sconfitte[1 - lg] = int(sconfitte[1 - lg]) + 1
		var perdente := -1
		if ritira_p or (perde_p and not perde_g):
			perdente = 1 - lg
		elif ritira_g or (perde_g and not perde_p):
			perdente = lg
		if un_round or perdente < 0:
			return ""
		var vinc := 1 - perdente
		var fl_v: Array = a if la == vinc else b
		var fl_p: Array = a if la == perdente else b
		fl_v = fl_v.filter(func(x): return s["navi"].has(x))
		fl_p = fl_p.filter(func(x): return s["navi"].has(x))
		# inseguimento del vincitore
		var ti := dado()
		var mi := (1 if posto.begins_with("@") else 0) + (1 if _nelson_con(fl_v) else 0)
		if forza_navale(fl_v) >= forza_navale(fl_p) and Dati.tabella_navale(Dati.INSEGUIMENTO, ti + mi) == "I" and int(sconfitte[perdente]) < 2:
			_log("Il vincitore insegue (dado %d): nuovo round." % ti)
			continue
		# il perdente si ritira nel porto amico più vicino della zona
		var z: String = zone_posto(posto)[0]
		var porto := _porto_amico_zona(z, perdente)
		for id in fl_p:
			if porto == "":
				pass
			else:
				s["navi"][id]["h"] = porto
				s["navi"][id]["z"] = ""
				s["navi"][id]["mp"] = 4
		if porto == "":
			_trasporti_attaccati(fl_p, posto)
		else:
			_log("La flotta sconfitta ripara a %s." % Mappa.nome(porto))
		return "ritirata" if perdente == lb else ""
	return ""

func _nome_posto(p: String) -> String:
	return Dati.ZONE[p.substr(1)]["nome"] if p.begins_with("@") else Mappa.nome(p)

## Affondamenti, catture e danni (Naval Damage Table: secondo i punti della forza più piccola)
func _danni_navali(ids: Array, ris: String, piccola: int) -> void:
	if ris == "0":
		return
	var squadre := ids.filter(func(x): return s["navi"].has(x) and s["navi"][x]["t"] == "S")
	var persi: int = {"K": 1, "C": 1, "2K": 2, "2C": 2}.get(ris, 0)
	for i in persi:
		if squadre.is_empty():
			break
		var id: String = squadre.pop_back()
		s["navi"].erase(id)
	var danni := Dati.danni_navali(ris, piccola)
	for id in squadre:
		if danni <= 0:
			break
		if not s["navi"].has(id):
			continue
		if s["navi"][id]["dan"]:
			s["navi"].erase(id)  # già danneggiata: affonda
		else:
			s["navi"][id]["dan"] = true
		danni -= 1
	_nelson_affondato()

func _nelson_affondato() -> void:
	for c in s["capi"]:
		var cc: Dictionary = s["capi"][c]
		if cc["nome"] == "Nelson" and cc.get("nave", false) and not cc["morto"] and not cc.get("ritirato", false):
			var p := _posto_capo_nave(c)
			if navi_in(p, lato_capo(cc)).is_empty():
				cc["morto"] = true
				cc["h"] = ""
				_log("[b]Nelson muore in battaglia.[/b]")

## Trasporti (o navi senza porto) attaccati senza scorta: catturati, affondati o in fuga
func _trasporti_attaccati(ids: Array, posto: String) -> void:
	var t := dado()
	var r := Dati.tabella_navale(Dati.TRASPORTO, t)
	var l := lato_nave(s["navi"][ids[0]]) if not ids.is_empty() and s["navi"].has(ids[0]) else 0
	if r == "E":
		var porto := _porto_amico_zona(zone_posto(posto)[0], l)
		if porto != "":
			for id in ids:
				if s["navi"].has(id):
					s["navi"][id]["h"] = porto
					s["navi"][id]["z"] = ""
			_log("I trasporti sfuggono e riparano a %s (dado %d)." % [Mappa.nome(porto), t])
			return
	for id in ids:
		s["navi"].erase(id)
	_log("Le navi senza scorta sono %s (dado %d)." % ["catturate" if r == "C" else "affondate", t])

## I blocchi cadono se i bloccanti sono meno delle squadre bloccate o se se ne vanno
func _controlla_blocchi() -> void:
	for h in s["blocchi"].keys():
		var l := int(s["blocchi"][h])
		var fuori := navi_in(h, l)
		var dentro := navi_in(h, 1 - l)
		if fuori.is_empty() or dentro.is_empty() or forza_navale(fuori) < forza_navale(dentro):
			s["blocchi"].erase(h)
			_log("Il blocco di %s è tolto." % Mappa.nome(h))

## Fine della fase navale: si passa al movimento terrestre
func _fine_navale() -> void:
	_controlla_blocchi()
	s["fase"] = "movimento"

## Logoramento in mare (dado non modificato 6): un dado per zona; con 5 o 6 squadre danneggiate
func _logoramento_navale(l: int) -> void:
	var per_zona := {}
	for id in s["navi"]:
		var nv: Dictionary = s["navi"][id]
		if lato_nave(nv) == l and nv["h"] == "":
			if not per_zona.has(nv["z"]):
				per_zona[nv["z"]] = []
			per_zona[nv["z"]].append(id)
	for z in per_zona:
		var t := dado()
		if t >= 5:
			var ids: Array = per_zona[z]
			var n := Dati.danni_navali("logoramento", forza_navale(ids) + ids.size() - forza_navale(ids))
			for id in ids:
				if n <= 0:
					break
				if s["navi"][id]["dan"]:
					s["navi"].erase(id)
				else:
					s["navi"][id]["dan"] = true
				n -= 1
			_log("Burrasca in %s (dado %d): navi danneggiate." % [Dati.ZONE[z]["nome"], t])

## Le navi danneggiate in un porto amico vengono riparate (semplificato: senza punti produzione)
func _ripara_navi(l: int) -> void:
	for id in s["navi"]:
		var nv: Dictionary = s["navi"][id]
		if lato_nave(nv) == l and nv["dan"] and nv["h"] != "" and controllore(nv["h"]) == l and not bloccato(nv["h"], l):
			nv["dan"] = false

## Navi in un porto caduto in mano nemica: catturate
func _navi_porti_caduti() -> void:
	for id in s["navi"].keys():
		var nv: Dictionary = s["navi"][id]
		if nv["h"] != "" and Mappa.porto(nv["h"]) and controllore(nv["h"]) == 1 - lato_nave(nv) and sp_in(nv["h"], 1 - lato_nave(nv)) > 0 and int(s["blocchi"].get(nv["h"], -1)) != lato_nave(nv):
			s["navi"].erase(id)
			_log("Navi catturate nel porto di %s." % Mappa.nome(nv["h"]))

# =============================================================================================
# Punti di rimpiazzo (guerra di Spagna): ogni turno il lato riceve punti e compra punti forza dalla
# propria riserva (le unità eliminate). Gli acquisti sono automatici secondo le regole dello scenario.

const COSTO_RP := {"I": 1, "C": 2, "GI": 2, "GC": 2, "M": 4, "P": 6, "L": 1}

func _costo_rp(naz: String, sub: String, tipo: String) -> int:
	if (naz == "SP" or sub == "Pt") and tipo == "I":
		return 6
	if (naz == "SP" or sub == "Pt") and tipo == "C":
		return 12
	return int(COSTO_RP.get(tipo, 1))

func _punti_rimpiazzo() -> void:
	var rp: Dictionary = scen.get("rp", {})
	if rp.is_empty():
		return
	var l: int = s["lato"]
	for chi in rp:
		var r: Dictionary = rp[chi]
		if int(r["lato"]) != l:
			continue
		var punti := 0
		if r.has("citta"):
			punti = _rp_citta(str(r["citta"]), int(r["inizio"]))
		else:
			for riga in r["tabella"]:
				if int(s["turno"]) >= int(riga[0]) and int(s["turno"]) <= int(riga[1]):
					if riga[2] is Array:
						var t: int = dado() + (int(riga[3]) if riga.size() > 3 else 0)
						punti = int(riga[2][clampi(t, 1, 6) - 1])
					else:
						punti = int(riga[2])
		if punti > 0:
			_compra(str(chi), r, punti)
	# Spagna: un punto di milizia gratis se un'unità non francese è a Madrid
	if scen.has("madrid_milizia") and l == 1:
		var mad := Mappa.hex("Madrid")
		if sp_in(mad, 1) > 0 and int(s["pool"].get("SP||M", 0)) > 0:
			s["pool"]["SP||M"] = int(s["pool"]["SP||M"]) - 1
			_nuova_unita("SP", "", "M", 1, mad)
			_log("Milizia spagnola a Madrid.")

## Punti di Spagna o Portogallo: il valore iniziale meno le città perse (2 le maggiori, 1 le minori)
func _rp_citta(stato: String, inizio: int) -> int:
	var p := inizio
	for h in Mappa.esagoni:
		if not Mappa.ha_citta(h) or Mappa.stato(h) != stato or Mappa.nome_citta(h) == "Gibraltar":
			continue
		var v := 2 if Mappa.citta_maggiore(h) else 1
		var ora := sp_in(h, 0) > 0
		var prima: bool = s["occ_inizio"].has(h)
		if ora and not prima:
			p -= v
		elif prima and not ora:
			p += v
	return maxi(0, p)

func _compra(chi: String, r: Dictionary, punti: int) -> void:
	var l: int = s["lato"]
	var cand := []
	for k in s["pool"]:
		if int(s["pool"][k]) <= 0:
			continue
		var p: PackedStringArray = str(k).split("|")
		var naz := p[0]
		var sub := p[1]
		var tipo := p[2]
		var ok := false
		match chi:
			"FR":
				ok = naz == "FR"
			"EN":
				ok = naz == "EN" and sub != "Pt" and not tipo in ["M", "P"]
			"SP":
				ok = naz == "SP"
			"Pt":
				ok = (naz == "EN" and sub == "Pt") or (naz == "EN" and tipo in ["M", "P"])
		if ok:
			cand.append([naz, sub, tipo])
	if cand.is_empty():
		return
	# milizia e partigiani prima di fanteria e cavalleria (Spagna e Portogallo); i Francesi prima un satellite
	var ha_mp := false
	for c in cand:
		if c[2] in ["M", "P"]:
			ha_mp = true
	if chi in ["SP", "Pt"] and ha_mp:
		cand = cand.filter(func(c): return c[2] in ["M", "P"])
	cand.sort_custom(func(a, b): return _costo_rp(a[0], a[1], a[2]) < _costo_rp(b[0], b[1], b[2]))
	var comprati := []
	var satellite_fatto := false
	var per_hex := {}
	var guard := 0
	while punti > 0 and guard < 40:
		guard += 1
		var scelto: Array = []
		for c in cand:
			var k := "%s|%s|%s" % c
			if int(s["pool"].get(k, 0)) <= 0 or _costo_rp(c[0], c[1], c[2]) > punti:
				continue
			if chi == "FR" and not satellite_fatto and punti > 1 and c[1] == "":
				var sat := false
				for c2 in cand:
					if c2[1] != "" and int(s["pool"].get("%s|%s|%s" % c2, 0)) > 0 and _costo_rp(c2[0], c2[1], c2[2]) <= punti:
						sat = true
				if sat:
					continue
			scelto = c
			break
		if scelto.is_empty():
			break
		var h := _dove_rimpiazzo(chi, r, scelto, per_hex)
		if h == "":
			break
		var k := "%s|%s|%s" % scelto
		s["pool"][k] = int(s["pool"][k]) - 1
		punti -= _costo_rp(scelto[0], scelto[1], scelto[2])
		if scelto[1] != "":
			satellite_fatto = true
		per_hex[h] = int(per_hex.get(h, 0)) + 1
		_nuova_unita(scelto[0], scelto[1], scelto[2], 1, h)
		comprati.append("%s a %s" % [Dati.TIPI.get(scelto[2], {}).get("nome", scelto[2]), Mappa.nome(h)])
	if not comprati.is_empty():
		_log("Rimpiazzi (%s): %s." % [chi, ", ".join(comprati)])

func _dove_rimpiazzo(chi: String, r: Dictionary, u: Array, per_hex: Dictionary) -> String:
	var l: int = s["lato"]
	var lista := []
	if u[2] == "P":
		var casa := casa_milizia({"n": u[0], "s": u[1]})
		for h in Mappa.esagoni:
			if Mappa.stato(h) == casa and unita_in(h).is_empty() and aperto(h) and (Mappa.ha_citta(h) or Mappa.terreno(h).begins_with("montagna")):
				lista.append(h)
	elif r.has("dove"):
		for nome in r["dove"]:
			var h := Mappa.hex(nome)
			if h != "" and not nemico_in(h, l) and controllore(h) != 1 - l:
				lista.append(h)
	elif chi == "EN":
		for h in Mappa.esagoni:
			if Mappa.porto(h) and aperto(h) and not nemico_in(h, l) and controllore(h) != 1 - l:
				lista.append(h)
	else:
		var casa := "SP" if chi == "SP" else "Pt"
		for h in Mappa.esagoni:
			if Mappa.ha_citta(h) and Mappa.stato(h) == casa and sp_in(h, 1 - l) == 0 and aperto(h):
				lista.append(h)
	# vicino alle proprie forze più grandi (le città indicate dallo scenario restano nel loro ordine)
	if not r.has("dove") or u[2] == "P":
		lista.sort_custom(func(a, b): return sp_in(a, l) > sp_in(b, l))
	for h in lista:
		if int(per_hex.get(h, 0)) < 2:
			return h
	return ""
