extends SceneTree
## Screenshot dell'interfaccia: xvfb-run godot --path . -s res://tests/foto.gd -- <modo>
## modo: menu | partita | movimento | battaglia | fine
var main
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func shot(nome: String):
	for i in 15: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % nome)
	print("shot ", nome)
func _run():
	var args := OS.get_cmdline_user_args()
	var modo: String = args[0] if args.size() > 0 else "menu"
	await shot("menu")
	if modo == "menu":
		quit(); return
	if modo == "nuova":
		main.scelta_scen = OS.get_environment("WP_SCEN") if OS.get_environment("WP_SCEN") != "" else "1805"
		main._menu_nuova()
		await shot("nuova")
		quit(); return
	main.scelta_modo = "ia"
	main.scelta_lato = 0
	if modo == "tattica":
		main.opz_regole = {"matrice": true, "carica": true, "guardia": true, "aggiramento": true}
	main.scelta_scen = OS.get_environment("WP_SCEN") if OS.get_environment("WP_SCEN") != "" else "1805"
	main._avvia_locale()
	await shot("partita")
	if modo == "partita":
		quit(); return
	if modo == "navale":
		var t: String = Mappa.hex("Toulon")
		main._scegli_posto(t)
		for id in main.m.unita_in(t, 0, true):
			main.sel_carico[id] = int(main.m.s["unita"][id]["sp"])
		for c in main.m.capi_in(t, 0):
			main.sel_capi_nave.append(c)
		main._ricalcola_navi()
		main.sel_hex = t
		main._aggiorna_tutto()
		main.distanza = 30.0
		main._centra_su(Mappa.hex("Leghorn"), 30.0)
		await shot("navale")
		quit(); return
	if modo == "movimento":
		var nap := ""
		for id in main.m.s["capi"]:
			if main.m.s["capi"][id]["nome"] == "Napoleon": nap = id
		main.sel_hex = main.m.s["capi"][nap]["h"]
		main._aggiorna_tutto()
		main._scegli_capo(nap)
		main._centra_su(main.sel_hex, 9.0)
		await shot("movimento")
		quit(); return
	if modo == "tattica":
		# gioca con l'IA fino alla prima scelta di tattica del giocatore
		main.velocita = 50.0
		var n := 0
		while n < 3000 and not main.m.finita():
			await process_frame
			if main.popup_aperto:
				main._chiudi_popup()
				main.coda_rapporti.clear()
			var r: Dictionary = main.m.richiesta()
			if r.is_empty() or main._chi(int(r["lato"])) != "io":
				continue
			if r["k"] in ["tattica", "aggira", "guardia", "carica"]:
				main._aggiorna_tutto()
				await shot("tattica_" + r["k"])
				if r["k"] == "tattica":
					main._matrice_popup()
					await shot("matrice")
					quit(); return
			await main._invia(main.ia[int(r["lato"])].decidi(r))
			n += 1
		quit(); return
	# gioca con l'IA anche per il lato umano fino a una battaglia o alla fine
	main.velocita = 50.0
	var passi := 0
	while passi < 3000 and not main.m.finita():
		await process_frame
		if main.popup_aperto and modo == "battaglia":
			await shot("battaglia")
			quit(); return
		if main.popup_aperto:
			main._chiudi_popup()
			main.coda_rapporti.clear()
		var r: Dictionary = main.m.richiesta()
		if r.is_empty() or main._chi(int(r["lato"])) != "io":
			continue
		var d: Dictionary = main.ia[int(r["lato"])].decidi(r)
		await main._invia(d)
		passi += 1
	for i in 30: await process_frame
	await shot("fine")
	quit()
