extends Control
## AURORA EM CAMPO on screen: today's edition as a sheet of newsprint, and the archive of
## every edition so far - the run, told back as front pages.
signal closed
const UI = preload("res://scripts/story_ui.gd")
const Press = preload("res://scripts/story_press.gd")
const Photo = preload("res://scripts/news_scene.gd")

var cup
var hud
var player_skin = 0
var number = -1
var scroll: ScrollContainer
var column: VBoxContainer
var title: Label
var archive_button: Button
var showing_archive = false
var render_busy = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ground = ColorRect.new()
	ground.color = Color("1b1d1e")
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	scroll.add_child(column)
	var bar = HBoxContainer.new()
	bar.name = "Bar"
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	bar.add_child(UI.key(hud, "‹  TAÇA", false, func(): closed.emit(), 52))
	title = UI.label("BANCA DA ROSA", 20, UI.GOLD, "display", false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)
	archive_button = UI.key(hud, "ARQUIVO", false, toggle_archive, 52)
	bar.add_child(archive_button)
	resized.connect(arrange)
	arrange()

func arrange() -> void:
	var bar: Control = get_node("Bar")
	var top = 16.0
	bar.position = Vector2(16, top)
	bar.size = Vector2(size.x - 32, 52)
	var width = minf(size.x - 24, 760)
	scroll.position = Vector2((size.x - width) * 0.5, top + 64)
	scroll.size = Vector2(width, size.y - top - 64)

func open(edition_number: int) -> void:
	number = clampi(edition_number, 0, Press.editions_available(cup) - 1)
	showing_archive = false
	# Reading the newest edition is what puts the NOVA EDIÇÃO badge out.
	if number > cup.editions_read:
		cup.editions_read = number
		cup.save()
	show_edition()

func toggle_archive() -> void:
	showing_archive = not showing_archive
	if showing_archive: show_archive()
	else: show_edition()

func clear() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0

# --- the archive -------------------------------------------------------------------------

func show_archive() -> void:
	clear()
	archive_button.text = "EDIÇÃO"
	title.text = "ARQUIVO DA TAÇA"
	var intro = UI.label("Todas as edições de AURORA EM CAMPO desde a abertura. A tua Taça, capa a capa.", 17, UI.MUTED, "italic")
	column.add_child(intro)
	var total = Press.editions_available(cup)
	for n in range(total - 1, -1, -1):
		var e: Dictionary = Press.edition(cup, n)
		var entry = Button.new()
		entry.focus_mode = Control.FOCUS_NONE
		entry.custom_minimum_size.y = 128
		var face_color = UI.PAPER if e.tier != "special" else Color("22262a")
		entry.add_theme_stylebox_override("normal", UI.panel_style(face_color, UI.PAPER_SHADE, 4, 0))
		entry.add_theme_stylebox_override("hover", UI.panel_style(face_color.darkened(0.04), UI.GOLD, 4, 0))
		entry.add_theme_stylebox_override("pressed", UI.panel_style(face_color.darkened(0.08), UI.GOLD, 4, 0))
		entry.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		column.add_child(entry)
		var face = Control.new()
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(func(): draw_archive_entry(face, e, n > cup.editions_read))
		entry.add_child(face)
		entry.pressed.connect(func(): open(n))

