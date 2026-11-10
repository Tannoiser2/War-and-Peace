## War and Peace - versione digitale (uso personale).
## Menu, mappa 3D con le pedine originali, partita contro l'IA, a due sullo stesso dispositivo,
## online (Firebase) e salvataggi.
extends Node

const F_TITOLO := preload("res://assets/font/Cinzel.ttf")
const F_BASE := preload("res://assets/font/EBGaramond.ttf")
const F_CORSIVO := preload("res://assets/font/EBGaramond-Italic.ttf")

const C_CARTA := Color(0.94, 0.89, 0.78)
const C_CARTA_SCURA := Color(0.86, 0.79, 0.66)
const C_INCHIOSTRO := Color(0.2, 0.12, 0.07)
const C_BORDEAUX := Color(0.39, 0.17, 0.16)
const C_BORDEAUX_SCURO := Color(0.22, 0.09, 0.08)
const C_ORO := Color(0.87, 0.71, 0.36)
const C_SPENTO := Color(0.46, 0.37, 0.28)
const C_ROSSO := Color(0.66, 0.1, 0.08)
const C_BLU := Color(0.17, 0.3, 0.6)
const COL_LATO := [Color(0.25, 0.42, 0.78), Color(0.72, 0.16, 0.12), Color(0.45, 0.42, 0.38)]
const SALVA_LOCALE := "user://partita_warpeace.json"
## scala: un pixel della mappa = 0.01 unità del mondo 3D
const SC := 0.01

var F_TESTO: FontVariation
var F_GRASSETTO: FontVariation

var ui: CanvasLayer
var schermo: Control
var net: Rete
var m: Motore
var ia: Array = []

# mondo 3D
var mondo: Node3D
var cam: Camera3D
var nodo_pezzi: Node3D
var nodo_evid: Node3D
var bersaglio_cam := Vector3(30, 0, 20)
var distanza := 16.0
var yaw := 0.0
var pitch := -1.05
var trascina := 0
var mouse_prec := Vector2.ZERO
var mouse_giu := Vector2.ZERO
var tocchi := {}
var due_dita := false
var cache_tex := {}
var cache_mat := {}

# partita
var in_partita := false
var umani := [true, false]
var online := false
var codice := ""
var mio_posto := 0
var posti_lati := [0, -1]
var attesa := 0.0
var velocita := 1.0
var aspetto_rete := false
var invio_in_corso := false
var salvataggio_in_corso := false
var ultimo_salvataggio := 0.0
var popup: Control
var popup_aperto := false
var coda_rapporti: Array = []
var carattere_ia := 1

# selezione
var sel_hex := ""
var sel_capo := ""
var sel_porta := {}
var rag := {}
var hover := ""
var vista_alta := false

# nodi dell'interfaccia
var lbl_data: Label
var lbl_fase: Label
var lbl_pv: Label
var pannello_info: VBoxContainer
var scroll_info: ScrollContainer
var box_azioni: VBoxContainer
var lbl_stato: Label
var diario: RichTextLabel
var pannello_diario: PanelContainer
var tip: PanelContainer
var tip_lbl: Label
var notifica: VBoxContainer

# online
var on_nome: LineEdit
var on_codice: LineEdit
var on_stato: Label
var on_lato: OptionButton
var on_scen: OptionButton
var lobby_box: VBoxContainer

func _ready() -> void:
	var tag_w := TextServerManager.get_primary_interface().name_to_tag("wght")
	F_TESTO = FontVariation.new()
	F_TESTO.base_font = F_BASE
	F_TESTO.variation_opentype = {tag_w: 470}
	F_GRASSETTO = FontVariation.new()
	F_GRASSETTO.base_font = F_BASE
	F_GRASSETTO.variation_opentype = {tag_w: 700}
	Mappa.carica()
	Motore.carica_catalogo()
	_costruisci_mondo()
	ui = CanvasLayer.new()
	add_child(ui)
	schermo = Control.new()
	schermo.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	schermo.theme = _tema()
	ui.add_child(schermo)
	net = Rete.new()
	add_child(net)
	mostra_menu()

# =============================================================================================
# Stile

func _tema() -> Theme:
	var t := Theme.new()
	t.default_font = F_TESTO
	t.default_font_size = 21
	var bn := stile(C_CARTA, C_BORDEAUX, 2, 5)
	var bh := stile(Color(1.0, 0.96, 0.86), C_ROSSO, 2, 5)
	var bp := stile(C_CARTA_SCURA, C_ROSSO, 3, 5)
	var bd := stile(Color(0.75, 0.7, 0.62, 0.7), Color(0.45, 0.38, 0.32), 1, 5)
	for k in [["normal", bn], ["hover", bh], ["pressed", bp], ["disabled", bd], ["focus", stile(Color(0, 0, 0, 0), C_ROSSO, 2, 5)]]:
		t.set_stylebox(k[0], "Button", k[1])
	t.set_font("font", "Button", F_TITOLO)
	t.set_color("font_color", "Button", C_INCHIOSTRO)
	t.set_color("font_hover_color", "Button", C_ROSSO)
	t.set_color("font_pressed_color", "Button", C_INCHIOSTRO)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.34, 0.28))
	t.set_color("font_color", "Label", C_INCHIOSTRO)
	t.set_stylebox("normal", "LineEdit", stile(Color(1, 0.97, 0.9), C_INCHIOSTRO, 2, 4))
	t.set_color("font_color", "LineEdit", C_INCHIOSTRO)
	t.set_stylebox("panel", "PanelContainer", stile(C_CARTA, C_BORDEAUX, 2, 6))
	t.set_color("default_color", "RichTextLabel", C_INCHIOSTRO)
	t.set_stylebox("normal", "OptionButton", bn)
	t.set_stylebox("hover", "OptionButton", bh)
	t.set_stylebox("pressed", "OptionButton", bp)
	t.set_color("font_color", "OptionButton", C_INCHIOSTRO)
	t.set_stylebox("panel", "PopupMenu", stile(C_CARTA, C_INCHIOSTRO, 2, 4))
	t.set_color("font_color", "PopupMenu", C_INCHIOSTRO)
	t.set_color("font_hover_color", "PopupMenu", C_ROSSO)
	t.set_stylebox("hover", "PopupMenu", stile(Color(1.0, 0.95, 0.84), Color(0, 0, 0, 0), 0, 3))
	t.set_color("font_color", "CheckBox", C_INCHIOSTRO)
	t.set_color("font_hover_color", "CheckBox", C_ROSSO)
	t.set_color("font_pressed_color", "CheckBox", C_INCHIOSTRO)
	return t

func stile(bg: Color, bordo := Color(0, 0, 0, 0), spessore := 0, raggio := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bordo
	s.set_border_width_all(spessore)
	s.set_corner_radius_all(raggio)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func etichetta(testo: String, font: Font = null, size := 21, col := C_INCHIOSTRO) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_override("font", font if font != null else F_TESTO)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func riga_lbl(testo: String, font: Font = null, size := 21, col := C_INCHIOSTRO) -> Label:
	var l := etichetta(testo, font, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

func bottone(testo: String, cb: Callable, size := 19, larg := 0.0) -> Button:
	var b := Button.new()
	b.text = testo
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	if larg > 0:
		b.custom_minimum_size.x = larg
	return b

func pannello(bg := C_CARTA, bordo := C_BORDEAUX) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stile(bg, bordo, 2, 8))
	return p

func tex(path: String) -> Texture2D:
	if not cache_tex.has(path):
		cache_tex[path] = load(path)
	return cache_tex[path]

func immagine(path: String, w: float, h: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(w, h)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func pulisci() -> void:
	for c in schermo.get_children():
		c.queue_free()
	in_partita = false
	popup = null
	popup_aperto = false
	coda_rapporti.clear()

# =============================================================================================
# Mondo 3D

func _costruisci_mondo() -> void:
	mondo = Node3D.new()
	add_child(mondo)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.07, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.88, 0.78)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	mondo.add_child(env)
	var luce := DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-62, 30, 0)
	luce.light_energy = 0.75
	luce.light_color = Color(1.0, 0.95, 0.85)
	luce.shadow_enabled = true
	luce.directional_shadow_max_distance = 30.0
	mondo.add_child(luce)
	cam = Camera3D.new()
	cam.fov = 42
	cam.far = 200
	mondo.add_child(cam)
	var lx := Mappa.larg * SC
	var lz := Mappa.alt * SC
	# tavolo
	var tav := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(lx * 3, lz * 3)
	tav.mesh = pm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.17, 0.1, 0.06)
	mt.roughness = 0.9
	tav.material_override = mt
	tav.position = Vector3(lx / 2, -0.06, lz / 2)
	mondo.add_child(tav)
	# spessore del tabellone
	var bordo := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(lx, 0.05, lz)
	bordo.mesh = bm
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.32, 0.15, 0.13)
	bordo.material_override = mb
	bordo.position = Vector3(lx / 2, -0.026, lz / 2)
	mondo.add_child(bordo)
	# la mappa originale
	var mp := MeshInstance3D.new()
	var pmm := PlaneMesh.new()
	pmm.size = Vector2(lx, lz)
	mp.mesh = pmm
	var mm := StandardMaterial3D.new()
	mm.albedo_texture = _con_mipmap("res://assets/mappa/mappa.webp")
	mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.material_override = mm
	mp.position = Vector3(lx / 2, 0, lz / 2)
	mondo.add_child(mp)
	nodo_evid = Node3D.new()
	mondo.add_child(nodo_evid)
	nodo_pezzi = Node3D.new()
	mondo.add_child(nodo_pezzi)
	_centra_su(Mappa.hex("Ulm"), 16.0)

