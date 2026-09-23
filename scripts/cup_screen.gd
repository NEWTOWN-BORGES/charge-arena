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
		var route = preload("res://scripts/cup_route.gd").new()
		route.cup = cup
		route.player_skin = player_skin_provider.call() if player_skin_provider.is_valid() else 0
		route.last_result = result
		content.add_child(route)
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

