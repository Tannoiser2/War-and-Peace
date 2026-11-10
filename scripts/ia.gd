## Intelligenza artificiale: muove eserciti verso obiettivi e nemici, cerca battaglie favorevoli
## (rapporto di forze, capi, morale, terreno), concentra le forze come un "bataillon carré",
## tiene conto del logoramento e del rifornimento, decide assedi, assalti e ritirate.
## Principi presi dalle strategie dei giocatori esperti (articolo del designer "Napoleon's Empire"
## su The General e discussioni dei giocatori):
## - corpi di 5-10 PF separati per contenere il logoramento, riuniti solo per la battaglia;
## - Napoleone vale molto più dei suoi punti forza: lo si evita, si colpiscono i corpi lontani da lui;
## - marcia forzata solo quando porta a una battaglia o a un obiettivo decisivo;
## - nel 1805 il Francese distrugge subito l'armata di Ulm e corre su Vienna; l'Austriaco difende Vienna;
## - nel 1813 l'Alleato scappa al primo turno, poi colpisce i corpi isolati; il Francese, se gli
##   Alleati non sono stati spezzati quando entra l'Austria, si ammassa nelle città del nord;
## - si trincerano i corpi fermi vicino al nemico, non si inseguono le piccole guarnigioni lontane.
class_name IA
extends RefCounted

var m: Motore
var piano: Array = []
var chiave := ""
var _campi := {}
## 0 = prudente, 1 = normale, 2 = aggressiva
var carattere := 1
var _mare_fatto := {}
## Catene di depositi: esagono -> nazione (posizioni dove serve un punto forza per il rifornimento)
var catena := {}
## nazione -> depositi ancora vuoti, dal lato delle fonti verso l'armata
var vuoti := {}
var _catena_fatta := {}

## Prove di confronto: WP_NO_<NOME> spegne un comportamento, WP_IA_VECCHIA=<lato> li spegne tutti per un lato
func _attivo(nome: String) -> bool:
	# prudenza (riunirsi prima dell'obiettivo, evitare eserciti più forti): nelle prove rallenta
	# troppo l'attaccante; resta solo per i lati che lo scenario indica come "prudenti"
	if nome in ["RADUNO", "PERICOLO"] and not int(m.s["lato"]) in m.scen.get("ia", {}).get("prudente", []):
		return false
	if OS.get_environment("WP_NO_" + nome) != "":
		return false
	var v := OS.get_environment("WP_IA_VECCHIA")
	return v == "" or int(v) != int(m.s["lato"])

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
		"contro":
			return {"a": "scelta", "v": _contro(rq)}
		"navale":
			return _navale(rq)
	return {"a": "fine"}

# =============================================================================================
# Movimento

func _movimento(rq: Dictionary) -> Dictionary:
	var sb := _sbarco(int(rq["lato"]))
	if not sb.is_empty():
		return sb
	var k := "%d|%d|%d" % [m.s["turno"], m.s["lato"], 0]
	if k != chiave:
		chiave = k
		_campi.clear()
		piano = []
		_pianifica(int(rq["lato"]))
	if not _mare_fatto.has(k):
		var vm := _via_mare(int(rq["lato"]))
		if not vm.is_empty():
			return vm
		_mare_fatto[k] = true
	if not _catena_fatta.has(k):
		var cc := _riempi_catena(int(rq["lato"]))
		if not cc.is_empty():
			return cc
		_catena_fatta[k] = true
	while not piano.is_empty():
		var p: Dictionary = piano.pop_front()
		var d := _concretizza(p)
		if not d.is_empty():
			if p["tipo"] == "cavalleria" or p["tipo"] == "trincee":
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

func _forza_vicina(h0: String, lato: int, raggio: int) -> float:
	var t := 0.0
	var c := campo(h0)
	for h in m.esagoni_di(lato):
		if c.get(h, 9999) <= raggio:
			t += forza(h, lato)
	return t

