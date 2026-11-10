extends SceneTree
func _init() -> void:
	var sc := OS.get_environment("SC")
	var mo := Motore.new()
	mo.nuova({"seed": 1, "scen": sc})
	for l in [0, 1]:
		mo.calcola_rifornimento(l)
		var d := {}
		for id in mo.s["unita"]:
			var u: Dictionary = mo.s["unita"][id]
			if mo.lato_unita(u) == l and u["h"] != "" and not mo.rifornita(u, l):
				var k: String = "%s %s" % [u["n"], Mappa.nome(u["h"])]
				d[k] = int(d.get(k, 0)) + int(u["sp"])
		print(l, " ", d)
		var f := {}
		for naz in ["FR", "AU", "PR", "RU", "EN", "SP"]:
			f[naz] = mo._fonti_naz(naz, mo.lato_di(naz)).map(func(h): return Mappa.nome(h))
		print(f)
	quit()