func _con_mipmap(path: String) -> Texture2D:
	var t: Texture2D = load(path)
	var img := t.get_image()
	if img == null:
		return t
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _centra_su(h: String, d := -1.0) -> void:
	if h == "":
		return
	var p := Mappa.pos(h)
	bersaglio_cam = Vector3(p.x * SC, 0, p.y * SC)
	if d > 0:
		distanza = d
	_aggiorna_camera()

func _aggiorna_camera() -> void:
	pitch = clampf(pitch, -1.5, -0.45)
	distanza = clampf(distanza, 2.5, 42.0)
	var lx := Mappa.larg * SC
	var lz := Mappa.alt * SC
	bersaglio_cam.x = clampf(bersaglio_cam.x, 0, lx)
	bersaglio_cam.z = clampf(bersaglio_cam.z, 0, lz)
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	cam.position = bersaglio_cam + dir * distanza
	cam.look_at(bersaglio_cam, Vector3.UP)

func _v3(h: String, alt := 0.0) -> Vector3:
	var p := Mappa.pos(h)
	return Vector3(p.x * SC, alt, p.y * SC)

func _mat_pedina(img: String) -> StandardMaterial3D:
	if cache_mat.has(img):
		return cache_mat[img]
	var mt := StandardMaterial3D.new()
	mt.albedo_texture = _con_mipmap("res://assets/pedine/%s.webp" % img)
	mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mt.roughness = 0.6
	cache_mat[img] = mt
	return mt

func _mat_colore(c: Color, trasp := false, senza_luce := false) -> StandardMaterial3D:
	var k := "%s|%s|%s" % [c.to_html(), trasp, senza_luce]
	if cache_mat.has(k):
		return cache_mat[k]
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	if trasp:
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if senza_luce:
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cache_mat[k] = mt
	return mt

const LATO_PEDINA := 0.44
const SPESSORE := 0.032

func _pedina(img: String, colore: Color) -> Node3D:
	var n := Node3D.new()
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(LATO_PEDINA, SPESSORE, LATO_PEDINA * 0.94)
	base.mesh = bm
	base.material_override = _mat_colore(colore.darkened(0.25))
	base.position.y = SPESSORE / 2
	n.add_child(base)
	var faccia := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(LATO_PEDINA, LATO_PEDINA * 0.94)
	faccia.mesh = q
	faccia.material_override = _mat_pedina(img)
	faccia.position.y = SPESSORE + 0.0015
	n.add_child(faccia)
	return n

## Le pedine di un gruppo: le unità in tagli (20, 15, 10, 5, 1) come le pedine vere, poi i capi sopra
func _pedine_gruppo(h: String, lato: int, dentro: bool) -> Array:
	var out := []
	var unita := []
	for id in m.unita_in(h, lato):
		var u: Dictionary = m.s["unita"][id]
		if u["in"] == dentro:
			unita.append(u)
	unita.sort_custom(func(a, b): return int(a["sp"]) > int(b["sp"]))
	for u in unita:
		var resto := int(u["sp"])
		for taglio in [20, 15, 10, 5, 2, 1]:
			while resto >= taglio:
				var img := _img_unita(u["n"], u["s"], u["t"], taglio)
				if img == "":
					break
				out.append(img)
				resto -= taglio
		if out.size() > 14:
			break
	if not dentro:
		for id in m.capi_in(h, lato):
			out.append(m.s["capi"][id]["img"])
	return out

var _cache_img := {}

func _img_unita(naz: String, sub: String, tipo: String, sp: int) -> String:
	var k := "%s_%s_%s_%d" % [naz, sub if sub != "" else "x", tipo, sp]
	if _cache_img.has(k):
		return _cache_img[k]
	var trovato := ""
	for u in Motore.catalogo["unita"]:
		if u["img"] == k:
			trovato = k
	if trovato == "" and sp == 1:
		# minore senza pedina: si usa quella della nazione
		for u in Motore.catalogo["unita"]:
			if u["naz"] == naz and u["tipo"] == tipo and u["sp"] == 1 and u["sub"] == "":
				trovato = u["img"]
	_cache_img[k] = trovato
	return trovato

func _aggiorna_pezzi() -> void:
	for c in nodo_pezzi.get_children():
		c.queue_free()
	if m == null:
		return
	var gruppi := {}
	for id in m.s["unita"]:
		var u: Dictionary = m.s["unita"][id]
		gruppi["%s|%d|%s" % [u["h"], m.lato_unita(u), u["in"]]] = true
	for id in m.s["capi"]:
		var c: Dictionary = m.s["capi"][id]
		if c["h"] != "":
			gruppi["%s|%d|false" % [c["h"], m.lato_capo(c)]] = true
	for k in gruppi:
		var p: PackedStringArray = k.split("|")
		var h := p[0]
		var lato := int(p[1])
		var dentro := p[2] == "true"
		var imgs := _pedine_gruppo(h, lato, dentro)
		if imgs.is_empty():
			continue
		var base := _v3(h)
		# due lati nello stesso esagono (assedio): le pile si affiancano
		var off := Vector3.ZERO
		if m.sp_in(h, 1 - lato) > 0 or (m.sp_in(h, lato, false, true) > 0 and m.sp_in(h, lato, true) > 0):
			off = Vector3(-0.17 if dentro else 0.17, 0, 0)
		var pila := Node3D.new()
		pila.position = base + off
		nodo_pezzi.add_child(pila)
		var col: Color = Dati.NAZ.get(_naz_gruppo(h, lato), {}).get("col", Color.GRAY)
		var max_vis := mini(imgs.size(), 9)
		for i in max_vis:
			var img: String = imgs[imgs.size() - max_vis + i] if imgs.size() > max_vis and i > 0 else imgs[i]
			var t := _pedina(img, col)
			t.position = Vector3(i * 0.012, i * (SPESSORE + 0.003), -i * 0.012)
			pila.add_child(t)
		var sp := 0
		for id in m.unita_in(h, lato):
			if m.s["unita"][id]["in"] == dentro:
				sp += int(m.s["unita"][id]["sp"])
		if sp > 0:
			var lb := Label3D.new()
			lb.text = str(sp)
			lb.font = F_TITOLO
			lb.font_size = 64
			lb.pixel_size = 0.0034
			lb.outline_size = 14
			lb.modulate = Color(1, 0.96, 0.85)
			lb.outline_modulate = COL_LATO[lato].darkened(0.35)
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.no_depth_test = true
			lb.position = Vector3(0.2, max_vis * (SPESSORE + 0.003) + 0.12, -0.12)
			pila.add_child(lb)
	# segnalini: assedi e trincee
	for h in m.s["assedi"]:
		var t := _pedina("seg_assedio%d" % clampi([1, 1, 3, 3, 5, 5][clampi(int(m.s["assedi"][h]["l"]), 0, 5)], 1, 5), Color(0.3, 0.3, 0.3))
		t.position = _v3(h) + Vector3(-0.22, 0, 0.22)
		t.scale = Vector3(0.6, 1, 0.6)
		nodo_pezzi.add_child(t)
	for h in m.s["trincee"]:
		var t := _pedina("seg_fortezza", Color(0.3, 0.3, 0.3))
		t.position = _v3(h) + Vector3(0.24, 0, 0.22)
		t.scale = Vector3(0.6, 1, 0.6)
		nodo_pezzi.add_child(t)
	# bandiere di controllo: città obiettivo e città prese al nemico
	for h in m.s["controllo"]:
		var l := m.controllore(h)
		var st := Mappa.stato(h)
		var nome := Mappa.nome_citta(h)
		var obiettivo: bool = m.scen["obiettivi"][0].has(nome) or m.scen["obiettivi"][1].has(nome)
		if m.lato_di(st) == l and not obiettivo:
			continue
		if m.sp_in(h, 0) > 0 or m.sp_in(h, 1) > 0:
			continue
		var naz := _naz_controllo(h, l)
		var t := _pedina("seg_bandiera_" + naz, Color(0.4, 0.4, 0.4))
		t.position = _v3(h) + Vector3(0.0, 0, 0.0)
		t.scale = Vector3(0.55, 1, 0.55)
		nodo_pezzi.add_child(t)

