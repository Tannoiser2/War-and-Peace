extends SceneTree
## Prova delle carte evento: a ogni richiesta i due lati hanno la mano piena di carte a caso,
## così si esercitano tutte le finestre e gli effetti. Conta le carte giocate.
## godot --headless --path . -s res://tests/carte.gd -- [partite] [scenario]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 2
	var sc: String = args[1] if args.size() > 1 else "1805"
	var giocate := {}
	for p in n:
		var mo := Motore.new()
		mo.nuova({"seed": p * 31 + 7, "scen": sc, "opzioni": {"carte": true}})
		var ia := [IA.new(mo), IA.new(mo)]
		var passi := 0
		var rng := RandomNumberGenerator.new()
		rng.seed = p
		var ids: Array = Carte.DATI.keys()
		while not mo.finita() and passi < 5000:
			for l in [0, 1]:
				while mo.mano(l).size() < 4:
					mo.s["carte"]["mano"][l].append(ids[rng.randi_range(0, ids.size() - 1)])
			var rq := mo.richiesta()
			if rq.is_empty():
				push_error("nessuna richiesta, fase " + str(mo.s["fase"]))
				break
			var d: Dictionary = ia[int(rq["lato"])].decidi(rq)
			if rq["k"] in ["carta", "reazione"] and d["v"] != "passo":
				var k := str(d["v"]).split("@")[0]
				giocate[k] = giocate.get(k, 0) + 1
			if not mo.applica(d):
				print("RIFIUTATA ", rq, " ", d)
				if not mo.applica({"a": "fine"}):
					break
			passi += 1
		print("partita %d: %s passi %d | %s" % [p, "FINITA" if mo.finita() else "NON FINITA", passi, mo.s["esito"].get("perche", "")])
	var k := giocate.keys()
	k.sort()
	for c in k:
		print("  ", c, " ", giocate[c])
	var mai := Carte.DATI.keys().filter(func(c): return not giocate.has(c))
	print("mai giocate: ", mai)
	quit()
