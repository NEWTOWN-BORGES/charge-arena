extends VBoxContainer
signal tree_requested(who: String)
## Publication view; editorial data and staged photographs live in separate modules.
const News = preload("res://scripts/cup_news.gd")
const Photo = preload("res://scripts/news_scene.gd")
const INK = Color("132d36")
const PAPER = Color("f0ecdf")
const SOFT_INK = Color("52636a")
const GOLD = Color("e8bd78")
var cup
var edition_number = -1
var body: VBoxContainer
var archive: OptionButton
var opened_id = ""
var render_jobs = 0
func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	edition_number = cup.wins if edition_number < 0 else edition_number
	var band = HBoxContainer.new()
	add_child(band)
	var branding = label("ARQUIVO DA TAÇA", 16, GOLD)
	branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.add_child(branding)
	archive = OptionButton.new()
	archive.custom_minimum_size = Vector2(230, 52)
	archive.add_theme_font_size_override("font_size", 18)
	for n in range(cup.wins, -1, -1): archive.add_item("EDIÇÃO %02d%s" % [n, " · NOVA" if n == cup.wins else ""], n)
	archive.selected = cup.wins - edition_number
	archive.item_selected.connect(func(i): edition_number = archive.get_item_id(i); front())
	archive.add_theme_stylebox_override("normal", control_style(INK, Color("39515a")))
	archive.add_theme_stylebox_override("hover", control_style(Color("28424a"), GOLD))
	band.add_child(archive)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	add_child(body)
	front()
func label(value: String, points: int, color: Color = PAPER) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", points)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 5)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
func clear() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
func button(value: String, callback: Callable) -> Button:
	var b = Button.new()
	b.text = value
	b.custom_minimum_size.y = 60
	b.add_theme_font_size_override("font_size", 18)
	var style = StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = Color("648b8e")
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	b.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = Color("33535a")
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", PAPER)
	b.pressed.connect(callback)
	return b
func paper() -> VBoxContainer:
	var p = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = PAPER
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 24
	s.content_margin_bottom = 24
	p.add_theme_stylebox_override("panel", s)
	body.add_child(p)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	p.add_child(box)
	return box
func photograph(parent: Control, story: Dictionary) -> void:
	var ratio = AspectRatioContainer.new()
	ratio.ratio = 16.0 / 9.0
	ratio.custom_minimum_size.y = 200
	ratio.resized.connect(func(): ratio.custom_minimum_size.y = ratio.size.x * 9.0 / 16.0)
	ratio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(ratio)
	var texture = TextureRect.new()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ratio.add_child(texture)
	# Render lazily when the photograph reaches the scroll window. Release the 3D
	# staging after readback; archive browsing never accumulates live worlds.
	texture.set_meta("story", story)
	texture.set_meta("pending", true)
	texture.add_to_group("press_photos")
func _process(_dt: float) -> void:
	if not is_visible_in_tree() or render_jobs > 0: return
	for node in get_tree().get_nodes_in_group("press_photos"):
		if not is_ancestor_of(node) or not node.get_meta("pending", false): continue
		var bounds: Rect2 = node.get_global_rect()
		var visible_bounds = get_parent().get_parent().get_global_rect()
		if bounds.size.y > 10 and visible_bounds.intersects(bounds):
			node.set_meta("pending", false)
			render_photo(node)
			break
func render_photo(target: TextureRect) -> void:
	render_jobs += 1
	var viewport = Photo.new()
	add_child(viewport)
	viewport.setup(target.get_meta("story"))
	await RenderingServer.frame_post_draw
	if is_instance_valid(target) and not DisplayServer.get_name() == "headless":
		var picture = viewport.get_texture().get_image()
		if picture != null: target.texture = ImageTexture.create_from_image(picture)
	viewport.queue_free()
	render_jobs -= 1
func reset_scroll() -> void:
	var scroller = get_parent().get_parent()
	if scroller is ScrollContainer: scroller.scroll_vertical = 0
func control_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style

func rule(parent: Control, thick: int = 1) -> void:
	var line = ColorRect.new()
	line.color = INK
	line.custom_minimum_size.y = thick
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func masthead(sheet: Control) -> void:
	var logo = label("AURORA", 66, INK)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet.add_child(logo)
	var strap = label("E M   C A M P O     /     J O R N A L   D A   T A Ç A", 13, INK)
	strap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet.add_child(strap)
	rule(sheet, 3)
	var info = HBoxContainer.new()
	sheet.add_child(info)
	info.add_child(label("N.º %03d  /  %s" % [edition_number, "ABERTURA" if edition_number == 0 else "JORNADA %03d" % edition_number], 14, SOFT_INK))
	var tag = label("EDIÇÃO OFICIAL", 14, SOFT_INK)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(tag)