func draw_archive_entry(c: Control, e: Dictionary, unread: bool) -> void:
	var dark = e.tier == "special"
	var ink = UI.PAPER if dark else UI.INK
	var soft = Color(ink, 0.6)
	var mast = UI.font("headline_black")
	c.draw_string(UI.font("display"), Vector2(18, 26), "N.º %03d   ·   DIA %d   ·   %s" % [e.number, e.day, e.round], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, soft)
	c.draw_line(Vector2(18, 36), Vector2(c.size.x - 18, 36), soft, 1.0)
	c.draw_string(mast, Vector2(18, 72), String(e.headline), HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 36, 28, ink)
	c.draw_string(UI.font("italic"), Vector2(18, 104), String(e.dek), HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 36, 14, soft)
	var tag = {"cover": "CAPA", "special": "EDIÇÃO ESPECIAL", "historic": "EDIÇÃO HISTÓRICA", "headline": "MANCHETE"}.get(e.tier, "")
	if tag != "":
		var w = UI.font("display").get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		c.draw_rect(Rect2(c.size.x - w - 34, 12, w + 16, 20), UI.GOLD_DEEP if e.tier == "historic" else UI.PRESS_RED)
		c.draw_string(UI.font("display"), Vector2(c.size.x - w - 26, 27), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.PAPER)
	if unread:
		c.draw_circle(Vector2(c.size.x - 22, c.size.y - 22), 8, UI.PRESS_RED, true, -1, true)

# --- an edition --------------------------------------------------------------------------

func show_edition() -> void:
	clear()
	archive_button.text = "ARQUIVO"
	title.text = "AURORA EM CAMPO"
	var e: Dictionary = Press.edition(cup, number)
	var sheet = Sheet.new()
	sheet.tier = e.tier
	column.add_child(sheet)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	sheet.add_child(page)
	masthead(page, e)
	var historic = e.tier == "historic"
	if e.tier in ["cover", "special", "historic"]:
		# The big days: the photograph first, the width of the page, then the headline.
		picture(page, e.photo, e.number, true)
		page.add_child(UI.label(String(e.headline), 96 if historic else (54 if e.tier != "special" else 58), UI.INK, "headline_black"))
	else:
		page.add_child(UI.label(String(e.headline), 46 if e.tier == "headline" else 40, UI.INK, "headline_black"))
		picture(page, e.photo, e.number, false)
	var dek = UI.label(String(e.dek), 22 if historic else 20, UI.INK, "italic")
	page.add_child(dek)
	UI.rule(page, UI.INK, 1)
	page.add_child(byline("REDAÇÃO AURORA EM CAMPO", e))
	page.add_child(UI.label(String(e.body), 18, UI.INK, "body"))
	for s in e.stories:
		UI.rule(page, UI.INK, 2 if s.get("twist", false) else 1)
		var kicker_row = HBoxContainer.new()
		kicker_row.add_theme_constant_override("separation", 10)
		page.add_child(kicker_row)
		if s.get("twist", false):
			kicker_row.add_child(stamp("EXCLUSIVO"))
		var kicker = UI.label(String(s.kicker), 15, UI.PRESS_RED, "display", false)
		kicker_row.add_child(kicker)
		page.add_child(UI.label(String(s.headline), 30, UI.INK, "headline"))
		if not s.photo.is_empty():
			picture(page, s.photo, e.number, false)
		page.add_child(UI.label(String(s.body), 17, UI.INK_SOFT, "body"))
	if not e.results.is_empty():
		UI.rule(page, UI.INK, 3)
		page.add_child(UI.label("RESULTADOS DA RONDA", 18, UI.INK, "display", false))
		for row in e.results:
			page.add_child(result_row(row))
	if not e.ahead.is_empty():
		UI.rule(page, UI.INK, 3)
		var ahead = PanelContainer.new()
		ahead.add_theme_stylebox_override("panel", UI.panel_style(UI.INK, Color.TRANSPARENT, 2, 16))
		page.add_child(ahead)
		var box = VBoxContainer.new()
		ahead.add_child(box)
		box.add_child(UI.label("NA PRÓXIMA RONDA  ·  %s" % e.ahead.round, 15, UI.GOLD, "display", false))
		box.add_child(UI.label("%s  vs  %s" % [Press.player_name().to_upper(), String(e.ahead.name).to_upper()], 30, UI.PAPER, "headline_black"))
		box.add_child(UI.label("%d pilotos ainda em prova. Encontro confirmado pela organização." % e.ahead.field, 15, Color(UI.PAPER, 0.7), "body"))
	UI.rule(page, UI.INK, 1)
	var foot = UI.label("À venda na %s  ·  Praça da Taça  ·  «%s»" % [Press.KIOSK_NAME, Press.kiosk_line(cup) if number == Press.editions_available(cup) - 1 else String(e.kiosk)], 13, UI.INK_SOFT, "italic")
	page.add_child(foot)
	UI.gap(column, 30)

