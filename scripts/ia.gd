## Intelligenza artificiale: muove eserciti verso obiettivi e nemici, cerca battaglie favorevoli
## (rapporto di forze, capi, morale, terreno), concentra le forze come un "bataillon carré",
## tiene conto del logoramento e del rifornimento, decide assedi, assalti e ritirate.
class_name IA
extends RefCounted

var m: Motore
var piano: Array = []
var chiave := ""
var _campi := {}
## 0 = prudente, 1 = normale, 2 = aggressiva
var carattere := 1

func _init(motore: Motore) -> void:
	m = motore

func decidi(rq: Dictionary) -> Dictionary:
	match rq.get("k", ""):
		"movimento":
			return _movimento(rq)
		"dichiara":
			return _dichiara(rq)
		"citta":
			return {"a": "scelta", "v": _citta(rq)}
		"assalto":
			return {"a": "scelta", "v": _assalto(rq)}
		"continua":
			return {"a": "scelta", "v": _continua(rq)}
		"resta":
			return {"a": "scelta", "v": _resta(rq)}
	return {"a": "fine"}

# =============================================================================================
# Movimento

func _movimento(rq: Dictionary) -> Dictionary:
	var k := "%d|%d|%d" % [m.s["turno"], m.s["lato"], 0]
	if k != chiave:
		chiave = k
		_campi.clear()
		piano = []
		_pianifica(int(rq["lato"]))
	while not piano.is_empty():
		var p: Dictionary = piano.pop_front()
		var d := _concretizza(p)
		if not d.is_empty():
			if p["tipo"] == "cavalleria":
				piano.push_front(p)
			return d
	return {"a": "fine"}

## Campo delle distanze (in punti movimento) verso un esagono
func campo(h0: String) -> Dictionary:
	if _campi.has(h0):
		return _campi[h0]
	var dist := {h0: 0}
	var heap := [[0, h0]]
	while not heap.is_empty():
		var bi := 0
		for i in heap.size():
			if heap[i][0] < heap[bi][0]:
				bi = i
		var e: Array = heap[bi]
		heap.remove_at(bi)
		var h: String = e[1]
		if e[0] > dist[h]:
			continue
		for v in Mappa.vicini(h):
			var n: String = v[0]
			if not m.aperto(n):
				continue
			var d: int = dist[h] + Mappa.costo(n, h)
			if d < dist.get(n, 9999):
				dist[n] = d
				heap.append([d, n])
	_campi[h0] = dist
	return dist

func _forza_vicina(h0: String, lato: int, raggio: int) -> int:
	var t := 0
	var c := campo(h0)
	for h in m.esagoni_di(lato):
		if c.get(h, 9999) <= raggio:
			t += m.sp_in(h, lato)
	return t

## Obiettivi del lato: [esagono, valore]
func _obiettivi(lato: int) -> Array:
	var out := []
	var ob: Dictionary = m.scen["obiettivi"][lato]
	for nome in ob:
		var h := Mappa.hex(nome)
		if m.controllore(h) != lato:
			out.append([h, float(ob[nome]) * 4.0, "citta"])
	# eserciti nemici
	for h in m.esagoni_di(1 - lato):
		var sp := m.sp_in(h, 1 - lato)
		out.append([h, float(sp) * 1.2, "esercito"])
	# città nemiche maggiori (rifornimento e controllo)
	for h in Mappa.esagoni:
		if Mappa.citta_maggiore(h) and m.controllore(h) == 1 - lato and m.aperto(h):
			out.append([h, 2.0, "citta"])
	return out