func _naz_gruppo(h: String, lato: int) -> String:
	var conta := {}
	for id in m.unita_in(h, lato):
		var n: String = m.s["unita"][id]["n"]
		conta[n] = conta.get(n, 0) + int(m.s["unita"][id]["sp"])
	for id in m.capi_in(h, lato):
		var n: String = m.s["capi"][id]["n"]
		conta[n] = conta.get(n, 0) + 1
	var best := ""
	for n in conta:
		if best == "" or conta[n] > conta[best]:
			best = n
	return best

func _naz_controllo(h: String, l: int) -> String:
	var st := Mappa.stato(h)
	if m.lato_di(st) == l and Dati.NAZ.has(st):
		return st
	if l == 0:
		return "FR"
	# coalizione: Austria salvo in Russia o Prussia
	if st in ["RU", "PR"]:
		return st
	return "AU"

# ---------- evidenziazioni

func _esagono_mesh(colore: Color, raggio := 0.36, alt := 0.004) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = raggio
	cm.bottom_radius = raggio
	cm.height = alt
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.rotation.y = PI / 6.0
	mi.material_override = _mat_colore(colore, colore.a < 1.0, true)
	return mi

func _anello(colore: Color) -> Node3D:
	var n := Node3D.new()
	for i in 6:
		var a := deg_to_rad(30 + i * 60)
		var b := deg_to_rad(30 + (i + 1) * 60)
		var r := 0.37
		var pa := Vector3(cos(a) * r, 0.01, sin(a) * r)
		var pb := Vector3(cos(b) * r, 0.01, sin(b) * r)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(pa.distance_to(pb), 0.012, 0.04)
		seg.mesh = bm
		seg.material_override = _mat_colore(colore, false, true)
		seg.position = (pa + pb) / 2
		seg.rotation.y = -atan2(pb.z - pa.z, pb.x - pa.x)
		n.add_child(seg)
	return n

func _freccia(da: String, a: String, colore: Color) -> Node3D:
	var p0 := _v3(da, 0.05)
	var p1 := _v3(a, 0.05)
	var n := Node3D.new()
	var dir := (p1 - p0)
	var lung := dir.length()
	var corpo := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(lung * 0.62, 0.02, 0.09)
	corpo.mesh = bm
	corpo.material_override = _mat_colore(colore, false, true)
	n.add_child(corpo)
	var punta := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.22, 0.2, 0.02)
	punta.mesh = pm
	punta.material_override = _mat_colore(colore, false, true)
	punta.rotation_degrees = Vector3(-90, 0, -90)
	punta.position = Vector3(lung * 0.36, 0, 0)
	n.add_child(punta)
	n.position = (p0 + p1) / 2 + Vector3(0, 0.25, 0)
	n.rotation.y = -atan2(dir.z, dir.x)
	return n

const COL_FM := [Color(0.2, 0.75, 0.25, 0.36), Color(0.95, 0.85, 0.15, 0.38), Color(0.95, 0.55, 0.1, 0.4), Color(0.9, 0.2, 0.1, 0.42)]

func _aggiorna_evidenze() -> void:
	for c in nodo_evid.get_children():
		c.queue_free()
	if m == null:
		return
	for h in rag:
		var fm := clampi(int(rag[h]["fm"]), 0, 3)
		var e := _esagono_mesh(COL_FM[fm])
		e.position = _v3(h, 0.006)
		nodo_evid.add_child(e)
	if sel_hex != "":
		var a := _anello(C_ORO)
		a.position = _v3(sel_hex)
		nodo_evid.add_child(a)
		if _fase_mia("dichiara"):
			for p in m.attacchi_possibili():
				if p[0] == sel_hex:
					var e := _esagono_mesh(Color(0.85, 0.1, 0.05, 0.42))
					e.position = _v3(p[1], 0.008)
					nodo_evid.add_child(e)
	if hover != "" and hover != sel_hex:
		var a := _anello(Color(1, 1, 1, 1))
		a.position = _v3(hover)
		nodo_evid.add_child(a)
	for b in m.s["batt"]:
		if b["att"] != b["dif"]:
			nodo_evid.add_child(_freccia(b["att"], b["dif"], Color(0.8, 0.08, 0.05)))
		else:
			var e := _esagono_mesh(Color(0.85, 0.1, 0.05, 0.5))
			e.position = _v3(b["dif"], 0.008)
			nodo_evid.add_child(e)

# ---------- input sulla mappa

func _esagono_sotto(pos: Vector2) -> String:
	var o := cam.project_ray_origin(pos)
	var d := cam.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		return ""
	var t := -o.y / d.y
	if t < 0:
		return ""
	var p := o + d * t
	return Mappa.esagono_in(Vector2(p.x / SC, p.z / SC))

func _unhandled_input(ev: InputEvent) -> void:
	if not in_partita or popup_aperto:
		return
	# tocco: un dito trascina (emulato come mouse), due dita pizzicano e ruotano
	if ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			tocchi[st.index] = st.position
		else:
			tocchi.erase(st.index)
		due_dita = tocchi.size() >= 2
		if due_dita:
			trascina = 0
		return
	if ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		if tocchi.size() >= 2 and tocchi.has(sd.index):
			var ids: Array = tocchi.keys()
			var altro: int = ids[1] if ids[0] == sd.index else ids[0]
			var a0: Vector2 = tocchi[sd.index]
			var b0: Vector2 = tocchi[altro]
			var a1: Vector2 = sd.position
			var d0 := a0.distance_to(b0)
			var d1 := a1.distance_to(b0)
			if d0 > 10 and d1 > 10:
				distanza = clampf(distanza * d0 / d1, 2.5, 42.0)
			var ang := (a1 - b0).angle() - (a0 - b0).angle()
			yaw -= wrapf(ang, -PI, PI)
			tocchi[sd.index] = a1
			_aggiorna_camera()
		elif tocchi.has(sd.index):
			tocchi[sd.index] = sd.position
		return
	if due_dita and (ev is InputEventMouseMotion or ev is InputEventMouseButton):
		if ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed:
			trascina = 0
			if tocchi.size() < 2:
				due_dita = false
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distanza *= 0.9
			_aggiorna_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distanza *= 1.1
			_aggiorna_camera()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				trascina = mb.button_index
				mouse_prec = mb.position
				mouse_giu = mb.position
			else:
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.position.distance_to(mouse_giu) < 8:
					_clic(_esagono_sotto(mb.position))
				elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.position.distance_to(mouse_giu) < 8:
					_annulla_selezione()
				trascina = 0
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if trascina == MOUSE_BUTTON_LEFT and mm.position.distance_to(mouse_giu) > 8:
			_sposta(mm.position - mouse_prec)
		elif trascina == MOUSE_BUTTON_RIGHT or trascina == MOUSE_BUTTON_MIDDLE:
			yaw -= (mm.position - mouse_prec).x * 0.006
			pitch -= (mm.position - mouse_prec).y * 0.004
			_aggiorna_camera()
		mouse_prec = mm.position
		var h := _esagono_sotto(mm.position)
		if h != hover:
			hover = h
			_aggiorna_evidenze()
			_mostra_tip(h, mm.position)
		elif h != "" and tip != null:
			tip.position = mm.position + Vector2(20, 20)
	elif ev is InputEventMagnifyGesture:
		distanza /= (ev as InputEventMagnifyGesture).factor
		_aggiorna_camera()
	elif ev is InputEventPanGesture:
		_sposta(-(ev as InputEventPanGesture).delta * 8.0)

func _sposta(d: Vector2) -> void:
	var f := distanza * 0.0011
	var dx := Vector3(cos(yaw), 0, -sin(yaw))
	var dz := Vector3(sin(yaw), 0, cos(yaw))
	bersaglio_cam -= dx * d.x * f + dz * d.y * f
	_aggiorna_camera()

func _mostra_tip(h: String, pos: Vector2) -> void:
	if tip == null:
		return
	if h == "" or m == null:
		tip.visible = false
		return
	var t := Mappa.nome(h)
	var righe := [t]
	if Mappa.ha_citta(h):
		var ctl := m.controllore(h)
		righe.append("%s%s" % [{"capitale": "Capitale", "maggiore": "Città maggiore", "minore": "Città minore"}[Mappa.tipo_citta(h)],
			(", controllata da: " + Dati.LATI[ctl]) if ctl >= 0 else ""])
	righe.append("Terreno: %s, area %d" % [Dati.NOMI_TERRENO.get(Mappa.terreno(h), ""), Mappa.area(h)])
	for l in [0, 1, 2]:
		var sp := m.sp_in(h, l)
		var capi := []
		for id in m.capi_in(h, l):
			capi.append("%s (%d)" % [m.s["capi"][id]["nome"], int(m.s["capi"][id]["v"])])
		if sp > 0 or not capi.is_empty():
			righe.append("%s: %d PF%s" % [Dati.LATI_BREVI[l], sp, (" — " + ", ".join(capi)) if not capi.is_empty() else ""])
	if rag.has(h):
		var r: Dictionary = rag[h]
		righe.append("Costo %d PM%s" % [int(r["mp"]), (", marcia forzata +%d" % int(r["fm"])) if int(r["fm"]) > 0 else ""])
	tip_lbl.text = "\n".join(righe)
	tip.position = pos + Vector2(20, 20)
	tip.visible = true

