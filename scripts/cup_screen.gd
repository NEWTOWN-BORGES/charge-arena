extends Control
## A thumb-first tournament desk. No per-frame redraws, blur or live background imports.
signal action(id: String)
const GOLD = Color("e8bd78")
const WHITE = Color("f2eee4")
const MUTED = Color("a6b7bd")
const MINT = Color("81d9c4")
const ArenaView = preload("res://scripts/indie_arena_view.gd")
var cup
var tab = 0
var page = 0
var tree_round = -1
var content: VBoxContainer
var scroll: ScrollContainer
var title: Label
var subtitle: Label
var play: Button
var nav: HBoxContainer
var footer: VBoxContainer
var result = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg = ColorRect.new()
	bg.color = Color("0b171f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	title = text("CHARGE / ARENA", 30, WHITE)
	add_child(title)
	subtitle = text("TAÇA AURORA   /   PRIMEIRO SETOR", 14, GOLD)
	add_child(subtitle)
	nav = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	add_child(nav)
	for i in range(3):
		var b = button(["PERCURSO", "ÁRVORE", "JORNAL"][i], false)
		b.pressed.connect(func(): tab = i; page = 0; refresh())
		nav.add_child(b)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	footer = VBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	add_child(footer)
	var tools = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	footer.add_child(tools)
	for entry in [["PILOTO", "skins"], ["KIT", "powers"], ["OPÇÕES", "settings"]]:
		var b = button(entry[0], false)
		b.pressed.connect(func(): action.emit(entry[1]))
		tools.add_child(b)
	var modes = HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	footer.add_child(modes)
	for entry in [["MENU 3D", "menu"], ["ARENAS", "arenas"], ["PvP LOCAL", "pvp"]]:
		var b = button(entry[0], false)
		b.pressed.connect(func(): action.emit(entry[1]))
		modes.add_child(b)
	play = button("ENTRAR NA TAÇA", true)
	play.custom_minimum_size.y = 72
	play.pressed.connect(func(): action.emit("play"))
	footer.add_child(play)
	resized.connect(arrange)
	arrange()

func panel_style(color: Color, edge: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(16)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s

func text(value: String, font_size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func button(value: String, primary: bool) -> Button:
	var b = Button.new()
	b.text = value
	b.custom_minimum_size.y = 56
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color("102029") if primary else WHITE)
	b.add_theme_color_override("font_hover_color", Color("102029") if primary else WHITE)
	b.add_theme_stylebox_override("normal", panel_style(GOLD if primary else Color("172a35"), GOLD if primary else Color("304652")))
	b.add_theme_stylebox_override("hover", panel_style(GOLD.lightened(0.12) if primary else Color("223e49"), MINT))
	b.add_theme_stylebox_override("pressed", panel_style(MINT if primary else Color("284b55"), MINT))
	b.add_theme_stylebox_override("focus", panel_style(Color(0, 0, 0, 0), MINT))
	return b

func arrange() -> void:
	var wide = size.x > size.y
	var w = minf(size.x - 48, 880 if wide else 640)
	var x = (size.x - w) * 0.5
	var top = 28.0
	if OS.has_feature("mobile"):
		var safe = DisplayServer.get_display_safe_area()
		var screen = DisplayServer.screen_get_size()
		if screen.y > 0:
			top += float(safe.position.y) / screen.y * size.y
	title.position = Vector2(x, top)
	subtitle.position = Vector2(x, top + 43)
	nav.position = Vector2(x, top + 80)
	nav.size = Vector2(w, 56)
	footer.position = Vector2(x, size.y - 246)
	footer.size = Vector2(w, 204)
	scroll.position = Vector2(x, top + 156)
	scroll.size = Vector2(w, maxf(100, footer.position.y - scroll.position.y - 18))
	if wide:
		# Desktop keeps the same reading order, with less vertical chrome.
		title.add_theme_font_size_override("font_size", 26)
	queue_redraw()

func card(kicker: String, headline: String, body: String, accent: Color = MINT) -> void:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(Color("142630"), Color("2a414c")))
	content.add_child(p)
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	p.add_child(stack)
	for data in [[kicker, 13, accent], [headline, 25, WHITE], [body, 17, MUTED]]:
		if str(data[0]).is_empty():
			continue
		var l = text(data[0], data[1], data[2])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(l)

func refresh() -> void:
	if not is_instance_valid(content) or cup == null:
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0
	play.disabled = cup.wins >= cup.DEMO_MATCHES
	play.text = "DEMO CONCLUÍDA" if play.disabled else ("DISPUTAR A FINAL  →" if cup.wins == 10 else "JOGAR QUALIFICATÓRIA %02d  →" % (cup.wins + 1))
	for i in range(nav.get_child_count()):
		nav.get_child(i).modulate = WHITE if tab == i else MUTED
	if tab == 0:
		if not result.is_empty():
			card("ÚLTIMO COMBATE", result, "O teu progresso está guardado. Consulta o Jornal para acompanhar o outro lado da Taça.", GOLD)
		hero()
		card("%02d / 11 VITÓRIAS   ·   SETOR DO FAROL" % cup.wins, "A tua história começa aqui." if cup.wins == 0 else ("Setor conquistado." if cup.wins >= 11 else "O próximo passo é teu."), "Dez qualificatórias. Uma final de setor. Enquanto jogas, 1 024 pilotos disputam a chave que vai entregar o teu primeiro boss.")
		var path_text = ""
		for i in range(11):
			var name_value = cup.NAMES[i] if i < 10 else "FAROLEIRO · FINAL"
			path_text += "%s  %02d   %s\n" % ["✓" if i < cup.wins else ("›" if i == cup.wins else "·"), i + 1, name_value]
		card("O TEU PERCURSO", "Cada vitória abre a seguinte", path_text.strip_edges())
		var story: Dictionary = cup.headlines.back()
		card("ÚLTIMA HORA", story.title, story.body, GOLD)
	elif tab == 1:
		card("CHAVE PARALELA · FAROL", "1 024 → 1", "Tu disputas as qualificatórias. Aqui, os rivais eliminam-se a cada vitória tua. O vencedor encontra-te na final do setor.")
		var overview = Control.new()
		overview.custom_minimum_size.y = 170
		overview.draw.connect(func(): draw_tree(overview))
		content.add_child(overview)
		var pick = OptionButton.new()
		pick.custom_minimum_size.y = 56
		pick.add_item("Participantes · lista completa")
		for i in range(cup.rounds.size()):
			pick.add_item("Eliminatória %d · %d jogos" % [i + 1, cup.rounds[i].fixtures.size()])
		pick.selected = clampi(tree_round + 1, 0, pick.item_count - 1)
		pick.item_selected.connect(func(i): tree_round = i - 1; page = 0; refresh())
		content.add_child(pick)
		var rows: Array = cup.entrants if tree_round < 0 or tree_round >= cup.rounds.size() else cup.rounds[tree_round].fixtures
		page = clampi(page, 0, maxi(0, (rows.size() - 1) / 16))
		var listing = ""
		for i in range(page * 16, mini(rows.size(), page * 16 + 16)):
			var row: Dictionary = rows[i]
			listing += ("%04d   %s" % [i + 1, row.name] if row.has("name") else "%s  %s  %s" % [row.winner, row.score, row.loser]) + "\n"
		card("PÁGINA %d / %d" % [page + 1, ceili(rows.size() / 16.0)], "Inscritos" if tree_round < 0 else "Resultados oficiais", listing.strip_edges())
		var pages = HBoxContainer.new()
		for step in [-1, 1]:
			var b = button("ANTERIOR" if step < 0 else "SEGUINTE", false)
			b.disabled = page <= 0 if step < 0 else (page + 1) * 16 >= rows.size()
			b.pressed.connect(func(): page += step; refresh())
			pages.add_child(b)
		content.add_child(pages)
	else:
		card("RÁDIO AURORA", "A Taça não espera por ti.", "Resultados do Farol e notícias dos outros setores. As manchetes ficam guardadas; repetir uma derrota não muda os resultados.", GOLD)
		for i in range(cup.headlines.size() - 1, -1, -1):
			var story: Dictionary = cup.headlines[i]
			card("ABERTURA" if story.round == 0 else "JORNADA %02d" % story.round, story.title, story.body, GOLD)
	arrange()

func hero() -> void:
	var frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", panel_style(Color("20343e"), Color("71634c")))
	content.add_child(frame)
	var row = HBoxContainer.new()
	frame.add_child(row)
	var words = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	words.add_child(text("O TEU PRÓXIMO RIVAL" if cup.wins < 11 else "SETOR CONQUISTADO", 12, GOLD))
	words.add_child(text(cup.opponent().to_upper() if cup.wins < 11 else "FAROLEIRO", 31, WHITE))
	words.add_child(text("FINAL DO FAROL" if cup.wins >= 10 else "QUALIFICATÓRIA %02d" % (cup.wins + 1), 14, MINT))
	var render = SubViewport.new()
	render.size = Vector2i(240, 240)
	render.transparent_bg = true
	render.msaa_3d = Viewport.MSAA_2X
	render.own_world_3d = true
	render.render_target_update_mode = SubViewport.UPDATE_ONCE
	var model = ArenaView.new()
	render.add_child(model)
	var entry: Dictionary = cup.level()
	var pilot = model.build_player(Color(entry.hue) if entry.hue != "" else Color("81d9c4"), 1, entry.boss)
	pilot.position = Vector3.ZERO
	pilot.rotation.y = 0.28
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_color = Color("ffead0")
	light.light_energy = 1.3
	render.add_child(light)
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b4dce3")
	world.environment.ambient_light_energy = 0.6
	render.add_child(world)
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.6
	cam.position = Vector3(2.4, 1.8, -4)
	render.add_child(cam)
	cam.transform = cam.transform.looking_at(Vector3(0, 0.95, 0))
	var image = TextureRect.new()
	image.custom_minimum_size = Vector2(164, 164)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(image)
	image.add_child(render)
	image.texture = render.get_texture()

func draw_tree(canvas: Control) -> void:
	var w = canvas.size.x - 20
	for col in range(11):
		var count = mini(32, 1024 >> col)
		var x = 10 + col * w / 10.0
		var active = col <= cup.rounds.size()
		for row in range(count):
			var y = 12 + (row + 0.5) * 136.0 / count
			canvas.draw_circle(Vector2(x, y), 2.5, MINT if active else Color("38515e"))
			if col < 10:
				var next_count = mini(32, 1024 >> (col + 1))
				var target = mini(next_count - 1, floori(float(row) * next_count / count))
				canvas.draw_line(Vector2(x + 3, y), Vector2(x + w / 10 - 3, 12 + (target + 0.5) * 136.0 / next_count), Color("38515e"), 1.0)
		canvas.draw_string(ThemeDB.fallback_font, Vector2(x - 10, 168), str(1024 >> col), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