func section(sheet: Control, kicker: String) -> void:
	rule(sheet)
	sheet.add_child(label(kicker, 14, SOFT_INK))

func score_row(sheet: Control, left: String, result: String, right: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	sheet.add_child(row)
	row.add_child(label(left, 19, INK))
	var score = label(result, 22, INK)
	score.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(score)
	var rival = label(right, 19, INK)
	rival.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(rival)

func front() -> void:
	archive.selected = cup.wins - edition_number
	clear()
	opened_id = ""
	reset_scroll()
	var articles = News.edition(cup, edition_number)
	var lead: Dictionary = articles[0]
	var sheet = paper()
	masthead(sheet)
	photograph(sheet, lead)
	sheet.add_child(label("NA CAPA  /  " + lead.personagemPrincipal.to_upper(), 14, SOFT_INK))
	sheet.add_child(label(lead.titulo, 48, INK))
	sheet.add_child(label(lead.subtitulo, 23, SOFT_INK))
	sheet.add_child(button("LER A REPORTAGEM  ↗", func(): article(lead)))
	var report: Dictionary = articles[1]
	var report_sheet = paper()
	section(report_sheet, "02  /  NOS BASTIDORES")
	report_sheet.add_child(label(report.titulo, 34, INK))
	photograph(report_sheet, report)
	report_sheet.add_child(label(report.subtitulo, 22, SOFT_INK))
	report_sheet.add_child(button("ABRIR REPORTAGEM  ↗", func(): article(report)))
	var brief: Dictionary = articles[2]
	var notes = paper()
	section(notes, "03  /  NOTAS DA REDAÇÃO")
	notes.add_child(label(brief.titulo, 30, INK))
	notes.add_child(label(brief.subtitulo, 22, SOFT_INK))
	notes.add_child(button("LER NOTA  ↗", func(): article(brief)))
	var scores = paper()
	section(scores, "04  /  RESULTADOS OFICIAIS")
	if edition_number > 0:
		var result: Dictionary = cup.history[edition_number - 1]
		score_row(scores, "TU", "%s–%s" % result.score, result.opponent.to_upper())
		var relevant: Array = cup.rounds.filter(func(r): return r.round <= edition_number and r.stage == cup.stage_index(edition_number - 1))
		if not relevant.is_empty():
			var round_data: Dictionary = relevant.back()
			for fixture in round_data.fixtures:
				if preload("res://scripts/cup_tree_data.gd").CAST.has(fixture.winner) or preload("res://scripts/cup_tree_data.gd").CAST.has(fixture.loser):
					rule(scores)
					score_row(scores, fixture.winner, fixture.score, fixture.loser)
			scores.add_child(label("%d pilotos avançaram na chave. Todos os encontros podem ser consultados na Árvore." % round_data.winners.size(), 19, SOFT_INK))
	else:
		scores.add_child(label("1 024 inscritos no Farol. O primeiro boletim chega depois da tua primeira vitória.", 22, SOFT_INK))
	var colophon = label("AURORA EM CAMPO\nA competição tem mais de uma história.", 16, Color("a6b7bd"))
	colophon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(colophon)
func article(story: Dictionary) -> void:
	edition_number = story.jornada
	archive.selected = cup.wins - edition_number
	clear()
	reset_scroll()
	opened_id = story.id
	body.add_child(button("← VOLTAR À EDIÇÃO %03d" % edition_number, front))
	var sheet = paper()
	sheet.add_child(label("AURORA EM CAMPO  /  REPORTAGEM", 15, SOFT_INK))
	rule(sheet, 3)
	sheet.add_child(label(story.titulo, 48, INK))
	sheet.add_child(label("REDAÇÃO AURORA   ·   " + story.etapa.to_upper(), 14, SOFT_INK))
	photograph(sheet, story)
	sheet.add_child(label(story.subtitulo, 25, INK))
	rule(sheet)
	sheet.add_child(label(story.corpo, 22, SOFT_INK))
	if not story.resultado.is_empty():
		section(sheet, "O RESULTADO")
		score_row(sheet, story.personagemPrincipal, story.resultado, story.personagemSecundario)
	sheet.add_child(button("ACOMPANHAR NA ÁRVORE  ↗", func(): tree_requested.emit(story.personagemPrincipal)))
	body.add_child(button("← REGRESSAR À CAPA", front))
