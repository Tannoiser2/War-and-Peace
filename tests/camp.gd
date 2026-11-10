extends SceneTree
## Campagna 1805-1815: partita tutta IA per N turni (o fino alla fine) con la cronaca politica
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var turni := int(args[0]) if args.size() > 0 else 12
	var seme := int(args[1]) if args.size() > 1 else 3
	var mo := Motore.new()
	mo.nuova({"seed": seme, "scen": "1805c"})
	var ia := [IA.new(mo), IA.new(mo)]
	var n := 0
	var t0 := Time.get_ticks_msec()
	var conta := {}
	var ult := 0
	while not mo.finita() and int(mo.s["turno"]) <= turni and n < 200000:
		var rq := mo.richiesta()
		if rq.is_empty():
			print("VUOTA fase ", mo.s["fase"]); break
		conta[rq["k"]] = conta.get(rq["k"], 0) + 1
		if int(mo.s["turno"]) != ult and int(mo.s["turno"]) % 6 == 1:
			ult = int(mo.s["turno"])
			var pool_fr := 0
			for k in mo.s["pool"]:
				if str(k).begins_with("FR|"):
					pool_fr += int(mo.s["pool"][k])
			print("T%d %s %d  PF fr %d coal %d neutri %d  riserva fr %d" % [ult, Dati.MESI[mo.s["mese"]], mo.s["anno"], mo.sp_lato(0), mo.sp_lato(1), mo.sp_lato(2), pool_fr])
		var d: Dictionary = ia[int(rq["lato"])].decidi(rq)
		if not mo.applica(d):
			print("RIFIUTATA ", rq.get("k"), " ", d)
			if not mo.applica({"a": "fine"}):
				break
		n += 1
	for x in mo.s["log"]:
		if "Invasione" in str(x): print("LOG ", x)
	for x in mo.s["camp"]["storia"]:
		print("  ", x)
	print("turno ", mo.s["turno"], " ", Dati.MESI[mo.s["mese"]], " ", mo.s["anno"], " passi ", n, " ms ", Time.get_ticks_msec() - t0)
	print("stati ", mo.s["camp"]["pol"])
	print("conquiste ", mo.s["camp"]["conq"], " in conquista ", mo.s["camp"]["in_conquista"])
	print("PF fr ", mo.sp_lato(0), " coal ", mo.sp_lato(1), " neutri ", mo.sp_lato(2))
	print("esito ", mo.s["esito"])
	print("richieste ", conta)
	quit()