## Forza "percepita" di un esagono: Napoleone (e Wellington) la moltiplicano, i buoni capi la aumentano
func forza(h: String, lato: int) -> float:
	var sp := float(m.sp_in(h, lato))
	var best := 0
	for id in m.capi_in(h, lato):
		best = maxi(best, int(m.s["capi"][id]["v"]))
	var f := 1.0 + 0.08 * best
	if best >= 3:
		f = 1.4
	return sp * f

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
		if c["h"] == "" or m.lato_capo(c) != lato or c["morto"] or c.get("nave", false):
			continue
		capi.append(id)
	capi.sort_custom(func(a, b):
		var ca: Dictionary = m.s["capi"][a]
		var cb: Dictionary = m.s["capi"][b]
		return int(ca["v"]) * 100 + m.sp_in(ca["h"], lato) > int(cb["v"]) * 100 + m.sp_in(cb["h"], lato))
	var assegnati := {}
	# capi "in più" (nella pila ci sono più capi di quanti servano a portare le truppe) e capi quasi
	# soli vanno a prendere le truppe rimaste ferme senza capo (rinforzi, guarnigioni liberate)
	catena.clear()
	vuoti.clear()
	if _attivo("CATENE"):
		_pianifica_catene(lato)
	# convogli: un capo minore con fanteria ferma dentro il rifornimento porta i depositi lungo la catena
	var convogli := _convogli(capi, lato)
	for id in convogli:
		piano.append({"capo": id, "da": m.s["capi"][id]["h"], "verso": convogli[id], "tipo": "catena"})
	var raccoglitori := _raccolta(capi.filter(func(x): return not convogli.has(x)), lato) if _attivo("RACCOLTA") else {}
	for id in convogli:
		raccoglitori[id] = convogli[id]
	for id in raccoglitori:
		if not convogli.has(id):
			piano.append({"capo": id, "da": m.s["capi"][id]["h"], "verso": raccoglitori[id], "tipo": "raccogli"})
	# il capo migliore di ogni esagono sceglie il bersaglio, gli altri capi dello stesso esagono
	# lo seguono (bataillon carré: corpi separati che convergono sullo stesso obiettivo)
	var scelto_qui := {}
	for id in capi:
		if raccoglitori.has(id):
			continue
		var c: Dictionary = m.s["capi"][id]
		var h: String = c["h"]
		var bersaglio: Array
		var ax := _bersaglio_asse(h, lato, c["n"])
		if not ax.is_empty():
			bersaglio = ax
		elif scelto_qui.has(h):
			bersaglio = scelto_qui[h]
		else:
			bersaglio = _scegli_bersaglio(h, lato, obiettivi, difese, assegnati)
			scelto_qui[h] = bersaglio
		if bersaglio.is_empty():
			continue
		assegnati[bersaglio[0]] = assegnati.get(bersaglio[0], 0) + 1
		piano.append({"capo": id, "da": h, "verso": bersaglio[0], "tipo": bersaglio[2]})
	# capi senza truppe: raggiungono le truppe senza capo più vicine
	for id in capi:
		var c: Dictionary = m.s["capi"][id]
		if m.sp_in(c["h"], lato) == 0 and not raccoglitori.has(id):
			piano.append({"capo": id, "da": c["h"], "verso": "", "tipo": "raggiungi"})
	if OS.get_environment("WP_DEBUG_IA") != "":
		var tot := 0
		var senza := 0
		for id in m.s["unita"]:
			var u: Dictionary = m.s["unita"][id]
			if m.lato_unita(u) == lato and u["h"] != "":
				tot += int(u["sp"])
				if not m.rifornita(u, lato):
					senza += int(u["sp"])
		print("RIF t%d l%d PF %d senza rifornimento %d" % [m.s["turno"], lato, tot, senza])
		var det := {}
		for id in m.s["unita"]:
			var u: Dictionary = m.s["unita"][id]
			if m.lato_unita(u) == lato and u["h"] != "" and not m.rifornita(u, lato):
				var kk: String = "%s@%s" % [u["n"], Mappa.nome(u["h"])]
				det[kk] = int(det.get(kk, 0)) + int(u["sp"])
		print("   SENZA ", det)
		if OS.get_environment("WP_DEBUG_IA") == "2":
			for h in m.esagoni_di(lato):
				var t := {}
				for id in m.unita_in(h, lato):
					var u: Dictionary = m.s["unita"][id]
					var kk: String = "%s%s" % [u["n"], u["t"]]
					t[kk] = int(t.get(kk, 0)) + int(u["sp"])
				var cc := []
				for c in m.capi_in(h, lato):
					cc.append("%s(%s)" % [m.s["capi"][c]["nome"], m.s["capi"][c]["n"]])
				print("   PILA %s %s %s" % [Mappa.nome(h), str(t), ",".join(cc)])
		for p in piano:
			var cc: Dictionary = m.s["capi"][p["capo"]]
			print("PIANO t%d l%d %s (%dPF) %s -> %s [%s]" % [m.s["turno"], lato, cc["nome"], m.sp_in(cc["h"], lato), Mappa.nome(cc["h"]), Mappa.nome(p["verso"]) if p["verso"] != "" else "-", p["tipo"]])
	# cavalleria senza capo: con il capo più vicino o resta
	piano.append({"capo": "", "tipo": "cavalleria"})
	piano.append({"capo": "", "tipo": "trincee"})

## Truppe ferme senza capo: esagono -> [nazione, punti forza di fanteria]
func _truppe_ferme(lato: int) -> Dictionary:
	var out := {}
	for h in m.esagoni_di(lato):
		if not m.capi_in(h, lato).is_empty() or catena.has(h):
			continue
		var per_naz := {}
		for id in m.unita_in(h, lato, true):
			var u: Dictionary = m.s["unita"][id]
			if u["mo"] or Dati.e_cavalleria(u["t"]) or u["t"] == "P":
				continue
			per_naz[u["n"]] = int(per_naz.get(u["n"], 0)) + int(u["sp"])
		var best := ""
		for n in per_naz:
			if best == "" or per_naz[n] > per_naz[best]:
				best = n
		if best == "":
			continue
		var sp: int = per_naz[best]
		# una guarnigione minacciata di una città da tenere resta dov'è
		if Mappa.ha_citta(h) and _forza_vicina(h, 1 - lato, 5) > 0 and sp <= 3:
			continue
		if sp >= 3:
			out[h] = [best, sp]
	return out