## Prepara i movimenti: per ogni capo con truppe, sceglie un bersaglio e una destinazione
func _pianifica(lato: int) -> void:
	m.calcola_rifornimento(lato)
	var obiettivi := _obiettivi(lato)
	var difese := _difese(lato)
	# capi ordinati per valore e truppe al seguito
	var capi := []
	for id in m.s["capi"]:
		var c: Dictionary = m.s["capi"][id]
		if c["h"] == "" or m.lato_di(c["n"]) != lato or c["morto"]:
			continue
		capi.append(id)
	capi.sort_custom(func(a, b):
		var ca: Dictionary = m.s["capi"][a]
		var cb: Dictionary = m.s["capi"][b]
		return int(ca["v"]) * 100 + m.sp_in(ca["h"], lato) > int(cb["v"]) * 100 + m.sp_in(cb["h"], lato))
	var assegnati := {}
	for id in capi:
		var c: Dictionary = m.s["capi"][id]
		var h: String = c["h"]
		var bersaglio := _scegli_bersaglio(h, lato, obiettivi, difese, assegnati)
		if bersaglio.is_empty():
			continue
		assegnati[bersaglio[0]] = assegnati.get(bersaglio[0], 0) + 1
		piano.append({"capo": id, "da": h, "verso": bersaglio[0], "tipo": bersaglio[2]})
	# capi senza truppe: raggiungono le truppe senza capo più vicine
	for id in capi:
		var c: Dictionary = m.s["capi"][id]
		if m.sp_in(c["h"], lato) == 0:
			piano.append({"capo": id, "da": c["h"], "verso": "", "tipo": "raggiungi"})
	# cavalleria senza capo: con il capo più vicino o resta
	piano.append({"capo": "", "tipo": "cavalleria"})

## Città proprie da difendere minacciate: [esagono, minaccia]
func _difese(lato: int) -> Array:
	var out := []
	var ob: Dictionary = m.scen["obiettivi"][1 - lato]
	for nome in ob:
		var h := Mappa.hex(nome)
		if m.controllore(h) == lato:
			var minaccia := _forza_vicina(h, 1 - lato, 7)
			var difesa := _forza_vicina(h, lato, 2)
			if minaccia > difesa:
				out.append([h, float(ob[nome]) * 2.0 * float(minaccia - difesa) / float(minaccia)])
	return out

func _scegli_bersaglio(h: String, lato: int, obiettivi: Array, difese: Array, assegnati: Dictionary) -> Array:
	var mia := m.sp_in(h, lato) + _forza_vicina(h, lato, 4) * 0.5
	var best := []
	var bv := -INF
	var c := campo(h)
	for o in obiettivi:
		var t: String = o[0]
		var cd := campo(t)
		var d: int = cd.get(h, 9999)
		if d >= 9999:
			continue
		var val: float = o[1]
		if o[2] == "esercito":
			var sua := float(m.sp_in(t, 1 - lato)) + _forza_vicina(t, 1 - lato, 3) * 0.6
			var rapp := float(mia) / maxf(1.0, sua)
			if rapp < 1.2:
				val = -val * (1.0 if carattere < 2 else 0.4)
			elif rapp >= 2.0:
				val *= 1.6
		else:
			var dif := float(m.sp_in(t, 1 - lato)) + _forza_vicina(t, 1 - lato, 3) * 0.6
			if dif > mia * 0.8:
				val *= 0.3
		val -= assegnati.get(t, 0) * 1.5
		var score := val * 10.0 / (6.0 + d)
		if score > bv:
			bv = score
			best = [t, val, o[2]]
	for dfn in difese:
		var t: String = dfn[0]
		var d: int = c.get(t, 9999)
		var score: float = float(dfn[1]) * 10.0 / (4.0 + d)
		if carattere == 0:
			score *= 1.5
		if score > bv:
			bv = score
			best = [t, dfn[1], "difesa"]
	# troppo debole: si ritira verso le forze amiche più grandi
	var minaccia := _forza_vicina(h, 1 - lato, 4)
	if minaccia > mia * 1.6 and m.sp_in(h, lato) > 0:
		var rif := _rifugio(h, lato)
		if rif != "":
			return [rif, 0.0, "ritirata"]
	return best

## Il miglior rifugio: la città amica o il gruppo amico più forte e più vicino lontano dal nemico
func _rifugio(h: String, lato: int) -> String:
	var best := ""
	var bv := -INF
	var c := campo(h)
	for h2 in m.esagoni_di(lato):
		if h2 == h:
			continue
		var d: int = c.get(h2, 9999)
		if d > 20:
			continue
		var v := float(m.sp_in(h2, lato)) - d * 0.8 - _forza_vicina(h2, 1 - lato, 3) * 0.7
		if Mappa.citta_maggiore(h2) and m.controllore(h2) == lato:
			v += 3.0
		if v > bv:
			bv = v
			best = h2
	return best

