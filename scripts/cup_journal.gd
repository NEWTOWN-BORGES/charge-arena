extends VBoxContainer
signal tree_requested(who: String)
## Publication view; editorial data and staged photographs live in separate modules.
const News = preload("res://scripts/cup_news.gd")
const Photo = preload("res://scripts/news_scene.gd")
const INK = Color("132d36")
const PAPER = Color("e9e5d6")
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
	var branding = label("AURORA EM CAMPO", 30, GOLD)
	branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.add_child(branding)
	archive = OptionButton.new()
	archive.custom_minimum_size = Vector2(210, 76)
	archive.add_theme_font_size_override("font_size", 23)
	for n in range(cup.wins, -1, -1): archive.add_item("EDIÇÃO %02d%s" % [n, " · NOVA" if n == cup.wins else ""], n)
	archive.selected = cup.wins - edition_number
	archive.item_selected.connect(func(i): edition_number = archive.get_item_id(i); front())
	band.add_child(archive)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	add_child(body)
	front()
func label(value: String, points: int, color: Color = PAPER) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", points if points >= 36 else roundi(points * 1.6))
	l.add_theme_color_override("font_color", color)
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
	b.custom_minimum_size.y = 76
	b.add_theme_font_size_override("font_size", 26)
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
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", s)
	body.add_child(p)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
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
func front() -> void:
	archive.selected = cup.wins - edition_number
	clear()
	opened_id = ""
	reset_scroll()
	var articles = News.edition(cup, edition_number)
	var lead: Dictionary = articles[0]
	var sheet = paper()
	sheet.add_child(label("JORNAL DA TAÇA  /  Nº %02d     •     SETOR FAROL" % edition_number, 12, INK))
	photograph(sheet, lead)
	sheet.add_child(label(lead.titulo, 48, INK))
	sheet.add_child(label(lead.subtitulo, 18, INK))
	sheet.add_child(button("LER A REPORTAGEM   ↗", func(): article(lead)))
	var report: Dictionary = articles[1]
	body.add_child(label("NOS BASTIDORES  /  REPORTAGEM", 13, GOLD))
	photograph(body, report)
	body.add_child(label(report.titulo, 25))
	body.add_child(button("ABRIR REPORTAGEM   ↗", func(): article(report)))
	body.add_child(label("TELEX   /   OUTROS SETORES", 13, GOLD))
	var brief: Dictionary = articles[2]
	body.add_child(label(brief.titulo, 20))
	body.add_child(label(brief.subtitulo, 16, Color("a6b7bd")))
	body.add_child(button("LER NOTA   ↗", func(): article(brief)))
	body.add_child(label("BOLETIM OFICIAL   /   FAROL", 13, GOLD))
	if edition_number > 0:
		var result: Dictionary = cup.history[edition_number - 1]
		body.add_child(label("TU  %s–%s  %s" % [result.score[0], result.score[1], result.opponent.to_upper()], 20))
		var round_index = mini(edition_number, 10) - 1
		var fixtures: Array = cup.rounds[round_index].fixtures
		for fixture in fixtures:
			if fixture.winner in ["FAROLEIRO", "Lira", "Vértice"] or fixture.loser == "Lira":
				body.add_child(label("%s  %s  %s" % [fixture.winner, fixture.score, fixture.loser], 16))
		body.add_child(label("%d pilotos avançaram na eliminatória %d.\nTodos os encontros disponíveis na ÁRVORE." % [cup.rounds[round_index].winners.size(), round_index + 1], 15, Color("a6b7bd")))
	else:
		body.add_child(label("1 024 inscritos na chave do Farol.\nO primeiro boletim chega depois da tua primeira vitória.", 17))
	body.add_child(label("AURORA EM CAMPO  •  A competição tem mais de uma história.", 13, GOLD))
func article(story: Dictionary) -> void:
	edition_number = story.jornada
	archive.selected = cup.wins - edition_number
	clear()
	reset_scroll()
	opened_id = story.id
	body.add_child(button("← VOLTAR À EDIÇÃO %02d" % edition_number, front))
	var sheet = paper()
	sheet.add_child(label("AURORA EM CAMPO   /   " + story.etapa.to_upper(), 13, INK))
	photograph(sheet, story)
	sheet.add_child(label(story.titulo, 48, INK))
	sheet.add_child(label(story.corpo, 20, INK))
	if not story.resultado.is_empty(): sheet.add_child(label("RESULTADO   " + story.resultado, 28, INK))
	var names: String = story.personagemPrincipal
	if not story.personagemSecundario.is_empty(): names += "  /  " + story.personagemSecundario
	sheet.add_child(label("EM CENA   " + names, 16, INK))
	sheet.add_child(label("Arquivo da Taça · edição %02d\nRedação Aurora · reportagem da competição." % story.jornada, 13, INK))
	body.add_child(button("VER NA ÁRVORE   ↗", func(): tree_requested.emit(story.personagemPrincipal)))
	body.add_child(button("← REGRESSAR À CAPA", front))
