extends Control
## The Taça Aurora hub: where the run lives between matches. The round being played, the
## ladder of the draw, the next match, Rosa's kiosk with today's paper, and the ways into
## the route, the tree, the hangar and the powers. The versus card before a match and the
## result after it are shown here too, so a match never ends on a generic menu.
signal action(id: String)
const UI = preload("res://scripts/story_ui.gd")
const Press = preload("res://scripts/story_press.gd")
const Taca = preload("res://scripts/tournament.gd")
const Paper = preload("res://scripts/story_paper.gd")
const Route = preload("res://scripts/story_route.gd")
const Bracket = preload("res://scripts/story_bracket.gd")
const Versus = preload("res://scripts/story_versus.gd")
const After = preload("res://scripts/story_after.gd")
const KioskScene = preload("res://scripts/story_kiosk.gd")

var cup
var hud
var player_skin_provider: Callable
var scroll: ScrollContainer
var home: VBoxContainer
var page: Control
var overlay: Control
var clock = 0.0
var ladder: Control
var result = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if get_parent() != null and get_parent().has_method("make_button"):
		hud = get_parent()
	var ground = Backdrop.new()
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	home = VBoxContainer.new()
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.add_theme_constant_override("separation", 16)
	scroll.add_child(home)
	resized.connect(arrange)
	arrange()

func player_skin() -> int:
	return int(player_skin_provider.call()) if player_skin_provider.is_valid() else 0

func arrange() -> void:
	var top = 18.0
	if OS.has_feature("mobile"):
		var safe = DisplayServer.get_display_safe_area()
		var screen = DisplayServer.screen_get_size()
		if screen.y > 0: top += float(safe.position.y) / screen.y * size.y
	var width = minf(size.x - 32, 760)
	scroll.position = Vector2((size.x - width) * 0.5, top)
	scroll.size = Vector2(width, size.y - top)

func _process(dt: float) -> void:
	clock += dt
	if is_instance_valid(ladder) and ladder.is_visible_in_tree():
		ladder.queue_redraw()

func refresh() -> void:
	# The legacy tab field some callers still set; the hub always opens on its home.
	close_page()
	for child in home.get_children():
		home.remove_child(child)
		child.queue_free()
	if cup == null: return
	build_header()
	build_next()
	build_kiosk()
	build_tiles()
	UI.gap(home, 24)
	scroll.scroll_vertical = 0

var tab: int:
	set(value):
		if value == 2 and cup != null: call_deferred("open_paper", Press.editions_available(cup) - 1)

# --- the home page ---------------------------------------------------------------------