## Trasforma un'intenzione in un'azione valida per il motore
func _concretizza(p: Dictionary) -> Dictionary:
	var lato: int = m.s["lato"]
	if p["tipo"] == "cavalleria":
		return _cavalleria_sola(lato)
	var capo: String = p["capo"]
	if not m.s["capi"].has(capo):
		return {}
	var c: Dictionary = m.s["capi"][capo]
	if c["h"] == "" or c["h"] != p["da"] and p["tipo"] != "raggiungi":
		return {}
	var h: String = c["h"]
	if p["tipo"] == "raggiungi":
		if m.sp_in(h, lato) > 0:
			return {}
		var dest := _truppe_senza_capo(h, lato, c["n"])
		if dest == "":
			return {}
		var rag := m.raggiungibili(capo, {})
		if rag.has(dest):
			return {"a": "muovi", "capo": capo, "porta": {}, "verso": dest, "fm": 0}
		return _verso_migliore(capo, {}, rag, campo(dest), lato, dest, false)
	# truppe al seguito: la fanteria del suo colore e la cavalleria, fino al massimo
	var porta := _truppe(capo, h, lato)
	if porta.is_empty() and m.sp_in(h, lato) > 0:
		return {}
	# guarnigione: se la città è obiettivo da difendere e il nemico è vicino, lascia qualcuno
	var verso: String = p["verso"]
	var fm := 0
	if not inverno_freddo():
		fm = 2 if p["tipo"] in ["esercito", "difesa"] else 1
	if carattere == 0:
		fm = mini(fm, 1)
	var rag2 := m.raggiungibili(capo, porta, fm)
	if rag2.is_empty():
		return {}
	var d := _verso_migliore(capo, porta, rag2, campo(verso), lato, verso, p["tipo"] == "esercito")
	return d

func inverno_freddo() -> bool:
	return m.inverno()

func _truppe(capo: String, h: String, lato: int) -> Dictionary:
	var c: Dictionary = m.s["capi"][capo]
	if int(c["mp"]) > 0:
		return {}
	var max_sp := m.max_porta(capo)
	var porta := {}
	var tot := 0
	var ids := m.unita_in(h, lato, true)
	ids.sort_custom(func(a, b):
		var ua: Dictionary = m.s["unita"][a]
		var ub: Dictionary = m.s["unita"][b]
		return Dati.morale(ua["n"], ua["s"], ua["t"]) > Dati.morale(ub["n"], ub["s"], ub["t"]))
	# lascia una guarnigione nelle città obiettivo minacciate (le truppe di morale più basso)
	var resta := 0
	if Mappa.ha_citta(h) and m.controllore(h) == lato and _forza_vicina(h, 1 - lato, 6) > 0:
		var ob: Dictionary = m.scen["obiettivi"][1 - lato]
		if ob.has(Mappa.nome_citta(h)) or Mappa.tipo_citta(h) == "capitale":
			resta = 2
	var disp := {}
	for id in ids:
		var u: Dictionary = m.s["unita"][id]
		if u["mo"]:
			continue
		if not Dati.e_cavalleria(u["t"]) and u["n"] != c["n"]:
			continue
		disp[id] = int(u["sp"])
	for i in range(ids.size() - 1, -1, -1):
		var id: String = ids[i]
		if resta <= 0:
			break
		if disp.has(id) and not Dati.e_cavalleria(m.s["unita"][id]["t"]):
			var lascia := mini(resta, int(disp[id]))
			disp[id] = int(disp[id]) - lascia
			resta -= lascia
	for id in ids:
		if not disp.has(id):
			continue
		var n := mini(int(disp[id]), max_sp - tot)
		if n > 0:
			porta[id] = n
			tot += n
		if tot >= max_sp:
			break
	return porta