func masthead(page: VBoxContainer, e: Dictionary) -> void:
	var special = e.tier == "special"
	var historic = e.tier == "historic"
	var band = PanelContainer.new()
	band.add_theme_stylebox_override("panel", UI.panel_style(UI.INK if special else (Color("2b2112") if historic else Color(0, 0, 0, 0)), Color.TRANSPARENT, 0, 10))
	page.add_child(band)
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	band.add_child(stack)
	var ink = UI.PAPER if special else (UI.GOLD if historic else UI.INK)
	var top = UI.label("DIÁRIO DA TAÇA AURORA   ·   EDIÇÃO N.º %03d   ·   DIA %d" % [e.number, e.day], 13, Color(ink, 0.75), "display", false)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(top)
	var name_label = UI.label("AURORA EM CAMPO", 58, ink, "headline_black", false)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(name_label)
	UI.rule(stack, ink, 3)
	var strap = HBoxContainer.new()
	stack.add_child(strap)
	var left = UI.label(String(e.round), 15, ink, "display", false)
	strap.add_child(left)
	var right = UI.label({"special": "EDIÇÃO ESPECIAL", "historic": "EDIÇÃO HISTÓRICA · GUARDE ESTE EXEMPLAR", "cover": "EDIÇÃO DE CAPA"}.get(e.tier, "2 ⚡"), 15, UI.PRESS_RED if special else ink, "display", false)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	strap.add_child(right)
	UI.rule(stack, ink, 1)

func byline(who: String, e: Dictionary) -> Label:
	return UI.label("%s   ·   %s" % [who, "PRAÇA DA TAÇA"], 12, UI.INK_SOFT, "display", false)

func stamp(text: String) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.panel_style(UI.PRESS_RED, Color.TRANSPARENT, 2, 4))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l = UI.label(text, 13, UI.PAPER, "display", false)
	p.add_child(l)
	return p

func result_row(row: Dictionary) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var yours = bool(row.yours)
	var left = UI.label(String(row.left), 18, UI.INK, "body_bold" if yours else "body", false)
	h.add_child(left)
	var score = UI.label(String(row.score), 20, UI.PRESS_RED if yours else UI.INK, "headline_black", false)
	score.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	h.add_child(score)
	var right = UI.label(String(row.right), 18, UI.INK, "body", false)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(right)
	return h

func picture(parent: VBoxContainer, shot: Dictionary, edition_number: int, wide: bool) -> void:
	# A press photograph: a staged scene with the real models - or the finished press
	# image, if one has been made for this slot - with its caption and credit under it.
	if shot.is_empty(): return
	var frame = AspectRatioContainer.new()
	frame.ratio = 16.0 / 9.0 if not wide else 3.0 / 2.0
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size.y = 220 if not wide else 300
	frame.resized.connect(func(): frame.custom_minimum_size.y = frame.size.x / frame.ratio)
	parent.add_child(frame)
	var holder = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UI.panel_style(Color("2a2e30"), Color.TRANSPARENT, 0, 0))
	frame.add_child(holder)
	var image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	holder.add_child(image)
	var asset = String(shot.get("asset", ""))
	if asset != "" and ResourceLoader.exists(asset):
		image.texture = load(asset)
	else:
		image.set_meta("shot", shot)
		image.set_meta("variant", edition_number)
		image.add_to_group("story_photos")
	var caption = UI.label(String(shot.get("caption", "")), 14, UI.INK_SOFT, "italic")
	parent.add_child(caption)
	var credit = UI.label("FOTO: ARQUIVO AURORA EM CAMPO  ·  %s" % String(shot.category), 11, Color(UI.INK_SOFT, 0.8), "display", false)
	parent.add_child(credit)