## Assegna i capi liberi alle truppe ferme: capo -> esagono delle truppe
func _raccolta(capi: Array, lato: int) -> Dictionary:
	var ferme := _truppe_ferme(lato)
	if ferme.is_empty():
		return {}
	# capi liberi: quelli oltre il necessario in una pila e quelli con meno di 2 PF
	var liberi := []
	var per_hex := {}
	for id in capi:
		var h: String = m.s["capi"][id]["h"]
		if not per_hex.has(h):
			per_hex[h] = []
		per_hex[h].append(id)
	for h in per_hex:
		var lista: Array = per_hex[h]
		var sp := m.sp_in(h, lato, true)
		var portati := 0
		for id in lista:
			if portati >= sp or sp < 2:
				liberi.append(id)
			portati += m.max_porta(id)
	var out := {}
	var ordine := ferme.keys()
	ordine.sort_custom(func(a, b): return int(ferme[a][1]) > int(ferme[b][1]))
	for h in ordine:
		var cd := campo(h)
		var best := ""
		var bd := 14
		for id in liberi:
			if out.has(id) or m.s["capi"][id]["n"] != ferme[h][0]:
				continue
			# i buoni capi comandano gli eserciti: a raccogliere vanno i generici e i mediocri
			if int(m.s["capi"][id]["v"]) >= 2:
				continue
			var d: int = cd.get(m.s["capi"][id]["h"], 9999)
			if d < bd:
				bd = d
				best = id
		if best != "":
			out[best] = h
	return out

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
	# città che lo scenario chiede di difendere (es. Vienna per la Coalizione nel 1805)
	var extra: Dictionary = m.scen.get("ia", {}).get("difendi", [{}, {}])[lato]
	for nome in extra:
		var h := Mappa.hex(nome)
		if m.controllore(h) == lato or m.controllore(h) < 0:
			var minaccia := _forza_vicina(h, 1 - lato, 12)
			var difesa := _forza_vicina(h, lato, 1)
			if minaccia > difesa * 0.8:
				out.append([h, float(extra[nome]) * 1.5])
	return out

func _ammassare(lato: int) -> String:
	var lista: Array = m.scen.get("ia", {}).get("ammassa", [])
	if lato != 0 or lista.is_empty():
		return ""
	var debole := float(m.sp_lato(0)) < float(m.sp_lato(1)) * 0.75
	var austria: bool = not m.s["neutrali"].has("AU")
	if not (debole and (austria or int(m.s["turno"]) >= 5)):
		return ""
	for nome in lista:
		var h := Mappa.hex(nome)
		if m.controllore(h) == 0 and not m.s["assedi"].has(h):
			return h
	return ""

## Strategia di scenario: le nazioni indicate si radunano in un punto e poi marciano insieme sull'obiettivo
func _asse(lato: int) -> Dictionary:
	var a: Dictionary = m.scen.get("ia", {}).get("asse", {})
	if a.is_empty() or int(a["lato"]) != lato or not _attivo("ASSE"):
		return {}
	return a

func _bersaglio_asse(h: String, lato: int, naz: String) -> Array:
	var a := _asse(lato)
	if a.is_empty() or not naz in a["naz"]:
		return []
	var ob := Mappa.hex(str(a["obiettivo"]))
	if m.controllore(ob) == lato and not m.nemico_fuori(ob, lato):
		return []
	if int(m.s["turno"]) < int(a["parti"]):
		var r := m._risolvi_hex(str(a["raduno"]))
		if r == "" or campo(r).get(h, 9999) <= 2:
			return [h, 0.0, "fermo"]
		return [r, 20.0, "raduno"]
	return [ob, 60.0, "asse"]