# =============================================================================================
# Menu

func _sfondo() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.08, 0.06, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	schermo.add_child(bg)

func _scheda_centrale(w: float, h: float) -> VBoxContainer:
	var box := pannello()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(w, h)
	box.position = Vector2(-w / 2.0, -h / 2.0)
	box.add_theme_stylebox_override("panel", stile(C_CARTA, C_BORDEAUX, 4, 10))
	schermo.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	return v

func mostra_menu() -> void:
	pulisci()
	m = null
	_aggiorna_pezzi_vuoti()
	_sfondo()
	var v := _scheda_centrale(780, 640)
	var logo := immagine("res://assets/ui/logo.webp", 620, 228)
	v.add_child(logo)
	var sot := etichetta("Le guerre napoleoniche, 1805-1815", F_CORSIVO, 30, C_INCHIOSTRO)
	sot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sot)
	var capi := HBoxContainer.new()
	capi.alignment = BoxContainer.ALIGNMENT_CENTER
	capi.add_theme_constant_override("separation", 10)
	for img in ["capo_FR_x_Napoleon", "capo_AU_x_Charles", "capo_RU_x_Kutusov", "capo_PR_x_Blucher", "capo_EN_x_Wellington"]:
		capi.add_child(immagine("res://assets/pedine/%s.webp" % img, 72, 68))
	v.add_child(capi)
	v.add_child(HSeparator.new())
	v.add_child(bottone("Nuova partita", _menu_nuova, 26))
	if FileAccess.file_exists(SALVA_LOCALE):
		v.add_child(bottone("Continua la partita salvata", _menu_continua, 24))
	v.add_child(bottone("Riprendi la partita salvata su Firebase", _continua_firebase, 21))
	v.add_child(bottone("Gioca online con un amico", _menu_online, 24))
	v.add_child(bottone("Le regole in breve", _menu_regole, 21))
	var nota := etichetta("Versione digitale per uso personale, dal modulo Tabletop Simulator della 6ª/7ª edizione (One Small Step).", F_CORSIVO, 17, C_SPENTO)
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nota)

func _aggiorna_pezzi_vuoti() -> void:
	for c in nodo_pezzi.get_children():
		c.queue_free()
	for c in nodo_evid.get_children():
		c.queue_free()

var scelta_lato := 0
var scelta_modo := "ia"
var scelta_scen := "1805"

func _menu_nuova() -> void:
	pulisci()
	_sfondo()
	var sc: Dictionary = Scenari.dati(scelta_scen)
	var v := _scheda_centrale(960, 820)
	var rs := HBoxContainer.new()
	rs.add_theme_constant_override("separation", 10)
	v.add_child(rs)
	var gs := ButtonGroup.new()
	for id in Scenari.ELENCO:
		var b := Button.new()
		b.text = Scenari.dati(id)["titolo"]
		b.toggle_mode = true
		b.button_group = gs
		b.button_pressed = id == scelta_scen
		b.add_theme_font_size_override("font_size", 20)
		var sid: String = id
		b.pressed.connect(func():
			scelta_scen = sid
			_menu_nuova())
		rs.add_child(b)
	v.add_child(etichetta(sc["titolo"], F_TITOLO, 42, C_BORDEAUX))
	v.add_child(etichetta(sc["sottotitolo"], F_CORSIVO, 23, C_INCHIOSTRO))
	v.add_child(etichetta(sc["descrizione"], F_TESTO, 19))
	v.add_child(etichetta(sc.get("durata", "") + " " + sc["vittoria"], F_TESTO, 16, C_SPENTO))
	v.add_child(HSeparator.new())
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	v.add_child(r)
	var opz := [["Comando i Francesi", "ia", 0], ["Comando la Coalizione", "ia", 1], ["Due giocatori qui", "due", 0], ["Guardo l'IA", "guarda", 0]]
	var gruppo := ButtonGroup.new()
	for o in opz:
		var b := Button.new()
		b.text = o[0]
		b.toggle_mode = true
		b.button_group = gruppo
		b.add_theme_font_size_override("font_size", 18)
		b.button_pressed = o[1] == scelta_modo and (o[1] != "ia" or o[2] == scelta_lato)
		b.pressed.connect(func():
			scelta_modo = o[1]
			scelta_lato = o[2])
		r.add_child(b)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 10)
	v.add_child(r2)
	r2.add_child(riga_lbl("Avversario:", F_GRASSETTO, 20))
	var g2 := ButtonGroup.new()
	for o in [["prudente", 0], ["normale", 1], ["aggressivo", 2]]:
		var b := Button.new()
		b.text = o[0]
		b.toggle_mode = true
		b.button_group = g2
		b.add_theme_font_size_override("font_size", 17)
		b.button_pressed = carattere_ia == o[1]
		b.pressed.connect(func(): carattere_ia = o[1])
		r2.add_child(b)
	var r3 := HBoxContainer.new()
	v.add_child(r3)
	r3.add_child(bottone("Inizia", _avvia_locale, 26, 260))
	r3.add_child(bottone("Indietro", mostra_menu, 20))

func _avvia_locale() -> void:
	online = false
	match scelta_modo:
		"ia":
			umani = [scelta_lato == 0, scelta_lato == 1]
		"due":
			umani = [true, true]
		_:
			umani = [false, false]
	m = Motore.new()
	m.nuova({"scen": scelta_scen, "seed": int(Time.get_unix_time_from_system()) % 1000000})
	_prepara_ia()
	_apri_partita()
	_salva(true)

func _prepara_ia() -> void:
	ia = [IA.new(m), IA.new(m)]
	for x in ia:
		x.carattere = carattere_ia

func _menu_continua() -> void:
	var f := FileAccess.open(SALVA_LOCALE, FileAccess.READ)
	if f == null:
		return
	var st = JSON.parse_string(f.get_as_text())
	if not (st is Dictionary):
		_avviso("Il salvataggio è illeggibile.")
		return
	_carica_stato(st)

func _continua_firebase() -> void:
	_avviso("Cerco la partita salvata su Firebase...")
	var st := await net.carica_partita()
	if st.is_empty():
		_avviso("Nessuna partita salvata su Firebase per questo dispositivo. " + net.last_error)
		return
	_carica_stato(st)

func _carica_stato(st: Dictionary) -> void:
	online = false
	m = Motore.new()
	var dati: Dictionary = st.get("motore", st)
	m.importa(dati)
	var u = st.get("umani", [true, false])
	umani = [bool(u[0]), bool(u[1])] if u is Array and u.size() == 2 else [true, false]
	carattere_ia = int(st.get("carattere", 1))
	_prepara_ia()
	_apri_partita()

func _avviso(t: String) -> void:
	_notifica(t)

func _menu_regole() -> void:
	pulisci()
	_sfondo()
	var v := _scheda_centrale(1100, 860)
	v.add_child(etichetta("Le regole in breve", F_TITOLO, 40, C_BORDEAUX))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1060, 700)
	v.add_child(sc)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(1030, 0)
	rt.add_theme_font_override("normal_font", F_TESTO)
	rt.add_theme_font_override("bold_font", F_GRASSETTO)
	rt.add_theme_font_override("italics_font", F_CORSIVO)
	rt.add_theme_font_size_override("normal_font_size", 20)
	rt.add_theme_font_size_override("bold_font_size", 20)
	rt.add_theme_font_size_override("italics_font_size", 20)
	rt.text = Guida.TESTO
	sc.add_child(rt)
	v.add_child(bottone("Indietro", mostra_menu, 20))

# =============================================================================================
# Online

func _menu_online() -> void:
	pulisci()
	_sfondo()
	var v := _scheda_centrale(860, 680)
	v.add_child(etichetta("Gioca online", F_TITOLO, 44, C_BORDEAUX))
	v.add_child(etichetta("Chi crea la stanza sceglie la sua parte; l'amico entra con il codice di 4 lettere e prende l'altra. Se l'amico non c'è, l'altra parte la guida l'IA.", F_TESTO, 20))
	var r1 := HBoxContainer.new()
	v.add_child(r1)
	r1.add_child(riga_lbl("Il tuo nome:  ", F_GRASSETTO, 21))
	on_nome = LineEdit.new()
	on_nome.custom_minimum_size = Vector2(300, 0)
	on_nome.text = str(net.load_session().get("name", "Maresciallo"))
	on_nome.max_length = 20
	r1.add_child(on_nome)
	var r0 := HBoxContainer.new()
	v.add_child(r0)
	r0.add_child(riga_lbl("La tua parte (se crei la stanza):  ", F_GRASSETTO, 21))
	on_lato = OptionButton.new()
	on_lato.add_item("Francia")
	on_lato.add_item("Coalizione")
	r0.add_child(on_lato)
	var r00 := HBoxContainer.new()
	v.add_child(r00)
	r00.add_child(riga_lbl("Scenario:  ", F_GRASSETTO, 21))
	on_scen = OptionButton.new()
	for id in Scenari.ELENCO:
		on_scen.add_item(Scenari.dati(id)["titolo"])
	r00.add_child(on_scen)
	v.add_child(bottone("Crea una stanza", _online_crea, 24))
	var r2 := HBoxContainer.new()
	v.add_child(r2)
	on_codice = LineEdit.new()
	on_codice.placeholder_text = "CODICE"
	on_codice.max_length = 4
	on_codice.custom_minimum_size = Vector2(160, 0)
	r2.add_child(on_codice)
	r2.add_child(bottone("Entra", _online_entra, 24))
	var sess := net.load_session()
	if str(sess.get("room", "")) != "":
		r2.add_child(bottone("Rientra in %s" % sess["room"], func():
			on_codice.text = str(sess["room"])
			_online_entra(), 20))
	on_stato = etichetta("", F_TESTO, 20, C_ROSSO)
	v.add_child(on_stato)
	lobby_box = VBoxContainer.new()
	v.add_child(lobby_box)
	v.add_child(bottone("Indietro", mostra_menu, 20))