func build_header() -> void:
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	home.add_child(bar)
	var back = UI.key(hud, "‹  LOBBY", false, func(): action.emit("menu"), 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size.x = 150
	bar.add_child(back)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var day = UI.label("DIA %d DA TAÇA" % Press.editions_available(cup), 16, UI.MUTED, "display", false)
	day.size_flags_horizontal = Control.SIZE_SHRINK_END
	day.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(day)
	home.add_child(UI.label("TAÇA AURORA", 18, UI.GOLD, "display", false))
	var phase = "CAMPEÃO" if cup.champion() else cup.round_name().to_upper()
	home.add_child(UI.label(phase, 52, UI.WHITE, "display", false))
	var standing = "O último em pé." if cup.champion() else ("A porta da Taça. Vence para entrar na chave de 1.024." if cup.step() == 0 else "%d pilotos em prova. Tu és um deles." % Taca.field_after(cup.wins))
	home.add_child(UI.label(standing, 18, UI.MUTED, "body"))
	ladder = Ladder.new()
	ladder.hub = self
	ladder.custom_minimum_size.y = 86
	home.add_child(ladder)

func build_next() -> void:
	var box = UI.card(home, UI.NAVY, UI.GOLD_DEEP, 20)
	if cup.champion():
		box.add_child(UI.label("CAMPEÃO DA TAÇA AURORA", 30, UI.GOLD, "display", false))
		box.add_child(UI.label("Dez rondas, dez vitórias. A tua Taça está guardada no arquivo, capa a capa.", 18, UI.WHITE, "body"))
		var trophy = Trophy.new()
		trophy.custom_minimum_size.y = 200
		box.add_child(trophy)
		box.add_child(UI.key(hud, "LER A EDIÇÃO HISTÓRICA", true, func(): open_paper(Press.editions_available(cup) - 1), 76))
		return
	var m: Dictionary = cup.confirmed_match()
	var head = HBoxContainer.new()
	box.add_child(head)
	head.add_child(UI.label("PRÓXIMA PARTIDA", 16, UI.GOLD, "display", false))
	var where = UI.label(String(cup.level().name).to_upper(), 16, UI.MUTED, "display", false)
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(where)
	var duel = HBoxContainer.new()
	duel.add_theme_constant_override("separation", 0)
	duel.custom_minimum_size.y = 250
	box.add_child(duel)
	duel.add_child(fighter(Taca.PLAYER, "TU", UI.MINT, -0.35))
	var versus = UI.label("VS", 54, UI.GOLD, "display", false)
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	versus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	versus.custom_minimum_size.x = 70
	duel.add_child(versus)
	var info: Dictionary = Press.CAST.get(String(m.name), {})
	duel.add_child(fighter(String(m.name), String(info.get("epithet", "")), UI.CORAL, 0.35))
	var lost = cup.losses_here()
	if lost > 0:
		box.add_child(UI.label("%d tentativa%s sem vitória nesta ronda. A Taça espera por ti." % [lost, "" if lost == 1 else "s"], 15, UI.CORAL, "italic"))
	box.add_child(UI.key(hud, "JOGAR PRÓXIMA PARTIDA", true, open_versus, 84))

func fighter(who: String, caption: String, tint: Color, turn: float) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	var art = UI.pilot_render(cup, who, player_skin(), turn)
	art.custom_minimum_size.y = 180
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(art)
	var name_label = UI.label(who.to_upper(), 26, UI.WHITE, "display", false)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var tag = UI.label(caption, 13, tint, "display", false)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tag)
	return column

func build_kiosk() -> void:
	var stall = Button.new()
	stall.focus_mode = Control.FOCUS_NONE
	stall.custom_minimum_size.y = 196
	stall.add_theme_stylebox_override("normal", UI.panel_style(Color("1a1712"), UI.GOLD_DEEP, 14, 0))
	stall.add_theme_stylebox_override("hover", UI.panel_style(Color("221d15"), UI.GOLD, 14, 0))
	stall.add_theme_stylebox_override("pressed", UI.panel_style(Color("2a2318"), UI.GOLD, 14, 0))
	stall.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	stall.pressed.connect(open_kiosk)
	home.add_child(stall)
	var face = Kiosk.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.line = Press.kiosk_line(cup)
	face.fresh = Press.has_new_edition(cup)
	face.edition = Press.edition(cup, Press.editions_available(cup) - 1)
	stall.add_child(face)

func build_tiles() -> void:
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	home.add_child(grid)
	var route_sub = "Ainda por começar" if not cup.entrance_passed else "%d vitória%s na Taça" % [cup.wins + 1, "" if cup.wins == 0 else "s"]
	var tree_sub = "1.024 inscritos" if cup.wins == 0 else "%d em prova" % Taca.field_after(cup.wins)
	for entry in [["MEU PERCURSO", route_sub, "route", func(): open_route()], ["ÁRVORE DA ARENA", tree_sub, "tree", func(): open_bracket()],
			["PILOTO", "Hangar e skins", "pilot", func(): action.emit("skins")], ["PODERES", "O teu kit", "powers", func(): action.emit("powers")],
			["ARENAS", "Rejoga as que venceste", "arenas", func(): action.emit("arenas")], ["OPÇÕES", "Imagem, som e controlos", "settings", func(): action.emit("settings")]]:
		var tile = Button.new()
		tile.focus_mode = Control.FOCUS_NONE
		tile.custom_minimum_size = Vector2(0, 104)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("normal", UI.panel_style(UI.NAVY, UI.LINE, 14, 0))
		tile.add_theme_stylebox_override("hover", UI.panel_style(UI.NAVY_LIGHT, UI.GOLD_DEEP, 14, 0))
		tile.add_theme_stylebox_override("pressed", UI.panel_style(UI.NAVY_LIGHT, UI.GOLD, 14, 0))
		tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tile.pressed.connect(entry[3])
		grid.add_child(tile)
		var face = Tile.new()
		face.title = entry[0]
		face.sub = entry[1]
		face.icon = entry[2]
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(face)