func _scegli_bersaglio(h: String, lato: int, obiettivi: Array, difese: Array, assegnati: Dictionary) -> Array:
	var naz0 := ""
	for id in m.capi_in(h, lato):
		naz0 = m.s["capi"][id]["n"]
		break
	var ax := _bersaglio_asse(h, lato, naz0)
	if not ax.is_empty():
		return ax
	var rad := _ammassare(lato)
	if rad != "" and h != rad:
		return [rad, 10.0, "difesa"]
	var mia := forza(h, lato) + _forza_vicina(h, lato, 4) * 0.5
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
			var sua := forza(t, 1 - lato) + _forza_vicina(t, 1 - lato, 3) * 0.6
			# piccole guarnigioni lontane: non vale la pena inseguirle
			if m.sp_in(t, 1 - lato) <= 2 and d > 6:
				continue
			var rapp := float(mia) / maxf(1.0, sua)
			if rapp < 1.2:
				val = -val * (1.0 if carattere < 2 else 0.4)
			elif rapp >= 2.0:
				val *= 1.6
		else:
			var dif := forza(t, 1 - lato) + _forza_vicina(t, 1 - lato, 3) * 0.6
			var amici := _forza_vicina(h, lato, 6)
			if dif > maxf(mia, amici * 0.7) * 0.9:
				val *= 0.35
			# col passare dei mesi le città obiettivo contano sempre di più
			val *= 1.0 + float(m.s["turno"]) / float(m.scen["turni"])
		val -= assegnati.get(t, 0) * 1.5
		var score := val * 10.0 / (6.0 + d)
		# obiettivo decisivo (es. Vienna): lo si insegue anche da lontano
		if o[2] == "citta" and float(o[1]) >= 30.0:
			score = val * 10.0 / (6.0 + d * 0.4)
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
	# obiettivo decisivo ben difeso: prima ci si riunisce al grosso più vicino (niente sconfitte separate)
	if _attivo("RADUNO") and not best.is_empty() and best[2] == "citta" and _valore_obiettivo(best[0], lato) >= 8:
		var t: String = best[0]
		var dif := forza(t, 1 - lato) + _forza_vicina(t, 1 - lato, 4) * 0.8
		var mia_loc := forza(h, lato) + _forza_vicina(h, lato, 2) * 0.8 - forza(h, lato) * 0.8
		if dif > mia_loc * 1.1 and dif > 6.0:
			var cd := campo(t)
			var dt: int = cd.get(h, 9999)
			var raduno := ""
			var rv := -INF
			var mia_qui := forza(h, lato)
			for h2 in m.esagoni_di(lato):
				# ci si riunisce solo a un gruppo più forte: il più forte va avanti e gli altri lo seguono
				var f2 := forza(h2, lato)
				if h2 == h or f2 < 4.0 or f2 < mia_qui or (f2 == mia_qui and h2 < h):
					continue
				var d2: int = c.get(h2, 9999)
				if d2 > 12:
					continue
				var v2 := forza(h2, lato) - d2 * 0.6 - float(cd.get(h2, 9999)) * 0.3
				if cd.get(h2, 9999) > dt + 3:
					continue
				if v2 > rv:
					rv = v2
					raduno = h2
			if raduno != "":
				best = [raduno, best[1], "raduno"]
	# troppo debole: si ritira verso le forze amiche più grandi
	var minaccia := _forza_vicina(h, 1 - lato, 4)
	if minaccia > mia * 1.5 and m.sp_in(h, lato) > 0:
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
	if p["tipo"] == "trincee":
		return _trincee(lato)
	var capo: String = p["capo"]
	if not m.s["capi"].has(capo):
		return {}
	var c: Dictionary = m.s["capi"][capo]
	if c["h"] == "" or c["h"] != p["da"] and not p["tipo"] in ["raggiungi", "raccogli", "catena"]:
		return {}
	var h: String = c["h"]
	if p["tipo"] == "catena":
		return _muovi_convoglio(capo, lato)
	if p["tipo"] == "raccogli":
		var dest: String = p["verso"]
		if h == dest or int(c["mp"]) > 0:
			return {}
		var rag0 := m.raggiungibili(capo, {})
		if rag0.has(dest):
			return {"a": "muovi", "capo": capo, "porta": {}, "verso": dest, "fm": 0}
		return _verso_migliore(capo, {}, rag0, campo(dest), lato, dest, false)
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
		if OS.get_environment("WP_DEBUG_IA") == "2":
			print("SENZA TRUPPE %s a %s mp %d" % [c["nome"], Mappa.nome(h), int(c["mp"])])
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
	if p["tipo"] == "fermo":
		return {}
	var decisivo: bool = float(_valore_obiettivo(verso, lato)) >= 8.0 or p["tipo"] == "asse"
	if decisivo and (not inverno_freddo() or p["tipo"] == "asse"):
		rag2 = m.raggiungibili(capo, porta, 3 if carattere > 0 else 2)
	var d := _verso_migliore(capo, porta, rag2, campo(verso), lato, verso, p["tipo"] == "esercito", decisivo)
	if OS.get_environment("WP_DEBUG_IA") == "2" and d.is_empty():
		print("FERMO %s a %s: porta %s, raggiungibili %d" % [c["nome"], Mappa.nome(h), str(porta), rag2.size()])
	if not d.is_empty() and _attivo("DEPOSITI"):
		var rr := m.raggiungibili(capo, porta, int(d["fm"]))
		var dep := _depositi(capo, porta, rr, str(d["verso"]), lato)
		if not dep.is_empty():
			d["lascia"] = dep
	return d

## Depositi: punti forza di fanteria lasciati lungo la strada perché la catena del rifornimento
## (al massimo 3 punti movimento fra un'unità rifornita e la successiva dello stesso colore) arrivi
## fino alla destinazione
func _depositi(capo: String, porta: Dictionary, rag: Dictionary, verso: String, lato: int) -> Dictionary:
	var c: Dictionary = m.s["capi"][capo]
	var naz: String = c["n"]
	var rif: Dictionary = m.s["rifornimento"].get(str(lato), {}).get(naz, {})
	if rif.has(verso) or rif.is_empty():
		return {}
	var fanteria := 0
	for id in porta:
		var u: Dictionary = m.s["unita"][id]
		if not Dati.e_cavalleria(u["t"]) and not u["t"] in ["GI", "GC"]:
			fanteria += int(porta[id])
	if fanteria < 8:
		return {}
	# vicino al nemico conta la massa: niente depositi
	if _forza_vicina(verso, 1 - lato, 6) > 0:
		return {}
	var strada := m.percorso(rag, verso)
	var da: String = c["h"]
	if not rif.has(da):
		return {}
	strada.push_front(da)
	var mp_di := func(h: String) -> int:
		return 0 if h == da else int(rag[h]["mp"])
	# l'ultimo esagono della strada ancora rifornito: lì il primo deposito, poi uno ogni 3 punti
	var cur := da
	for h in strada:
		if rif.has(h):
			cur = h
	var pc: int = mp_di.call(cur)
	var dep := {}
	for i in 3:
		# basta un'unità dello stesso colore lì o a un esagono di distanza
		var gia := false
		for hx in [cur] + Mappa.vicini(cur).map(func(v): return v[0]):
			for id in m.unita_in(hx, lato):
				if m.s["unita"][id]["n"] == naz and not id in porta:
					gia = true
		if not gia and cur != verso:
			dep[cur] = 1
		if mp_di.call(verso) <= pc + 3:
			if fanteria - dep.size() < 4 or dep.size() > 1:
				return {}
			return dep
		var prossimo := ""
		for h in strada:
			var mh: int = mp_di.call(h)
			if mh > pc and mh <= pc + 3 and h != verso:
				prossimo = h
		if prossimo == "":
			return {}
		cur = prossimo
		pc = mp_di.call(cur)
	return {}