func _online_crea() -> void:
	on_stato.text = "Creo la stanza..."
	net._save({"name": on_nome.text})
	var lato := on_lato.selected
	var c := await net.create_room(on_nome.text, {"lato": lato, "scen": Scenari.ELENCO[on_scen.selected]})
	if c == "":
		on_stato.text = "Non riesco a creare la stanza: " + net.last_error
		return
	codice = c
	mio_posto = 0
	net.remember_room(c, 0)
	on_stato.text = "Stanza %s creata. Dai il codice all'amico, poi premi Inizia." % c
	_lobby(true)

func _online_entra() -> void:
	var c := on_codice.text.strip_edges().to_upper()
	if c.length() != 4:
		on_stato.text = "Il codice ha 4 lettere."
		return
	on_stato.text = "Entro nella stanza %s..." % c
	net._save({"name": on_nome.text})
	var p := await net.join_room(c, on_nome.text, 2)
	if p < 0:
		on_stato.text = "Non riesco a entrare (stanza piena, inesistente o già iniziata). " + net.last_error
		return
	codice = c
	mio_posto = p
	net.remember_room(c, p)
	var room := await net.room(c)
	if room.get("status", "") == "playing":
		_avvia_da_stanza(room)
		return
	on_stato.text = "Sei nella stanza %s. Aspetta che chi l'ha creata inizi." % c
	_lobby(false)

func _lobby(host: bool) -> void:
	for ch in lobby_box.get_children():
		ch.queue_free()
	var lista := etichetta("", F_TESTO, 20)
	lobby_box.add_child(lista)
	if host:
		lobby_box.add_child(bottone("Inizia la partita", _online_inizia, 24))
	while is_instance_valid(lista) and not in_partita:
		var room := await net.room(codice)
		if not is_instance_valid(lista):
			return
		var seats := Rete._as_dict(room.get("seats", {}))
		var t := "Nella stanza:\n"
		for k in seats:
			t += "  %d. %s\n" % [int(k) + 1, seats[k].get("name", "?")]
		lista.text = t
		if not host and room.get("status", "") == "playing":
			_avvia_da_stanza(room)
			return
		await get_tree().create_timer(1.5).timeout

func _online_inizia() -> void:
	var room := await net.room(codice)
	var seats := Rete._as_dict(room.get("seats", {}))
	var cfg = JSON.parse_string(str(room.get("cfg", "{}")))
	var lato_host: int = int(cfg.get("lato", 0)) if cfg is Dictionary else 0
	var lati := [-1, -1]
	lati[lato_host] = 0
	if seats.has("1"):
		lati[1 - lato_host] = 1
	var game := {"seed": int(Time.get_unix_time_from_system()) % 1000000, "lati": lati, "scen": str(cfg.get("scen", "1805")) if cfg is Dictionary else "1805"}
	if not await net.start_room(codice, game):
		on_stato.text = "Non riesco a iniziare: " + net.last_error
		return
	room["game"] = JSON.stringify(game)
	_avvia_da_stanza(room)

func _avvia_da_stanza(room: Dictionary) -> void:
	var game = JSON.parse_string(str(room.get("game", "{}")))
	if not (game is Dictionary):
		on_stato.text = "Dati della partita illeggibili."
		return
	online = true
	posti_lati = [int(game["lati"][0]), int(game["lati"][1])]
	umani = [posti_lati[0] == mio_posto, posti_lati[1] == mio_posto]
	m = Motore.new()
	m.nuova({"scen": str(game.get("scen", "1805")), "seed": int(game["seed"])})
	_prepara_ia()
	# si rigiocano le decisioni già prese
	var log := await net.get_decisions(codice, 0)
	var guard := 0
	while not m.finita() and guard < 20000:
		guard += 1
		var n := int(m.s["azioni"])
		if not log.has(n):
			break
		if not m.applica(log[n]):
			push_warning("decisione %d rifiutata nel riavvio" % n)
			break
	_apri_partita()

## Chi decide per un lato: "io", "ia" (calcolata qui), "remoto" (si aspetta dalla rete)
func _chi(lato: int) -> String:
	if not online:
		return "io" if umani[lato] else "ia"
	if posti_lati[lato] == mio_posto:
		return "io"
	if posti_lati[lato] < 0:
		return "ia" if mio_posto == 0 else "remoto"
	return "remoto"

# =============================================================================================
# La partita

func _apri_partita() -> void:
	pulisci()
	in_partita = true
	sel_hex = ""
	_annulla_selezione()
	_costruisci_hud()
	_aggiorna_tutto()
	# centra sulla prima armata del primo lato umano
	for l in [0, 1]:
		if _chi(l) == "io":
			for id in m.s["capi"]:
				var c: Dictionary = m.s["capi"][id]
				if m.lato_capo(c) == l and c["h"] != "" and c["nome"] in ["Napoleon", "Mack", "Charles", "Kutusov", "Blucher", "Wittgenstein"]:
					_centra_su(c["h"], 15.0)
					break
			break

func _costruisci_hud() -> void:
	# barra in alto
	var barra := PanelContainer.new()
	barra.add_theme_stylebox_override("panel", stile(C_BORDEAUX_SCURO, C_ORO, 0, 0))
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra.custom_minimum_size.y = 62
	schermo.add_child(barra)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	barra.add_child(hb)
	hb.add_child(riga_lbl("WAR and PEACE", F_TITOLO, 30, C_ORO))
	lbl_data = riga_lbl("", F_TITOLO, 22, Color(0.98, 0.93, 0.82))
	hb.add_child(lbl_data)
	lbl_fase = riga_lbl("", F_GRASSETTO, 22, Color(0.98, 0.93, 0.82))
	lbl_fase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(lbl_fase)
	lbl_pv = riga_lbl("", F_TESTO, 20, C_ORO)
	hb.add_child(lbl_pv)
	for b in [["Registro", _mostra_diario], ["Vista", _cambia_vista], ["Regole", _regole_popup], ["Menu", _menu_partita]]:
		var bt := bottone(b[0], b[1], 17)
		bt.autowrap_mode = TextServer.AUTOWRAP_OFF
		hb.add_child(bt)
	# pannello a sinistra
	var sx := pannello(Color(0.95, 0.9, 0.79, 0.96))
	sx.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	sx.offset_top = 74
	sx.offset_bottom = -12
	sx.offset_left = 12
	sx.offset_right = 452
	schermo.add_child(sx)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	sx.add_child(col)
	lbl_stato = etichetta("", F_CORSIVO, 20, C_BORDEAUX)
	col.add_child(lbl_stato)
	box_azioni = VBoxContainer.new()
	box_azioni.add_theme_constant_override("separation", 6)
	col.add_child(box_azioni)
	col.add_child(HSeparator.new())
	scroll_info = ScrollContainer.new()
	scroll_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_info.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll_info)
	pannello_info = VBoxContainer.new()
	pannello_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pannello_info.add_theme_constant_override("separation", 6)
	scroll_info.add_child(pannello_info)
	# registro a destra (nascosto)
	pannello_diario = pannello(Color(0.95, 0.9, 0.79, 0.96))
	pannello_diario.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	pannello_diario.offset_top = 74
	pannello_diario.offset_bottom = -12
	pannello_diario.offset_left = -520
	pannello_diario.offset_right = -12
	pannello_diario.visible = false
	schermo.add_child(pannello_diario)
	diario = RichTextLabel.new()
	diario.bbcode_enabled = true
	diario.scroll_following = true
	diario.add_theme_font_override("normal_font", F_TESTO)
	diario.add_theme_font_override("bold_font", F_GRASSETTO)
	diario.add_theme_font_size_override("normal_font_size", 18)
	diario.add_theme_font_size_override("bold_font_size", 18)
	pannello_diario.add_child(diario)
	# legenda in basso a destra
	var leg := pannello(Color(0.95, 0.9, 0.79, 0.88))
	leg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	leg.offset_left = -560
	leg.offset_top = -52
	leg.offset_right = -12
	leg.offset_bottom = -12
	leg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	schermo.add_child(leg)
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 6)
	leg.add_child(lh)
	for x in [[COL_FM[0], "si arriva"], [COL_FM[1], "+1"], [COL_FM[2], "+2"], [COL_FM[3], "+3 marcia forzata"]]:
		var c := ColorRect.new()
		c.color = Color(x[0].r, x[0].g, x[0].b, 1.0)
		c.custom_minimum_size = Vector2(22, 22)
		lh.add_child(c)
		lh.add_child(riga_lbl(x[1], F_TESTO, 16))
	# suggerimento
	tip = pannello(Color(1, 0.97, 0.88, 0.95))
	tip.visible = false
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	schermo.add_child(tip)
	tip_lbl = etichetta("", F_TESTO, 17)
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tip.add_child(tip_lbl)
	notifica = VBoxContainer.new()
	notifica.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notifica.offset_top = 84
	notifica.offset_left = -330
	notifica.offset_right = 330
	notifica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	schermo.add_child(notifica)