## Sceglie la destinazione fra quelle raggiungibili: più vicina al bersaglio, con buone battaglie
func _verso_migliore(capo: String, porta: Dictionary, rag: Dictionary, cd: Dictionary, lato: int, bersaglio: String, attacca: bool) -> Dictionary:
	var best := ""
	var bv := -INF
	var g := m.info_gruppo(capo, porta)
	var forza: int = g.get("sp", 0)
	var d0: int = cd.get(g.get("da", ""), 9999)
	for h in rag:
		var r: Dictionary = rag[h]
		var d: int = cd.get(h, 9999)
		if d >= 9999:
			continue
		var v := float(d0 - d) * 2.0
		# marcia forzata: costa logoramento e rischio
		v -= float(r["fm"]) * 2.4
		if m.nemico_fuori(h, lato):
			v += 6.0  # travolgimento
		# vicino al nemico: buono se il rapporto è favorevole
		var vicino_nemico := 0
		for vv in Mappa.vicini(h):
			vicino_nemico = maxi(vicino_nemico, m.sp_in(vv[0], 1 - lato))
		if vicino_nemico > 0:
			var mia := forza + m.sp_in(h, lato)
			var rapp := float(mia) / float(vicino_nemico)
			if rapp >= 1.5:
				v += 4.0 if attacca else 2.0
			elif rapp < 1.0:
				v -= 6.0
		# logoramento: evitare grandi ammassi lontano dalla battaglia
		var tot := forza + m.sp_in(h, lato)
		if tot > 12 and vicino_nemico == 0:
			v -= (tot - 12) * 0.25
		if Mappa.area(h) in [1, 4]:
			v -= 0.3
		# fuori rifornimento (lontano dalle fonti): penalità
		if not _vicino_rifornimento(h, lato):
			v -= 3.0
		if h == bersaglio:
			v += 1.0
		if v > bv:
			bv = v
			best = h
	if best == "" or bv < 0.5:
		return {}
	return {"a": "muovi", "capo": capo, "porta": porta, "verso": best, "fm": rag[best]["fm"]}

func _vicino_rifornimento(h: String, lato: int) -> bool:
	var r: Dictionary = m.s["rifornimento"].get(str(lato), {})
	for naz in r:
		if r[naz].has(h):
			return true
		for v in Mappa.vicini(h):
			if r[naz].has(v[0]):
				return true
	return false

func _truppe_senza_capo(h0: String, lato: int, naz: String) -> String:
	var best := ""
	var bd := INF
	var c := campo(h0)
	for h in m.esagoni_di(lato):
		if not m.capi_in(h, lato).is_empty():
			continue
		var ok := false
		for id in m.unita_in(h, lato, true):
			if m.s["unita"][id]["n"] == naz:
				ok = true
		if not ok:
			continue
		var d: float = c.get(h, 9999)
		if d < bd:
			bd = d
			best = h
	return best

func _cavalleria_sola(lato: int) -> Dictionary:
	# la cavalleria senza capo raggiunge il capo amico più vicino
	for id in m.s["unita"]:
		var u: Dictionary = m.s["unita"][id]
		if m.lato_unita(u) != lato or u["mo"] or u["in"] or not Dati.e_cavalleria(u["t"]):
			continue
		if not m.capi_in(u["h"], lato).is_empty():
			continue
		var rag := m.raggiungibili("", {id: int(u["sp"])}, 0)
		var best := ""
		var bd := INF
		for h in rag:
			if m.capi_in(h, lato).is_empty() or m.nemico_fuori(h, lato):
				continue
			var d: float = rag[h]["mp"]
			if d < bd:
				bd = d
				best = h
		if best != "":
			return {"a": "muovi", "capo": "", "porta": {id: int(u["sp"])}, "verso": best, "fm": 0}
		# segna come "mossa" per non riprovare: si ferma
	return {}

# =============================================================================================
# Combattimento

func _stima(da: String, su: String, lato: int) -> float:
	var mia := float(m.sp_in(da, lato, true))
	var sua := float(m.sp_in(su, 1 - lato, true))
	if da == su or (sua == 0 and m.sp_in(su, 1 - lato, false, true) > 0):
		sua = float(m.sp_in(su, 1 - lato, false, true)) * 2.0
	# rinforzi probabili
	for v in Mappa.vicini(su):
		if v[0] != da:
			mia += m.sp_in(v[0], lato, true) * 0.35
			sua += m.sp_in(v[0], 1 - lato, true) * 0.35
	var cm := _miglior_capo(da, lato)
	var cs := _miglior_capo(su, 1 - lato)
	var vantaggio := (cm - cs) * 0.15
	var t: int = Dati.MOD_TERRENO.get(Mappa.terreno(su), 0)
	if Mappa.fiume_tra(da, su):
		t += Dati.MOD_FIUME
	vantaggio -= t * 0.08
	return mia / maxf(0.5, sua) * (1.0 + vantaggio)