# --- pages and overlays ----------------------------------------------------------------

func open_page(node: Control) -> void:
	close_page()
	page = node
	add_child(page)

func close_page() -> void:
	if is_instance_valid(page):
		page.queue_free()
	page = null

func open_paper(number: int) -> void:
	var paper = Paper.new()
	paper.cup = cup
	paper.hud = hud
	paper.player_skin = player_skin()
	paper.closed.connect(func(): close_page(); refresh())
	open_page(paper)
	paper.open(number)

func open_kiosk() -> void:
	# The kiosk is a place: Rosa behind her counter, the day's paper one key away.
	var stand = KioskScene.new()
	stand.cup = cup
	stand.hud = hud
	stand.closed.connect(func(): close_page(); refresh())
	stand.read.connect(func(number): open_paper(number))
	stand.archive.connect(func():
		open_paper(Press.editions_available(cup) - 1)
		if is_instance_valid(page): page.toggle_archive())
	open_page(stand)

func open_route() -> void:
	var route = Route.new()
	route.cup = cup
	route.hud = hud
	route.player_skin = player_skin()
	route.closed.connect(close_page)
	route.play_requested.connect(open_versus)
	open_page(route)

func open_bracket() -> void:
	var tree = Bracket.new()
	tree.cup = cup
	tree.hud = hud
	tree.closed.connect(close_page)
	open_page(tree)

func open_versus() -> void:
	if cup.confirmed_match().is_empty(): return
	close_overlay()
	var card = Versus.new()
	card.cup = cup
	card.hud = hud
	card.player_skin = player_skin()
	card.enter.connect(func(): close_overlay(); action.emit("play"))
	card.cancelled.connect(close_overlay)
	overlay = card
	add_child(card)

func show_after(outcome: Dictionary) -> void:
	close_page()
	close_overlay()
	var card = After.new()
	card.cup = cup
	card.hud = hud
	card.outcome = outcome
	card.player_skin = player_skin()
	card.read_paper.connect(func(): close_overlay(); open_paper(Press.editions_available(cup) - 1))
	card.retry.connect(func(): close_overlay(); open_versus())
	card.done.connect(func(): close_overlay(); refresh())
	overlay = card
	add_child(card)

func close_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null

# --- drawn pieces ----------------------------------------------------------------------

class Backdrop extends Control:
	## The stadium at night behind the hub: a deep gradient and two long gold light bars.
	func _draw() -> void:
		var top = Color("0b1c26")
		var bottom = Color("050d12")
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([top, top, bottom, bottom]))
		for i in range(2):
			var y = size.y * (0.18 + i * 0.5)
			draw_line(Vector2(0, y), Vector2(size.x, y - 120), Color(0.91, 0.74, 0.47, 0.035), 60.0)

class Ladder extends Control:
	## The draw as a ladder: the admission, then 1 024 down to 2, then the cup. Done in
	## gold, the current round pulsing in mint, the rest still to come.
	const UI = preload("res://scripts/story_ui.gd")
	var hub
	func _draw() -> void:
		var cup = hub.cup
		var labels = ["ADM", "1024", "512", "256", "128", "64", "32", "16", "8", "4", "2", "★"]
		var current: int = 11 if cup.champion() else cup.step()
		var n = labels.size()
		var x0 = 16.0
		var x1 = size.x - 16.0
		var y = 30.0
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(1, 1, 1, 0.12), 3.0)
		var done_x = lerpf(x0, x1, float(current) / (n - 1))
		draw_line(Vector2(x0, y), Vector2(done_x, y), Color("e8bd78"), 3.0)
		var font = UI.font("display")
		for i in range(n):
			var x = lerpf(x0, x1, float(i) / (n - 1))
			var done = i < current
			var here = i == current
			if here:
				var pulse = 0.5 + 0.5 * sin(hub.clock * 3.0)
				draw_circle(Vector2(x, y), 13 + pulse * 3, Color(0.51, 0.85, 0.77, 0.25), true, -1, true)
				draw_circle(Vector2(x, y), 9, Color("81d9c4"), true, -1, true)
			else:
				draw_circle(Vector2(x, y), 7, Color("e8bd78") if done else Color("24404d"), true, -1, true)
			var text: String = labels[i]
			var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(x - w * 0.5, y + 34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("81d9c4") if here else (Color("e8bd78") if done else Color("5d7884")))