func _notifica(t: String) -> void:
	if notifica == null or not is_instance_valid(notifica):
		if on_stato != null and is_instance_valid(on_stato):
			on_stato.text = t
		return
	var p := pannello(Color(0.98, 0.94, 0.84, 0.97), C_ROSSO)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := etichetta(t, F_GRASSETTO, 21, C_BORDEAUX)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	notifica.add_child(p)
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)

func _mostra_diario() -> void:
	pannello_diario.visible = not pannello_diario.visible

func _cambia_vista() -> void:
	vista_alta = not vista_alta
	if vista_alta:
		pitch = -1.5
		yaw = 0.0
	else:
		pitch = -1.05
	_aggiorna_camera()

func _menu_partita() -> void:
	var v := _apri_popup("Menu", 560)
	v.add_child(bottone("Torna alla partita", _chiudi_popup, 22))
	v.add_child(bottone("Salva ora (anche su Firebase)", func():
		_salva(true)
		_chiudi_popup()
		_notifica("Partita salvata"), 20))
	var gv := HBoxContainer.new()
	gv.add_child(riga_lbl("Velocità dell'IA: ", F_GRASSETTO, 19))
	for x in [["lenta", 0.5], ["normale", 1.0], ["veloce", 3.0]]:
		gv.add_child(bottone(x[0], func(): velocita = x[1], 17))
	v.add_child(gv)
	var cb := CheckBox.new()
	cb.text = "Rinforzi automatici nelle battaglie"
	cb.button_pressed = m.s["opzioni"].get("rinforzi_auto", true)
	cb.toggled.connect(func(on):
		for l in [0, 1]:
			if _chi(l) == "io":
				m.s["opzioni"]["rinforzi_" + str(l)] = on
		m.s["opzioni"]["rinforzi_auto"] = on)
	v.add_child(cb)
	v.add_child(bottone("Esci al menu principale", func():
		_salva(true)
		mostra_menu(), 20))

func _apri_popup(titolo: String, larg := 900, alto := 0) -> VBoxContainer:
	_chiudi_popup()
	popup_aperto = true
	var velo := ColorRect.new()
	velo.color = Color(0.08, 0.04, 0.03, 0.5)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	schermo.add_child(velo)
	popup = velo
	var box := pannello()
	box.add_theme_stylebox_override("panel", stile(C_CARTA, C_BORDEAUX, 4, 10))
	box.custom_minimum_size = Vector2(larg, alto)
	velo.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	v.add_child(etichetta(titolo, F_TITOLO, 30, C_BORDEAUX))
	box.resized.connect(func(): _adatta_popup(box, velo))
	_adatta_popup.call_deferred(box, velo)
	return v

func _adatta_popup(p: Control, velo: Control) -> void:
	if not is_instance_valid(p) or not is_instance_valid(velo):
		return
	var vs := velo.size
	p.position = ((vs - p.size) / 2.0).max(Vector2(10, 10))

func _chiudi_popup() -> void:
	if popup != null and is_instance_valid(popup):
		popup.queue_free()
	popup = null
	popup_aperto = false

func _regole_popup() -> void:
	var v := _apri_popup("Le regole in breve", 1100)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1060, 640)
	v.add_child(sc)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(1030, 0)
	rt.add_theme_font_override("normal_font", F_TESTO)
	rt.add_theme_font_override("bold_font", F_GRASSETTO)
	rt.add_theme_font_override("italics_font", F_CORSIVO)
	rt.add_theme_font_size_override("normal_font_size", 19)
	rt.add_theme_font_size_override("bold_font_size", 19)
	rt.add_theme_font_size_override("italics_font_size", 19)
	rt.text = Guida.TESTO
	sc.add_child(rt)
	v.add_child(bottone("Chiudi", _chiudi_popup, 20))

# ---------- aggiornamento

func _fase_mia(k: String) -> bool:
	if m == null or m.finita():
		return false
	var r := m.richiesta()
	return r.get("k", "") == k and _chi(int(r["lato"])) == "io"

func _aggiorna_tutto() -> void:
	if m == null or lbl_data == null:
		return
	lbl_data.text = "%s %d  ·  turno %d di %d" % [Dati.MESI[m.s["mese"]], m.s["anno"], mini(int(m.s["turno"]), int(m.scen["turni"])), int(m.scen["turni"])]
	var r := m.richiesta()
	var fase := ""
	match r.get("k", ""):
		"movimento": fase = "movimento"
		"dichiara": fase = "dichiarazione degli attacchi"
		"citta", "assalto", "continua", "resta": fase = "battaglie"
	if m.finita():
		lbl_fase.text = "Partita finita"
	else:
		lbl_fase.text = "%s — %s%s" % [Dati.LATI[m.s["lato"]], fase, "  (inverno)" if m.inverno() else ""]
	var p0 := m.punti(0)
	var p1 := m.punti(1)
	lbl_pv.text = "Punti vittoria  Francia %d  ·  Coalizione %d" % [p0["tot"], p1["tot"]]
	diario.text = "\n".join(m.s["log"].slice(-160))
	_aggiorna_pezzi()
	_aggiorna_evidenze()
	_aggiorna_pannello()

func _aggiorna_pannello() -> void:
	for c in box_azioni.get_children():
		c.queue_free()
	for c in pannello_info.get_children():
		c.queue_free()
	if m.finita():
		lbl_stato.text = "La partita è finita."
		box_azioni.add_child(bottone("Vedi il risultato", _mostra_fine, 20))
		_info_esagono(sel_hex)
		return
	var r := m.richiesta()
	var lato := int(r.get("lato", 0))
	var chi := _chi(lato)
	if chi != "io":
		lbl_stato.text = "Tocca a: %s%s" % [Dati.LATI[lato], " (IA)" if chi == "ia" else " (in attesa dell'avversario)"]
		_info_esagono(sel_hex)
		return
	match r["k"]:
		"movimento":
			lbl_stato.text = "%s: movimento. Tocca un tuo esercito, scegli il capo e le truppe, poi la destinazione." % Dati.LATI[lato]
			box_azioni.add_child(bottone("Fine del movimento", func():
				_annulla_selezione()
				_invia({"a": "fine"}), 22))
			if sel_hex != "" and m.puo_trincerare(sel_hex) and m.sp_in(sel_hex, lato) > 0:
				box_azioni.add_child(bottone("Trincera le truppe ferme qui", func(): _invia({"a": "trincea", "h": sel_hex}), 18))
			_pannello_movimento()
		"dichiara":
			lbl_stato.text = "%s: dichiara gli attacchi. Tocca un tuo esercito e poi l'esagono nemico (in rosso). Poi «Combatti»." % Dati.LATI[lato]
			box_azioni.add_child(bottone("Combatti! (%d attacchi)" % m.s["batt"].size() if not m.s["batt"].is_empty() else "Nessun attacco: fine turno", func():
				_annulla_selezione()
				_invia({"a": "fine"}), 22))
			for b in m.s["batt"]:
				var rr := HBoxContainer.new()
				rr.add_child(riga_lbl("%s » %s" % [Mappa.nome(b["att"]), Mappa.nome(b["dif"])], F_TESTO, 18))
				var su: String = b["dif"]
				rr.add_child(bottone("annulla", func(): _invia({"a": "annulla", "su": su}), 15))
				box_azioni.add_child(rr)
			_info_esagono(sel_hex)
		_:
			lbl_stato.text = "Battaglia in corso: decidi."
			_mostra_scelta_battaglia(r)
			_info_esagono(sel_hex)