func _valore_obiettivo(h: String, lato: int) -> int:
	return int(m.scen["obiettivi"][lato].get(Mappa.nome_citta(h), 0)) if Mappa.ha_citta(h) else 0

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
func _verso_migliore(capo: String, porta: Dictionary, rag: Dictionary, cd: Dictionary, lato: int, bersaglio: String, attacca: bool, decisivo := false) -> Dictionary:
	var vio: Dictionary = m.scen.get("violazione", {})
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
		v -= float(r["fm"]) * (1.2 if decisivo else 2.4)
		# non violare un neutrale che potrebbe entrare in guerra
		if not vio.is_empty() and lato == int(vio["lato"]) and Mappa.stato(h) in vio["stati"] and not m.s["in_guerra"].has(Mappa.stato(h)):
			v -= 8.0
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
		# pericolo: un esercito nemico più forte a portata di marcia, senza amici vicini (battuti uno alla volta)
		if forza >= 4 and _attivo("PERICOLO"):
			var pr := _pericolo(h, lato, forza, g.get("da", "")) - _pericolo(g.get("da", ""), lato, forza, g.get("da", ""))
			if pr > 0.0:
				v -= minf(8.0, pr * 4.0)
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

## Quanto un esercito sarebbe esposto in un esagono: forza nemica a portata contro forza amica vicina
func _pericolo(h: String, lato: int, forza_mia: int, da: String) -> float:
	if h == "":
		return 0.0
	var nem := _forza_vicina(h, 1 - lato, 5)
	var amici := float(forza_mia) + _forza_vicina(h, lato, 3)
	if da != "" and campo(h).get(da, 9999) <= 3:
		amici -= float(m.sp_in(da, lato))
	amici = maxf(amici, float(forza_mia))
	if nem <= amici * 1.3:
		return 0.0
	return nem / maxf(1.0, amici) - 1.3

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

## Trincera i corpi fermi minacciati dal nemico (non nelle città maggiori)
func _trincee(lato: int) -> Dictionary:
	for h in m.esagoni_di(lato):
		if not m.puo_trincerare(h):
			continue
		var minaccia := _forza_vicina(h, 1 - lato, 4)
		if minaccia > 0 and minaccia >= forza(h, lato) * 0.7:
			return {"a": "trincea", "h": h}
	return {}

func _cavalleria_sola(lato: int) -> Dictionary:
	# la cavalleria senza capo raggiunge il capo amico più vicino
	for id in m.s["unita"]:
		var u: Dictionary = m.s["unita"][id]
		if m.lato_unita(u) != lato or u["mo"] or u["in"] or not Dati.e_cavalleria(u["t"]):
			continue
		if catena.get(u["h"], "") == u["n"]:
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
	for id in m.capi_in(su, 1 - lato):
		if int(m.s["capi"][id]["v"]) >= 3:
			sua *= 1.25
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
		# senza rifornimento si logora ogni mese: meglio tentare l'assalto a una città che conta
		var disperato := _attivo("DISPERATO") and not _stack_rifornito(p[0], lato) and _valore_obiettivo(p[1], lato) >= 5
		# città che si chiuderà in fortezza: serve forza per assalto o un assedio rifornito
		if Mappa.ha_citta(p[1]) and m.controllore(p[1]) == 1 - lato:
			var dif := m.sp_in(p[1], 1 - lato)
			var serve := 1.3 if disperato else 2.0
			if dif <= Dati.capienza(Mappa.tipo_citta(p[1])) and m.sp_in(p[0], lato, true) < dif * serve:
				continue
		var s2 := soglia
		if disperato:
			s2 -= 0.4
		# con Napoleone al comando si attacca anche alla pari (soprattutto Prussiani e Austriaci)
		if _miglior_capo(p[0], lato) >= 3:
			s2 -= 0.3
		if st >= s2 and st > bv:
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
	# senza rifornimento l'assedio è impossibile: si assalta se la città vale la pena
	if _attivo("DISPERATO") and riforniti == 0 and mia >= dentro * 1.3 and _valore_obiettivo(b["dif"], lato) >= 5:
		return "assalto"
	return "rinuncia"