func _process(_dt: float) -> void:
	# Photographs are developed one at a time, when they scroll into view.
	if not is_visible_in_tree() or render_busy: return
	var view = scroll.get_global_rect()
	for node in get_tree().get_nodes_in_group("story_photos"):
		if not is_ancestor_of(node) or node.texture != null: continue
		if view.intersects(node.get_global_rect()):
			develop(node)
			break

func develop(target: TextureRect) -> void:
	render_busy = true
	target.remove_from_group("story_photos")
	var shot: Dictionary = target.get_meta("shot")
	var cast: Dictionary = {}
	for who in [String(shot.subject), String(shot.other)]:
		if who != "": cast[who] = UI.spec(cup, who, player_skin)
	cast["Repórter"] = [120, "9aa7ab"]
	var viewport = Photo.new()
	add_child(viewport)
	var story = {"cenario": shot.scene, "personagemPrincipal": shot.subject, "personagemSecundario": shot.other, "visual_variant": int(target.get_meta("variant")), "cast": cast}
	if String(shot.get("set", "")) != "":
		story["set"] = shot.set
	viewport.setup(story)
	await RenderingServer.frame_post_draw
	if is_instance_valid(target) and DisplayServer.get_name() != "headless":
		var picture_data = viewport.get_texture().get_image()
		if picture_data != null: target.texture = ImageTexture.create_from_image(picture_data)
	viewport.queue_free()
	render_busy = false

class Sheet extends PanelContainer:
	## Newsprint: cream paper, a fold across the middle, crop marks at the corners and a
	## faint grain, so it reads as a real paper and not a panel.
	var tier = "regular"
	func _ready() -> void:
		var s = StyleBoxFlat.new()
		s.bg_color = Color("f3eee1") if tier != "historic" else Color("f6ecd2")
		s.set_content_margin_all(26)
		s.shadow_color = Color(0, 0, 0, 0.5)
		s.shadow_size = 18
		s.shadow_offset = Vector2(0, 8)
		if tier == "historic":
			s.border_color = Color("c49a4c")
			s.set_border_width_all(6)
		add_theme_stylebox_override("panel", s)
		resized.connect(queue_redraw)
	func _draw() -> void:
		var w = size.x
		var h = size.y
		for i in range(0, int(h), 7):
			draw_line(Vector2(0, i), Vector2(w, i), Color(0.4, 0.33, 0.2, 0.025 if i % 14 == 0 else 0.012), 1.0)
		# The fold.
		var fold = h * 0.42
		draw_rect(Rect2(0, fold - 10, w, 10), Color(0.3, 0.25, 0.15, 0.035))
		draw_line(Vector2(0, fold), Vector2(w, fold), Color(0.3, 0.25, 0.15, 0.10), 1.2)
		draw_rect(Rect2(0, fold + 1, w, 12), Color(1, 1, 1, 0.05))
		for corner in [Vector2(8, 8), Vector2(w - 8, 8), Vector2(8, h - 8), Vector2(w - 8, h - 8)]:
			var sx = 1.0 if corner.x < w * 0.5 else -1.0
			var sy = 1.0 if corner.y < h * 0.5 else -1.0
			draw_line(corner, corner + Vector2(12 * sx, 0), Color(0, 0, 0, 0.35), 1.0)
			draw_line(corner, corner + Vector2(0, 12 * sy), Color(0, 0, 0, 0.35), 1.0)
		# Registration dots in the four inks, top right, like a real print run.
		var dots = [Color("00a6d6"), Color("d6007e"), Color("f2d100"), Color("111111")]
		for i in range(4):
			draw_circle(Vector2(w - 70 + i * 12, h - 14), 3.5, Color(dots[i], 0.55), true, -1, true)