func _info_esagono(h: String) -> void:
	if h == "" or m == null:
		pannello_info.add_child(etichetta("Tocca un esagono per vederne il contenuto. Trascina per spostare la mappa, rotella o due dita per lo zoom, tasto destro o due dita per ruotare.", F_CORSIVO, 17, C_SPENTO))
		return
	pannello_info.add_child(etichetta(Mappa.nome(h), F_TITOLO, 22, C_BORDEAUX))
	var riga := "Terreno: %s · area %d" % [Dati.NOMI_TERRENO.get(Mappa.terreno(h), ""), Mappa.area(h)]
	if Mappa.ha_citta(h):
		var ctl := m.controllore(h)
		riga += "\n%s (fortezza: %d PF)%s" % [{"capitale": "Capitale", "maggiore": "Città maggiore", "minore": "Città minore"}[Mappa.tipo_citta(h)],
			Dati.capienza(Mappa.tipo_citta(h)), ("\nControllo: " + Dati.LATI[ctl]) if ctl >= 0 else ""]
	if m.s["trincee"].has(h):
		riga += "\nTrincee"
	if m.s["assedi"].has(h):
		riga += "\nAssedio, livello %d" % int(m.s["assedi"][h]["l"])
	pannello_info.add_child(etichetta(riga, F_TESTO, 18))
	for l in [0, 1, 2]:
		var capi := m.capi_in(h, l)
		var ids := m.unita_in(h, l)
		if capi.is_empty() and ids.is_empty():
			continue
		pannello_info.add_child(etichetta("%s — %d PF" % [Dati.LATI[l], m.sp_in(h, l)], F_GRASSETTO, 19, COL_LATO[l].darkened(0.3)))
		for id in capi:
			var c: Dictionary = m.s["capi"][id]
			var rr := HBoxContainer.new()
			rr.add_child(immagine("res://assets/pedine/%s.webp" % c["img"], 44, 42))
			rr.add_child(etichetta("%s, comando %d" % [c["nome"], int(c["v"])], F_TESTO, 18))
			pannello_info.add_child(rr)
		for id in ids:
			pannello_info.add_child(_riga_unita(id, false))