func _stack_rifornito(h: String, lato: int) -> bool:
	for id in m.unita_in(h, lato, true):
		if m.rifornita(m.s["unita"][id], lato):
			return true
	return false

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

## Contrattacco: solo con forze nettamente superiori e morale buono
func _contro(rq: Dictionary) -> String:
	var b: Dictionary = m.s["batt"][int(rq["b"])]
	var lato: int = rq["lato"]
	var r := _rapporto_corrente(b, lato)
	var mor_mia := m._morale_lato(b, lato)
	var mor_sua := m._morale_lato(b, 1 - lato)
	var soglia := 1.6 if carattere < 2 else 1.3
	if r >= soglia and mor_mia >= mor_sua and mor_mia >= 1:
		return "contrattacca"
	return "lascia"

# =============================================================================================
# Flotte, sbarchi e movimenti via mare

var _navi_ferme := {}
var _chiave_navi := ""

## Il miglior obiettivo nemico del lato (città con il valore più alto non ancora presa)
func _obiettivo_principale(lato: int) -> String:
	var best := ""
	var bv := -1.0
	var ob: Dictionary = m.scen["obiettivi"][lato]
	for nome in ob:
		var h := Mappa.hex(nome)
		if h != "" and m.controllore(h) != lato and float(ob[nome]) > bv and m.aperto(h):
			bv = float(ob[nome])
			best = h
	return best

func _navale(rq: Dictionary) -> Dictionary:
	var lato: int = rq["lato"]
	var k := "%d|%d" % [m.s["turno"], lato]
	if k != _chiave_navi:
		_chiave_navi = k
		_navi_ferme.clear()
	# gruppi di navi per posto
	var posti := {}
	for id in m.s["navi"]:
		var nv: Dictionary = m.s["navi"][id]
		if m.lato_nave(nv) != lato or int(nv["mp"]) >= 4:
			continue
		var p := m.posto_nave(id)
		if _navi_ferme.has(p):
			continue
		if not posti.has(p):
			posti[p] = []
		posti[p].append(id)
	for p in posti:
		var ids: Array = posti[p]
		var d := _muovi_flotta(p, ids, lato)
		if not d.is_empty():
			return d
		_navi_ferme[p] = true
	return {"a": "fine"}

func _muovi_flotta(p: String, ids: Array, lato: int) -> Dictionary:
	var trasporti := ids.filter(func(x): return m.s["navi"][x]["t"] == "T")
	var obiettivo := _obiettivo_principale(lato)
	# trasporti in un porto con truppe: si imbarca l'armata e si sbarca vicino all'obiettivo
	if not trasporti.is_empty() and not p.begins_with("@") and obiettivo != "" and Mappa.distanza(p, obiettivo, 8) > 6:
		var carico := {}
		var cap := m.capacita_trasporti(ids)
		var peso := 0
		var unita := m.unita_in(p, lato, true)
		unita.sort_custom(func(a, b): return int(m.s["unita"][a]["sp"]) > int(m.s["unita"][b]["sp"]))
		for id in unita:
			var u: Dictionary = m.s["unita"][id]
			if u["mo"]:
				continue
			var costo := 2 if Dati.e_cavalleria(u["t"]) else 1
			var n := mini(int(u["sp"]), (cap - peso) / costo)
			if n > 0:
				carico[id] = n
				peso += n * costo
		var capi := m.capi_in(p, lato)
		if not carico.is_empty() or not capi.is_empty():
			var dest := m.destinazioni_navali(ids, {"_": 1})
			var best := ""
			var bd := 9999
			for h in dest:
				if h.begins_with("@") or m.nemico_fuori(h, lato) or not m.aperto(h):
					continue
				var dd := Mappa.distanza(h, obiettivo, 14)
				if dd < bd:
					bd = dd
					best = h
			if best != "" and bd < Mappa.distanza(p, obiettivo, 14):
				return {"a": "naviga", "navi": ids, "verso": best, "carico": carico, "capi": capi}
	# squadre: bloccare un porto nemico con navi più deboli, o incrociare dove sono le navi nemiche
	var mie := m.forza_navale(ids)
	if not p.begins_with("@") and m.s["blocchi"].get(p, -1) == lato:
		return {}  # resta a bloccare il porto
	if mie > 0:
		var dest2 := m.destinazioni_navali(ids)
		for h in dest2:
			if not h.begins_with("@") and Mappa.porto(h) and m.controllore(h) == 1 - lato:
				return {"a": "naviga", "navi": ids, "verso": h, "carico": {}, "capi": []}
		var zona_nemica := ""
		for id in m.s["navi"]:
			var nv: Dictionary = m.s["navi"][id]
			if m.lato_nave(nv) == 1 - lato:
				var zs := m.zone_posto(m.posto_nave(id))
				if not zs.is_empty():
					zona_nemica = zs[0]
					break
		if zona_nemica != "" and p != "@" + zona_nemica and dest2.has("@" + zona_nemica):
			return {"a": "naviga", "navi": ids, "verso": "@" + zona_nemica, "carico": {}, "capi": []}
	return {}

