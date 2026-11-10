extends SceneTree
## Partite automatiche tutte IA: controlla che finiscano e mostra gli esiti.
## godot --headless --path . -s res://tests/sim.gd -- [partite]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 3
	var sc: String = args[1] if args.size() > 1 else "1805"
	var vinte := {-1: 0, 0: 0, 1: 0}
	var t0 := Time.get_ticks_msec()
	for p in n:
		var mo := Motore.new()
		mo.nuova({"seed": p * 7919 + 3, "scen": sc})
		var ia := [IA.new(mo), IA.new(mo)]
		var passi := 0
		var conta := {}
		while not mo.finita() and passi < 4000:
			var rq := mo.richiesta()
			if rq.is_empty():
				push_error("nessuna richiesta, fase " + str(mo.s["fase"]))
				break
			var d: Dictionary = ia[int(rq["lato"])].decidi(rq)
			conta[rq["k"]] = conta.get(rq["k"], 0) + 1
			if not mo.applica(d):
				print("RIFIUTATA ", rq, " ", d)
				# per non bloccarsi: fine fase
				if not mo.applica({"a": "fine"}):
					break
			passi += 1
		var e: Dictionary = mo.s["esito"]
		vinte[int(e.get("vince", -1))] += 1
		print("partita %d: %s passi %d | %s | PV %s | PF fr %d all %d | %s" % [p, "FINITA" if mo.finita() else "NON FINITA", passi, e.get("perche", ""), str(mo.s["pv"]), mo.sp_lato(0), mo.sp_lato(1), str(conta)])
		if p == 0 or "--log" in args:
			for l in mo.s["log"]:
				print("   ", l)
	print("esiti (pareggi, Francia, Coalizione): ", vinte, " tempo ms ", Time.get_ticks_msec() - t0)
	quit()
