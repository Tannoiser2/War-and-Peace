extends SceneTree
## Prova delle regole facoltative: manovra sul retro, matrice tattica, carica, Guardia
func _init() -> void:
	var mo := Motore.new()
	mo.nuova({"seed": 5, "scen": "1805", "opzioni": {"matrice": true, "aggiramento": true, "carica": true, "guardia": true}})
	var ulm := Mappa.hex("Ulm")
	var vic: Array = Mappa.vicini(ulm).map(func(v): return v[0])
	var att: String = vic[0]
	var lato := ""
	for h in vic:
		if h != att and not Mappa.adiacenti(h, att):
			lato = h
			break
	# sgombera e prepara: Napoleone con 6 fanteria e la Guardia in att, Lannes con 3 in lato
	for id in mo.s["unita"].keys():
		if mo.s["unita"][id]["h"] in [att, lato]:
			mo.s["unita"].erase(id)
	var nap := ""
	var lan := ""
	for id in mo.s["capi"]:
		if mo.s["capi"][id]["nome"] == "Napoleon": nap = id
		if mo.s["capi"][id]["nome"] == "Lannes": lan = id
	mo.s["capi"][nap]["h"] = att
	mo.s["capi"][lan]["h"] = lato
	mo._nuova_unita("FR", "", "I", 6, att)
	mo._nuova_unita("FR", "", "GI", 2, att)
	mo._nuova_unita("FR", "", "C", 2, att)
	mo._nuova_unita("FR", "", "I", 3, lato)
	mo.s["fase"] = "dichiara"
	mo.s["lato"] = 0
	print("attacco da ", Mappa.nome(att), " su Ulm; aggiramento da ", Mappa.nome(lato))
	print("dichiara ", mo.applica({"a": "attacco", "da": att, "su": ulm}))
	mo.applica({"a": "fine"})
	var guard := 0
	while mo.s["fase"] == "battaglie" and guard < 60:
		guard += 1
		var rq := mo.richiesta()
		var v: String = rq["opzioni"][0]
		if rq["k"] == "tattica":
			v = "charge" if rq["lato"] == 0 else "skirmish"
		if rq["k"] == "citta":
			v = "fuori"
		print("RQ ", rq["k"], " lato ", rq["lato"], " ", rq["opzioni"], " -> ", v)
		mo.applica({"a": "scelta", "v": v})
		for e in mo.eventi:
			if e["k"] == "battaglia":
				print("   mods ", e["rep"]["mods"], " tiro ", e["rep"]["tiro"], " ris ", e["rep"]["ris"])
	for l in mo.s["log"].slice(-12):
		print("LOG ", l)
	quit()