class Kiosk extends Control:
	## Rosa's kiosk: a striped awning, the day's papers pegged up, Rosa behind the counter,
	## and what she has to say today. A red stamp when there is an edition not yet read.
	const UI = preload("res://scripts/story_ui.gd")
	var line = ""
	var fresh = false
	var edition: Dictionary = {}
	func _draw() -> void:
		var art = Rect2(14, 14, 190, size.y - 28)
		# Awning.
		for i in range(7):
			var stripe = Rect2(art.position.x + i * art.size.x / 7.0, art.position.y, art.size.x / 7.0, 34)
			draw_rect(stripe, Color("e8bd78") if i % 2 == 0 else Color("f3eee1"))
		draw_rect(Rect2(art.position.x, art.position.y + 34, art.size.x, 5), Color("b88a3e"))
		# Stall.
		var stall = Rect2(art.position.x + 6, art.position.y + 39, art.size.x - 12, art.size.y - 39)
		draw_rect(stall, Color("22404a"))
		# Papers pegged up.
		for i in range(3):
			var sheet = Rect2(stall.position.x + 10 + i * 58, stall.position.y + 10, 48, 62)
			draw_rect(sheet, Color("f3eee1"))
			draw_rect(Rect2(sheet.position + Vector2(5, 6), Vector2(38, 6)), Color("16191c"))
			draw_rect(Rect2(sheet.position + Vector2(5, 16), Vector2(38, 18)), Color("8a8f92"))
			for k in range(3):
				draw_rect(Rect2(sheet.position + Vector2(5, 40 + k * 6), Vector2(38, 2)), Color("8a8f92"))
		# Rosa, the robot dog, in her newsboy cap and red scarf.
		var head = Vector2(stall.position.x + stall.size.x * 0.5, stall.end.y - 44)
		var shell = Color("e9e3d4")
		draw_circle(head + Vector2(0, 42), 34, shell, true, -1, true)
		draw_rect(Rect2(head + Vector2(-30, 16), Vector2(60, 12)), Color("b83a2b"))
		for side in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([head + Vector2(side * 12, -14), head + Vector2(side * 26, -40), head + Vector2(side * 28, -8)]), shell)
		draw_circle(head, 24, shell, true, -1, true)
		draw_rect(Rect2(head + Vector2(-16, -4), Vector2(32, 9)), Color("24323a"))
		draw_rect(Rect2(head + Vector2(-11, -2), Vector2(6, 4)), Color("81d9c4"))
		draw_rect(Rect2(head + Vector2(5, -2), Vector2(6, 4)), Color("81d9c4"))
		draw_circle(head + Vector2(0, 12), 5, Color("24323a"), true, -1, true)
		draw_rect(Rect2(head + Vector2(-22, -26), Vector2(44, 10)), Color("39505a"))
		draw_rect(Rect2(head + Vector2(-26, -18), Vector2(30, 4)), Color("2a3c44"))
		draw_rect(Rect2(stall.position.x, stall.end.y - 14, stall.size.x, 14), Color("16303a"))
		# What she says.
		var text_x = art.end.x + 18
		var width = size.x - text_x - 16
		draw_string(UI.font("display"), Vector2(text_x, 34), "BANCA DA ROSA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e8bd78"))
		var f = UI.font("italic")
		var words = ("«" + line + "»").split(" ")
		var row = ""
		var y = 64.0
		for w in words:
			var attempt = (row + " " + w).strip_edges()
			if f.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x > width and row != "":
				draw_string(f, Vector2(text_x, y), row, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f2eee4"))
				y += 24
				row = w
			else:
				row = attempt
		draw_string(f, Vector2(text_x, y), row, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f2eee4"))
		if not edition.is_empty():
			draw_string(UI.font("headline"), Vector2(text_x, size.y - 30), String(edition.headline), HORIZONTAL_ALIGNMENT_LEFT, width, 17, Color("e8bd78"))
		if fresh:
			var tag = "NOVA EDIÇÃO  N.º %03d" % int(edition.get("number", 1))
			var tw = UI.font("display").get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var at = Vector2(size.x - tw - 30, size.y - 74)
			draw_rect(Rect2(at, Vector2(tw + 18, 26)), Color("b83a2b"))
			draw_string(UI.font("display"), at + Vector2(9, 19), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f3eee1"))
		else:
			draw_string(UI.font("display"), Vector2(size.x - 150, size.y - 56), "LER O JORNAL  ›", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9fb3ba"))

class Tile extends Control:
	const UI = preload("res://scripts/story_ui.gd")
	var title = ""
	var sub = ""
	var icon = ""
	func _draw() -> void:
		var at = Vector2(40, size.y * 0.5)
		draw_circle(at, 24, Color(0.91, 0.74, 0.47, 0.12), true, -1, true)
		var gold = Color("e8bd78")
		match icon:
			"route":
				for i in range(3):
					draw_circle(at + Vector2(-10 + i * 10, 8 - i * 8), 3.5, gold, true, -1, true)
				draw_polyline(PackedVector2Array([at + Vector2(-10, 8), at + Vector2(0, 0), at + Vector2(10, -8)]), gold, 2.0, true)
			"tree":
				for y in [-10, -3, 4, 11]:
					draw_line(at + Vector2(-12, y), at + Vector2(-4, y), gold, 2.0, true)
				draw_line(at + Vector2(-4, -10), at + Vector2(-4, -3), gold, 2.0, true)
				draw_line(at + Vector2(-4, 4), at + Vector2(-4, 11), gold, 2.0, true)
				draw_line(at + Vector2(-4, -6), at + Vector2(4, -6), gold, 2.0, true)
				draw_line(at + Vector2(-4, 7), at + Vector2(4, 7), gold, 2.0, true)
				draw_line(at + Vector2(4, -6), at + Vector2(4, 7), gold, 2.0, true)
				draw_line(at + Vector2(4, 0), at + Vector2(12, 0), gold, 2.0, true)
			"pilot":
				draw_circle(at + Vector2(0, -3), 11, gold, false, 2.2, true)
				draw_rect(Rect2(at + Vector2(-7, -6), Vector2(14, 5)), gold)
				draw_line(at + Vector2(-9, 12), at + Vector2(9, 12), gold, 2.2, true)
			"powers":
				draw_colored_polygon(PackedVector2Array([at + Vector2(3, -13), at + Vector2(-7, 2), at + Vector2(0, 2), at + Vector2(-3, 13), at + Vector2(7, -3), at + Vector2(0, -3)]), gold)
			"arenas":
				draw_arc(at, 12, 0, TAU, 24, gold, 2.2, true)
				draw_line(at + Vector2(-12, 0), at + Vector2(12, 0), gold, 1.5, true)
				draw_arc(at, 5, 0, TAU, 16, gold, 1.5, true)
			_:
				for tooth in range(8):
					var angle = tooth * TAU / 8.0
					draw_line(at + Vector2.from_angle(angle) * 7, at + Vector2.from_angle(angle) * 12, gold, 3.0, true)
				draw_circle(at, 7, gold, false, 2.0, true)
		draw_string(UI.font("display"), Vector2(78, size.y * 0.5 - 4), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 86, 21, Color("f2eee4"))
		draw_string(UI.font("body"), Vector2(78, size.y * 0.5 + 20), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - 86, 14, Color("9fb3ba"))

class Trophy extends Control:
	func _draw() -> void:
		var c = Vector2(size.x * 0.5, size.y * 0.5)
		var gold = Color("e8bd78")
		draw_circle(c, 90, Color(0.91, 0.74, 0.47, 0.08), true, -1, true)
		draw_arc(c + Vector2(0, -20), 46, 0, PI, 32, gold, 10, true)
		draw_line(c + Vector2(-46, -20), c + Vector2(46, -20), gold, 10, true)
		draw_rect(Rect2(c + Vector2(-7, 26), Vector2(14, 34)), gold)
		draw_rect(Rect2(c + Vector2(-34, 58), Vector2(68, 14)), gold)
		for s in [-1, 1]:
			draw_arc(c + Vector2(s * 52, -4), 16, -PI * 0.5 if s > 0 else PI * 0.5, PI * 0.5 if s > 0 else PI * 1.5, 16, gold, 6, true)
