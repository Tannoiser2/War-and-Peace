extends SceneTree
## Controlla che ogni scenario si carichi: schieramento, città sconosciute, capi mancanti.
func _init() -> void:
	for id in Scenari.ELENCO:
		var mo := Motore.new()
		mo.nuova({"seed": 5, "scen": id})
		var sp := [mo.sp_lato(0), mo.sp_lato(1), mo.sp_lato(2)]
		print("%s %s: PF %s capi %d riserva %d navi %d fase %s turni %d" % [id, mo.scen["titolo"], str(sp), mo.s["capi"].size(), mo.s["riserva"].size(), mo.s["navi"].size(), mo.s["fase"], int(mo.scen["turni"])])
	quit()