## Forze in mare: sbarcano sulla costa più vicina all'obiettivo
func _sbarco(lato: int) -> Dictionary:
	var obiettivo := _obiettivo_principale(lato)
	for r in m.riserve(lato):
		var dest := m.destinazioni_sbarco(r["id"])
		if dest.is_empty():
			continue
		var best := ""
		var bv := INF
		for h in dest:
			var v := float(Mappa.distanza(h, obiettivo, 20)) if obiettivo != "" else 0.0
			v -= float(m.sp_in(h, lato)) * 0.3
			if v < bv:
				bv = v
				best = h
		if best != "":
			return {"a": "sbarca", "r": r["id"], "verso": best}
	return {}

## Movimento via mare dello scenario: le truppe lontane dal fronte si avvicinano all'obiettivo
func _via_mare(lato: int) -> Dictionary:
	var regole := m.regole_mare()
	if regole.is_empty():
		return {}
	var obiettivo := _obiettivo_principale(lato)
	if obiettivo == "":
		return {}
	for h in m.esagoni_di(lato):
		if not Mappa.costiero(h) or _forza_vicina(h, 1 - lato, 4) > 0:
			continue
		var porta := {}
		var tot := 0
		for id in m.unita_in(h, lato, true):
			var u: Dictionary = m.s["unita"][id]
			if u["mo"] or not u["n"] in regole.get("naz", ["EN"]) or u["t"] in ["M", "P"]:
				continue
			var n := mini(int(u["sp"]), int(regole.get("max_sp", 2)) - int(m.s["mare_usato"].get("sp", 0)) - tot)
			if n > 0:
				porta[id] = n
				tot += n
		if porta.is_empty():
			continue
		var capo := ""
		for c in m.capi_in(h, lato):
			if int(m.s["capi"][c]["mp"]) == 0 and m.s["capi"][c]["n"] in regole.get("naz", ["EN"]):
				capo = c
				break
		var dest := m.destinazioni_mare(capo, porta)
		if dest.is_empty() and capo != "":
			capo = ""
			dest = m.destinazioni_mare("", porta)
		var d0 := Mappa.distanza(h, obiettivo, 25)
		var best := ""
		var bd := d0 - 6
		for x in dest:
			var dd := Mappa.distanza(x, obiettivo, 25)
			if dd < bd:
				bd = dd
				best = x
		if best != "":
			return {"a": "mare", "capo": capo, "porta": porta, "verso": best}
	return {}

# =============================================================================================
# Catene di depositi (regola M3c): le armate fuori rifornimento ricevono una fila di punti forza dello
# stesso colore, al massimo 3 punti movimento l'uno dall'altro, dalla fonte più vicina fino a loro.

func _pianifica_catene(lato: int) -> void:
	var rif_l: Dictionary = m.s["rifornimento"].get(str(lato), {})
	# armate senza rifornimento, per nazione (le più grandi per prime)
	var armate := []
	for h in m.esagoni_di(lato):
		var per_naz := {}
		for id in m.unita_in(h, lato, true):
			var u: Dictionary = m.s["unita"][id]
			if not m.rifornita(u, lato):
				per_naz[u["n"]] = int(per_naz.get(u["n"], 0)) + int(u["sp"])
		for naz in per_naz:
			if int(per_naz[naz]) >= 4:
				armate.append([h, naz, int(per_naz[naz])])
	armate.sort_custom(func(a, b): return int(a[2]) > int(b[2]))
	var fatte := {}
	for a in armate:
		var h: String = a[0]
		var naz: String = a[1]
		if int(fatte.get(naz, 0)) >= 3:
			continue
		var rif: Dictionary = rif_l.get(naz, {})
		if rif.is_empty():
			continue
		var cd := campo(h)
		var b := ""
		var bd := 9999
		for x in rif:
			var dx: int = cd.get(x, 9999)
			if dx < bd and m.sp_in(x, 1 - lato) == 0:
				bd = dx
				b = x
		if b == "" or bd > 30:
			continue
		# strada dalla fonte all'armata, scendendo nel campo delle distanze
		var strada := [b]
		var cur := b
		while int(cd.get(cur, 9999)) > 0 and strada.size() < 40:
			var best := ""
			var bv: int = cd[cur]
			for v in Mappa.vicini(cur):
				var n: String = v[0]
				if cd.has(n) and int(cd[n]) < bv and m.sp_in(n, 1 - lato) == 0 and m.aperto(n):
					bv = cd[n]
					best = n
			if best == "":
				break
			strada.append(best)
			cur = best
		if cur != h:
			continue
		# depositi: ognuno entro 3 punti dal precedente, finché l'armata è entro 3 dall'ultimo
		var ultimo: int = cd[b]
		var prec := b
		var nuovi := []
		for i in range(1, strada.size()):
			var p: String = strada[i]
			if ultimo - int(cd[p]) > 3:
				nuovi.append(prec)
				ultimo = cd[prec]
			if ultimo <= 3:
				break
			prec = p
		if ultimo > 3 and ultimo - int(cd[prec]) <= 3 and prec != h:
			nuovi.append(prec)
		for q in nuovi:
			if q == b:
				continue
			catena[q] = naz
			var pieno := false
			for id in m.unita_in(q, lato):
				if m.s["unita"][id]["n"] == naz:
					pieno = true
			if not pieno:
				if not vuoti.has(naz):
					vuoti[naz] = []
				if not q in vuoti[naz]:
					vuoti[naz].append(q)
		fatte[naz] = int(fatte.get(naz, 0)) + 1
	if OS.get_environment("WP_DEBUG_IA") != "":
		for naz in vuoti:
			print("CATENA t%d l%d %s vuoti: %s" % [m.s["turno"], lato, naz, ", ".join(vuoti[naz].map(func(x): return Mappa.nome(x)))])

