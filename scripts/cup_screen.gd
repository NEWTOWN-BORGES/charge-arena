extends Control
## A thumb-first tournament desk. No per-frame redraws, blur or live background imports.
signal action(id: String)
const GOLD = Color("e8bd78")
const WHITE = Color("f2eee4")
const MUTED = Color("a6b7bd")
const MINT = Color("81d9c4")
const ArenaView = preload("res://scripts/indie_arena_view.gd")
var cup
var player_skin_provider: Callable
var tab = 0
var page = 0
var tree_round = -1
var tree_view: Control
var tree_focus = ""
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
	var w = minf(size.x - 48, 1040 if wide else 1080)
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
	footer.visible = tab == 0
	footer.position = Vector2(x, size.y - (28 if tab != 0 else 246))
	footer.size = Vector2(w, 204)
	scroll.position = Vector2(x, top + 156)
	scroll.size = Vector2(w, maxf(100, footer.position.y - scroll.position.y - 18))
	if wide and tab == 0 and w >= 900:
		# Keep the protagonist visible beside the actions on a short desktop window.
		footer.position.x = x + w - 400
		footer.size.x = 400
		scroll.size = Vector2(w - 424, size.y - scroll.position.y - 28)
	if is_instance_valid(tree_view):
		tree_view.position = scroll.position
		tree_view.size = scroll.size
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
	if is_instance_valid(tree_view):
		remove_child(tree_view)
		tree_view.queue_free()
		tree_view = null
	scroll.visible = tab != 1
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0
	var next_match: Dictionary = cup.confirmed_match()
	play.disabled = next_match.is_empty()
	subtitle.text = "TAÇA AURORA   /   " + cup.sector_label()
	play.text = "TAÇA CONQUISTADA" if cup.wins >= cup.DEMO_MATCHES else ("AGUARDANDO ADVERSÁRIO" if play.disabled else ("DISPUTAR A FINAL  →" if next_match.is_final else "JOGAR RONDA %02d  →" % next_match.round))
	for i in range(nav.get_child_count()):
		nav.get_child(i).modulate = WHITE if tab == i else MUTED
	if tab == 0:
		journey(next_match)
	elif tab == 1:
		tree_view = preload("res://scripts/cup_tree.gd").new()
		tree_view.cup = cup
		tree_view.player_skin = player_skin_provider.call() if player_skin_provider.is_valid() else 0
		tree_view.entry_person = tree_focus
		tree_focus = ""
		add_child(tree_view)
	else:
		var journal = preload("res://scripts/cup_journal.gd").new()
		journal.cup = cup
		journal.tree_requested.connect(func(who): tree_focus = who; tab = 1; refresh())
		content.add_child(journal)
	arrange()

func journey(next_match: Dictionary) -> void:
	var done: bool = cup.wins >= cup.DEMO_MATCHES
	if not done:
		var reward = "AVANÇAS PARA A PRÓXIMA RONDA"
		var detail = "Mais uma vitória na tua caminhada pela Taça Aurora."
		if cup.local_wins() == 9:
			reward = "CLASSIFICAS-TE PARA A FINAL DO SETOR"
			detail = "O adversário depende do resultado da chave do setor."
		elif cup.local_wins() == 10:
			reward = "CAMPEÃO DO SETOR"
			detail = "Ganhas a skin do adversário e avanças para o próximo setor."
			if cup.wins == cup.FULL_MATCHES - 1:
				reward = "CAMPEÃO DA TAÇA AURORA"
				detail = "Conquistas a Taça e as skins de prémio da final."
		path_node("↑", "SE VENCER", reward, detail, GOLD)
		if next_match.is_empty():
			path_node("?", "PRÓXIMO CONFRONTO", "ADVERSÁRIO A DEFINIR", "Aguardando o resultado oficial da chave.", GOLD)
		else:
			var heading = ("GRANDE FINAL · CONFIRMADA" if next_match.grand_final else "FINAL DO SETOR · CONFIRMADA") if next_match.is_final else "PRÓXIMO CONFRONTO CONFIRMADO"
			path_node("VS", heading, next_match.name.to_upper(), "RONDA %02d · TU vs %s" % [next_match.round, next_match.name], GOLD)
	var current = path_node("★", "TU ESTÁS AQUI", "TAÇA CONQUISTADA" if done else "RONDA %02d" % (cup.wins + 1), "%02d vitórias · O caminho que construíste." % cup.wins, MINT, true)
	var skin = int(player_skin_provider.call()) if player_skin_provider.is_valid() else 0
	portrait(current, {"boss": skin, "hue": "81d9c4"})
	if not result.is_empty():
		path_node("·", "ÚLTIMO COMBATE", result, "O teu progresso está guardado.", MUTED)
	for i in range(cup.history.size() - 1, -1, -1):
		var bout: Dictionary = cup.history[i]
		var caption = "ACABOU DE FICAR PARA TRÁS" if i == cup.history.size() - 1 else "CONFRONTO VENCIDO"
		path_node("✓", "%s · RONDA %02d" % [caption, bout.round], bout.opponent, "Vitória %d–%d" % [bout.score[0], bout.score[1]], MUTED)
	path_node("○", "INÍCIO", "A tua história começa aqui.", "As tuas vitórias vão ficando nesta estrada." if cup.history.is_empty() else "Cada vitória trouxe-te até aqui.", MUTED)

func path_node(marker: String, kicker: String, headline: String, body: String, accent: Color, present: bool = false) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	var rail = VBoxContainer.new()
	rail.custom_minimum_size.x = 36
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rail)
	var dot = text(marker, 19, accent)
	dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rail.add_child(dot)
	var line = ColorRect.new()
	line.color = accent.darkened(0.6)
	line.custom_minimum_size = Vector2(2, 20)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(line)
	var frame = PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", panel_style(Color("203e43") if present else Color("142630"), accent if present else Color("2a414c")))
	row.add_child(frame)
	var inside = HBoxContainer.new()
	frame.add_child(inside)
	var words = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 6)
	inside.add_child(words)
	for entry in [[kicker, 12, accent], [headline, 23 if present else 20, WHITE], [body, 15, MUTED]]:
		var label = text(entry[0], entry[1], entry[2])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(label)
	return inside

func portrait(parent: Control, entry: Dictionary) -> void:
	var render = SubViewport.new()
	render.size = Vector2i(240, 240)
	render.transparent_bg = true
	render.msaa_3d = Viewport.MSAA_2X
	render.own_world_3d = true
	render.render_target_update_mode = SubViewport.UPDATE_ONCE
	var model = ArenaView.new()
	render.add_child(model)
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
	image.custom_minimum_size = Vector2(100, 100)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(image)
	image.add_child(render)
	image.texture = render.get_texture()