func _riga_unita(id: String, con_spin: bool) -> HBoxContainer:
	var u: Dictionary = m.s["unita"][id]
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 6)
	var img := _img_unita(u["n"], u["s"], u["t"], 1)
	if img != "":
		rr.add_child(immagine("res://assets/pedine/%s.webp" % img, 44, 42))
	var nome: String = Dati.TIPI[u["t"]]["nome"]
	var naz: String = Dati.MINORI.get(u["s"], "") if u["s"] != "" else Dati.NAZ[u["n"]]["nome"]
	var extra := ""
	if u["in"]:
		extra = ", in città"
	if u["mo"]:
		extra += ", già mossa"
	var l := etichetta("%d PF %s (%s, morale %d%s)" % [int(u["sp"]), nome, naz, Dati.morale(u["n"], u["s"], u["t"]), extra], F_TESTO, 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rr.add_child(l)
	if con_spin:
		var sp := SpinBox.new()
		sp.min_value = 0
		sp.max_value = int(u["sp"])
		sp.value = int(sel_porta.get(id, 0))
		sp.custom_minimum_size.x = 96
		sp.value_changed.connect(func(v):
			if int(v) > 0:
				sel_porta[id] = int(v)
			else:
				sel_porta.erase(id)
			_ricalcola_raggio())
		rr.add_child(sp)
	return rr

# ---------- movimento

func _pannello_movimento() -> void:
	var h := sel_hex
	if h == "":
		_info_esagono("")
		return
	var lato: int = m.s["lato"]
	var capi := m.capi_in(h, lato)
	var ids := []
	for id in m.unita_in(h, lato):
		var u: Dictionary = m.s["unita"][id]
		if not u["mo"] and not (u["in"] and m.s["assedi"].has(h)):
			ids.append(id)
	if capi.is_empty() and ids.is_empty():
		_info_esagono(h)
		return
	pannello_info.add_child(etichetta(Mappa.nome(h), F_TITOLO, 22, C_BORDEAUX))
	if not capi.is_empty():
		pannello_info.add_child(etichetta("Capi (scegline uno per muovere):", F_GRASSETTO, 18))
		for id in capi:
			var c: Dictionary = m.s["capi"][id]
			var rr := HBoxContainer.new()
			rr.add_child(immagine("res://assets/pedine/%s.webp" % c["img"], 52, 50))
			var resto := m.mp_capo(id) - int(c["mp"])
			var b := Button.new()
			b.text = "%s (%d) · %d PM" % [c["nome"], int(c["v"]), resto]
			b.toggle_mode = true
			b.button_pressed = sel_capo == id
			b.add_theme_font_size_override("font_size", 17)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var cid: String = id
			b.pressed.connect(func(): _scegli_capo(cid))
			rr.add_child(b)
			pannello_info.add_child(rr)
	if not ids.is_empty():
		pannello_info.add_child(etichetta("Truppe da portare (punti forza):", F_GRASSETTO, 18))
		for id in ids:
			pannello_info.add_child(_riga_unita(id, true))
		var rb := HBoxContainer.new()
		rb.add_child(bottone("Tutte", func(): _porta_tutte(), 16))
		rb.add_child(bottone("Nessuna", func():
			sel_porta.clear()
			_ricalcola_raggio()
			_aggiorna_pannello(), 16))
		pannello_info.add_child(rb)
	var g := m.info_gruppo(sel_capo, sel_porta)
	var t := ""
	if sel_capo == "" and sel_porta.is_empty():
		t = "La fanteria si muove solo con un capo del suo colore (al massimo 10 PF, 12 con Napoleone o Wellington) e per 3 punti movimento; la cavalleria anche da sola, per 4."
	elif not g["ok"]:
		t = "Non si può: " + str(g["errore"]) + "."
	else:
		t = "Clicca un esagono evidenziato. Oltre i %d PM delle truppe serve la marcia forzata (giallo, arancio, rosso): un dado decide quanto si va avanti e si può perdere un punto forza." % int(g["mp_truppe"]) if not sel_porta.is_empty() else "Il capo si muove da solo (%d PM)." % int(g["mp_capo"])
	pannello_info.add_child(etichetta(t, F_CORSIVO, 17, C_SPENTO))
	# nemici nello stesso esagono, ecc.
	for l in [1 - lato]:
		if m.sp_in(h, l) > 0:
			pannello_info.add_child(etichetta("Nemici qui: %d PF" % m.sp_in(h, l), F_GRASSETTO, 18, C_ROSSO))

func _scegli_capo(id: String) -> void:
	if sel_capo == id:
		sel_capo = ""
	else:
		sel_capo = id
		# truppe proposte: come farebbe l'IA (il meglio fino al massimo)
		sel_porta = ia[0]._truppe(id, sel_hex, m.s["lato"]) if int(m.s["capi"][id]["mp"]) == 0 else {}
	_ricalcola_raggio()
	_aggiorna_pannello()

func _porta_tutte() -> void:
	sel_porta.clear()
	var lato: int = m.s["lato"]
	var tot := 0
	var max_sp := m.max_porta(sel_capo) if sel_capo != "" else 99
	for id in m.unita_in(sel_hex, lato):
		var u: Dictionary = m.s["unita"][id]
		if u["mo"] or (sel_capo == "" and not Dati.e_cavalleria(u["t"])):
			continue
		if sel_capo != "" and not Dati.e_cavalleria(u["t"]) and u["n"] != m.s["capi"][sel_capo]["n"]:
			continue
		var n := mini(int(u["sp"]), max_sp - tot)
		if n > 0:
			sel_porta[id] = n
			tot += n
	_ricalcola_raggio()
	_aggiorna_pannello()

func _ricalcola_raggio() -> void:
	rag = {}
	if _fase_mia("movimento") and (sel_capo != "" or not sel_porta.is_empty()):
		rag = m.raggiungibili(sel_capo, sel_porta, 3)
	_aggiorna_evidenze()

func _annulla_selezione() -> void:
	sel_capo = ""
	sel_porta = {}
	rag = {}
	if m != null and in_partita:
		_aggiorna_evidenze()

func _clic(h: String) -> void:
	if m == null:
		return
	if _fase_mia("movimento") and h != "" and rag.has(h):
		var fm := int(rag[h]["fm"])
		var d := {"a": "muovi", "capo": sel_capo, "porta": sel_porta.duplicate(), "verso": h, "fm": fm}
		var capo := sel_capo
		_annulla_selezione()
		await _invia(d)
		# il capo può continuare da solo: resta selezionato nel nuovo esagono
		if capo != "" and m.s["capi"].has(capo) and m.s["capi"][capo]["h"] != "":
			sel_hex = m.s["capi"][capo]["h"]
		else:
			sel_hex = h
		_aggiorna_tutto()
		return
	if _fase_mia("dichiara") and h != "" and sel_hex != "":
		for b in m.s["batt"]:
			if b["dif"] == h and b["att"] == sel_hex:
				_invia({"a": "annulla", "su": h})
				return
		for p in m.attacchi_possibili():
			if p[0] == sel_hex and p[1] == h:
				_invia({"a": "dichiara_ui", "da": sel_hex, "su": h})
				return
	sel_hex = h
	_annulla_selezione()
	_aggiorna_tutto()

# ---------- battaglie

const TESTI_SCELTA := {
	"fuori": "Battaglia campale fuori dalle mura",
	"dentro": "Chiudi le truppe migliori in città",
	"assalto": "Assalto alle mura",
	"assedio": "Assedio",
	"rinuncia": "Rinuncia all'attacco",
	"continua": "Continua l'attacco",
	"interrompi": "Interrompi la battaglia",
	"resta": "Resta e combatti",
	"ritirati": "Ritirati",
}

func _mostra_scelta_battaglia(r: Dictionary) -> void:
	var b: Dictionary = m.s["batt"][int(r["b"])]
	var t := ""
	match r["k"]:
		"citta":
			t = "%s attaccano %s. Puoi chiudere fino a %d PF dentro le fortificazioni (la loro forza vale doppio contro un assalto) o combattere in campo aperto." % [Dati.LATI_BREVI[1 - int(r["lato"])], Mappa.nome(b["dif"]), Dati.capienza(Mappa.tipo_citta(b["dif"]))]
		"assalto":
			t = "Il nemico si è chiuso in %s (%d PF, che valgono doppio). Assalto subito o assedio (ogni mese un dado: la città cade se esce un numero non superiore ai mesi d'assedio)?" % [Mappa.nome(b["dif"]), m.sp_in(b["dif"], 1 - int(r["lato"]), false, true)]
		"continua":
			t = "Fine del round a %s. Continuare l'attacco?" % Mappa.nome(b["dif"])
		"resta":
			t = "Il nemico continua ad attaccare %s. Resti o ti ritiri di un esagono?" % Mappa.nome(b["dif"])
	box_azioni.add_child(etichetta(t, F_TESTO, 18))
	if not b["rapporti"].is_empty():
		box_azioni.add_child(_vista_rapporto(b["rapporti"][-1], false))
	for o in r["opzioni"]:
		var v: String = o
		box_azioni.add_child(bottone(TESTI_SCELTA.get(v, v), func(): _invia({"a": "scelta", "v": v}), 19))
	_centra_su(b["dif"])

func _vista_rapporto(rep: Dictionary, grande: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g := int(rep["grande"])
	var la := 0 if g == 0 else 1
	var fs := 19 if grande else 16
	v.add_child(etichetta("Battaglia di %s — round %d%s" % [Mappa.nome(rep["dif"]), int(rep["r"]), " (assalto)" if rep["tipo"] == "assalto" else ""], F_GRASSETTO, fs + 2, C_BORDEAUX))
	v.add_child(etichetta("Forza più grande: %s %d PF (comanda %s) contro %s %d PF (comanda %s). Rapporto %s." % [
		Dati.LATI_BREVI[g], maxi(rep["forze"][0], rep["forze"][1]), rep["capi"][0], Dati.LATI_BREVI[1 - g], mini(rep["forze"][0], rep["forze"][1]), rep["capi"][1], rep["rapporto"]], F_TESTO, fs))
	var mods := []
	for x in rep["mods"]:
		if int(x[1]) != 0:
			mods.append("%s %+d" % [x[0], int(x[1])])
	var dadi := HBoxContainer.new()
	dadi.add_theme_constant_override("separation", 8)
	for d in rep["dadi"]:
		dadi.add_child(Dado.new(int(d), false, 40.0 if grande else 30.0))
	dadi.add_child(riga_lbl("  modificatori %+d%s  »  %d" % [int(rep["mod"]), (" (" + ", ".join(mods) + ")") if not mods.is_empty() else "", int(rep["tiro"])], F_TESTO, fs))
	v.add_child(dadi)
	v.add_child(etichetta("Risultato: %s %s (perde %d PF), %s %s (perde %d PF)." % [Dati.LATI_BREVI[g], _ris(rep["ris"][0]), int(rep["perdite"][0]), Dati.LATI_BREVI[1 - g], _ris(rep["ris"][1]), int(rep["perdite"][1])], F_GRASSETTO, fs))
	return v

func _ris(r: String) -> String:
	match r:
		"0": return "nessun danno"
		"1": return "perdite"
		"D1": return "perdite e demoralizzazione 1"
		"D2": return "perdite e demoralizzazione 2"
		"D3": return "perdite e demoralizzazione 3"
	return r

func _mostra_rapporti() -> void:
	if coda_rapporti.is_empty() or popup_aperto:
		return
	var reps := coda_rapporti.duplicate()
	coda_rapporti.clear()
	var v := _apri_popup("Battaglie", 980)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(940, mini(560, 190 * reps.size()))
	v.add_child(sc)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	for rep in reps:
		col.add_child(_vista_rapporto(rep, true))
		col.add_child(HSeparator.new())
	v.add_child(bottone("Avanti", func():
		_chiudi_popup()
		_aggiorna_tutto(), 22))

func _mostra_fine() -> void:
	var e: Dictionary = m.s["esito"]
	var vince := int(e.get("vince", -1))
	var tit: String = "Pareggio" if vince < 0 else "Vittoria: " + Dati.LATI[vince]
	var v := _apri_popup(tit, 760)
	v.add_child(etichetta(str(e.get("perche", "")), F_TESTO, 21))
	for l in [0, 1]:
		var p := m.punti(l)
		v.add_child(etichetta("%s: %d punti (battaglie %d, città %d: %s)" % [Dati.LATI[l], p["tot"], p["battaglie"], p["citta"], ", ".join(p["elenco"]) if not p["elenco"].is_empty() else "nessuna"], F_TESTO, 19))
	var r := HBoxContainer.new()
	r.add_child(bottone("Guarda la mappa", _chiudi_popup, 20))
	r.add_child(bottone("Menu principale", mostra_menu, 20))
	v.add_child(r)

# =============================================================================================
# Ciclo: IA, rete, decisioni

func _process(delta: float) -> void:
	if not in_partita or m == null:
		return
	if m.finita():
		return
	if not coda_rapporti.is_empty() and not popup_aperto and _ci_sono_umani():
		_mostra_rapporti()
		return
	if popup_aperto:
		return
	var r := m.richiesta()
	if r.is_empty():
		return
	var chi := _chi(int(r["lato"]))
	if chi == "ia":
		if invio_in_corso:
			return
		attesa += delta * velocita
		var pausa := 0.45 if r["k"] == "movimento" else 0.6
		if not _ci_sono_umani():
			pausa = 0.12
		if attesa >= pausa:
			attesa = 0.0
			var d: Dictionary = ia[int(r["lato"])].decidi(r)
			_invia(d)
	elif chi == "remoto" and not aspetto_rete:
		_aspetta_remoto()

func _ci_sono_umani() -> bool:
	return _chi(0) == "io" or _chi(1) == "io"

func _aspetta_remoto() -> void:
	aspetto_rete = true
	var n: int = m.s["azioni"]
	var d = await net.get_decision(codice, n)
	if d is Dictionary and not d.is_empty() and int(m.s["azioni"]) == n:
		_applica(d)
	else:
		await get_tree().create_timer(1.0).timeout
	aspetto_rete = false

## Invia una decisione: in rete la pubblica prima di applicarla
func _invia(d: Dictionary) -> void:
	if d.get("a", "") == "dichiara_ui":
		d = {"a": "attacco", "da": d["da"], "su": d["su"]}
	if invio_in_corso:
		return
	invio_in_corso = true
	if online:
		var n: int = m.s["azioni"]
		var ok := await net.post_decision(codice, n, d)
		if not ok:
			_notifica("Rete: non riesco a inviare la mossa (" + net.last_error + "). Riprova.")
			invio_in_corso = false
			return
	_applica(d)
	invio_in_corso = false

func _applica(d: Dictionary) -> void:
	var lato_prima: int = m.s["lato"]
	if not m.applica(d):
		if d.get("a", "") == "muovi" and _chi(lato_prima) == "io":
			_notifica("Mossa non valida")
		elif _chi(lato_prima) == "ia":
			# l'IA non deve bloccare la partita
			m.applica({"a": "fine"})
		return
	for e in m.eventi:
		match e["k"]:
			"battaglia":
				coda_rapporti.append(e["rep"])
			"annuncio":
				_notifica(e["t"])
			"dado":
				if _ci_sono_umani():
					_notifica("%s: dado %s" % [e["titolo"], ", ".join(e["dadi"].map(func(x): return str(x)))])
			"fine":
				pass
	if int(m.s["lato"]) != lato_prima:
		sel_hex = ""
		_annulla_selezione()
		_salva(false)
	_aggiorna_tutto()
	if m.finita():
		_salva(true)
		_mostra_fine()

func _salva(subito: bool) -> void:
	if online or m == null:
		return
	var st := {"motore": m.s, "umani": umani, "carattere": carattere_ia}
	var f := FileAccess.open(SALVA_LOCALE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(st))
		f.close()
	var ora := Time.get_unix_time_from_system()
	if (subito or ora - ultimo_salvataggio > 20.0) and not salvataggio_in_corso:
		ultimo_salvataggio = ora
		salvataggio_in_corso = true
		await net.salva_partita(st)
		salvataggio_in_corso = false