## Cavalleria libera: va a occupare un deposito vuoto raggiungibile
func _riempi_catena(lato: int) -> Dictionary:
	for naz in vuoti:
		var lista: Array = vuoti[naz]
		for q in lista:
			var pieno := false
			for id in m.unita_in(q, lato):
				if m.s["unita"][id]["n"] == naz:
					pieno = true
			if pieno:
				continue
			for id in m.s["unita"]:
				var u: Dictionary = m.s["unita"][id]
				if u["n"] != naz or m.lato_unita(u) != lato or u["mo"] or u["in"] or not Dati.e_cavalleria(u["t"]):
					continue
				if u["h"] == "" or catena.has(u["h"]):
					continue
				# dalla pila di un'armata si stacca un punto di cavalleria solo se l'armata è grande
				if not m.capi_in(u["h"], lato).is_empty() and m.sp_in(u["h"], lato) < 6:
					continue
				# non si sguarnisce una città minacciata
				if Mappa.ha_citta(u["h"]) and _forza_vicina(u["h"], 1 - lato, 4) > 0:
					continue
				var rag := m.raggiungibili("", {id: 1}, 0)
				if rag.has(q) and not m.nemico_in(q, lato):
					return {"a": "muovi", "capo": "", "porta": {id: 1}, "verso": q, "fm": 0}
	return {}

## Capi minori con fanteria ferma dentro il rifornimento: portano i depositi lungo la catena
func _convogli(capi: Array, lato: int) -> Dictionary:
	var out := {}
	if vuoti.is_empty():
		return out
	var rif_l: Dictionary = m.s["rifornimento"].get(str(lato), {})
	for id in capi:
		var c: Dictionary = m.s["capi"][id]
		var naz: String = c["n"]
		if not vuoti.has(naz) or int(c["v"]) >= 3 or int(c["mp"]) > 0:
			continue
		var h: String = c["h"]
		if not rif_l.get(naz, {}).has(h):
			continue
		var fanteria := 0
		for uid in m.unita_in(h, lato, true):
			var u: Dictionary = m.s["unita"][uid]
			if u["n"] == naz and not Dati.e_cavalleria(u["t"]) and not u["mo"]:
				fanteria += int(u["sp"])
		if catena.get(h, "") == naz:
			fanteria -= 1  # il deposito dove si trova resta
		# solo truppe di seconda linea: non si smonta un'armata vicina al nemico
		if fanteria < 1 or fanteria > 12 or _forza_vicina(h, 1 - lato, 3) > 0:
			continue
		var gia := 0
		for x in out:
			if m.s["capi"][x]["n"] == naz:
				gia += 1
		if gia >= 2:
			continue
		out[id] = vuoti[naz][0]
	return out

## Il convoglio marcia lungo la catena lasciando un punto forza in ogni deposito vuoto che attraversa
func _muovi_convoglio(capo: String, lato: int) -> Dictionary:
	var c: Dictionary = m.s["capi"][capo]
	var naz: String = c["n"]
	var h: String = c["h"]
	var porta := {}
	var tot := 0
	var resta := 1 if catena.get(h, "") == naz else 0
	for uid in m.unita_in(h, lato, true):
		var u: Dictionary = m.s["unita"][uid]
		if u["n"] == naz and not Dati.e_cavalleria(u["t"]) and not u["mo"] and not u["t"] in ["GI", "GC", "P"]:
			var disp := int(u["sp"])
			if resta > 0:
				var k := mini(resta, disp)
				disp -= k
				resta -= k
			var n := mini(disp, m.max_porta(capo) - tot)
			if n > 0:
				porta[uid] = n
				tot += n
	if porta.is_empty():
		return {}
	var rag := m.raggiungibili(capo, porta, 0)
	var lista: Array = vuoti.get(naz, [])
	# il deposito vuoto più lontano raggiungibile, lasciando 1 PF in quelli lungo la strada
	var best := ""
	var bl := {}
	for q in lista:
		if not rag.has(q) or m.nemico_in(q, lato):
			continue
		var strada := m.percorso(rag, q)
		var lascia := {}
		for p in strada:
			if p in lista:
				lascia[p] = 1
		if lascia.size() > tot:
			continue
		if lascia.size() > bl.size() or best == "":
			best = q
			bl = lascia
	if best == "":
		# nessun deposito a portata: ci si avvicina al primo
		if lista.is_empty():
			return {}
		return _verso_migliore(capo, porta, rag, campo(lista[0]), lato, lista[0], false)
	for q in bl:
		lista.erase(q)
	return {"a": "muovi", "capo": capo, "porta": porta, "verso": best, "fm": 0, "lascia": bl}