func _miglior_capo(h: String, lato: int) -> int:
	var best := 0
	for id in m.capi_in(h, lato):
		best = maxi(best, int(m.s["capi"][id]["v"]))
	return best

func _dichiara(rq: Dictionary) -> Dictionary:
	var lato: int = rq["lato"]
	var dichiarati := {}
	for b in m.s["batt"]:
		dichiarati[b["dif"]] = true
	var best := []
	var bv := 0.0
	var soglia := 1.45 if carattere == 1 else (1.8 if carattere == 0 else 1.2)
	for p in m.attacchi_possibili():
		if dichiarati.has(p[1]):
			continue
		var st := _stima(p[0], p[1], lato)
		# niente attacchi da esagoni già usati
		var usato := false
		for b in m.s["batt"]:
			if b["att"] == p[0]:
				usato = true
		if usato:
			continue
		# città che si chiuderà in fortezza: serve forza per assalto o un assedio rifornito
		if Mappa.ha_citta(p[1]) and m.controllore(p[1]) == 1 - lato:
			var dif := m.sp_in(p[1], 1 - lato)
			if dif <= Dati.capienza(Mappa.tipo_citta(p[1])) and m.sp_in(p[0], lato, true) < dif * 2:
				continue
		if st >= soglia and st > bv:
			bv = st
			best = p
	if not best.is_empty():
		return {"a": "attacco", "da": best[0], "su": best[1]}
	return {"a": "fine"}

func _citta(rq: Dictionary) -> String:
	var b: Dictionary = m.s["batt"][int(rq["b"])]
	var lato: int = rq["lato"]
	var mia := m.sp_in(b["dif"], lato, true)
	var sua := m.sp_in(b["att"], 1 - lato, true)
	var cap := Dati.capienza(Mappa.tipo_citta(b["dif"]))
	if sua >= mia * 1.5 and mia <= cap + 2:
		return "dentro"
	return "fuori"

func _assalto(rq: Dictionary) -> String:
	var b: Dictionary = m.s["batt"][int(rq["b"])]
	var lato: int = rq["lato"]
	var mia := m.sp_in(b["att"], lato, true)
	var dentro := m.sp_in(b["dif"], 1 - lato, false, true)
	m.calcola_rifornimento(lato)
	var riforniti := 0
	for id in m.unita_in(b["att"], lato, true):
		if m.rifornita(m.s["unita"][id], lato):
			riforniti += int(m.s["unita"][id]["sp"])
	if mia >= dentro * 3:
		return "assalto"
	if riforniti >= dentro + 1:
		return "assedio"
	if mia >= dentro * 2 and carattere > 0:
		return "assalto"
	return "rinuncia"

func _rapporto_corrente(b: Dictionary, lato: int) -> float:
	var mia := float(m._sp_battaglia(b, lato))
	var sua := float(m._sp_battaglia(b, 1 - lato))
	if b["tipo"] == "assalto":
		if lato == int(b["ld"]):
			mia *= 2.0
		else:
			sua *= 2.0
	return mia / maxf(0.5, sua)

func _continua(rq: Dictionary) -> String:
	var b: Dictionary = m.s["batt"][int(rq["b"])]
	var lato: int = rq["lato"]
	var r := _rapporto_corrente(b, lato)
	var mor_mia := m._morale_lato(b, lato)
	var mor_sua := m._morale_lato(b, 1 - lato)
	var round_n := int(m.s["cb"]["r"])
	if round_n >= 5:
		return "interrompi"
	if mor_sua == 0:
		return "continua"
	if r >= 1.5 and mor_mia >= 1:
		return "continua"
	if r >= 1.0 and mor_mia > mor_sua:
		return "continua"
	return "interrompi"

func _resta(rq: Dictionary) -> String:
	var b: Dictionary = m.s["batt"][int(rq["b"])]
	var lato: int = rq["lato"]
	var r := _rapporto_corrente(b, lato)
	var mor_mia := m._morale_lato(b, lato)
	if r < 0.5 or (r < 0.8 and mor_mia <= 1):
		return "ritirati"
	return "resta"
