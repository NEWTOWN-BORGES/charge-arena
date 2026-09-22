extends Control
signal back_to_journal
const Data = preload("res://scripts/cup_tree_data.gd")
const Canvas = preload("res://scripts/cup_tree_canvas.gd")
const Models = preload("res://scripts/indie_arena_view.gd")
const MINT = Color("81d9c4")
const GOLD = Color("e8bd78")
var cup
var player_skin = 0
var map
var toolbar: HBoxContainer
var controls: HBoxContainer
var caption: Label
var detail: PanelContainer
var level = 0
var following = ""
var round_index = 0
var page = 0
var portrait_queue: Array = []
var loading_portrait = false
var entry_person = ""
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	map = Canvas.new()
	add_child(map)
	map.picked.connect(select_node)
	toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)
	for item in [["TAÇA", 0], ["SETOR", 1], ["CONFRONTOS", 2]]:
		toolbar.add_child(button(item[0], func(): show_level(item[1])))
	caption = label("", 21)
	add_child(caption)
	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	add_child(controls)
	controls.add_child(button("LOCALIZAR-ME", locate_player))
	controls.add_child(button("VISÃO GERAL", func(): show_level(0)))
	controls.add_child(button("−", func(): map.scale_at(1 / 1.2, map.size * 0.5)))
	controls.add_child(button("+", func(): map.scale_at(1.2, map.size * 0.5)))
	resized.connect(arrange)
	arrange()
	show_level(0)
	if not entry_person.is_empty(): call_deferred("open_person", entry_person)
func label(value: String, points: int = 24) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", points)
	l.add_theme_color_override("font_color", Color("d6e5df"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
func button(value: String, callback: Callable) -> Button:
	var b = Button.new()
	b.text = value
	b.custom_minimum_size.y = 96
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 23)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("18343e")
	style.border_color = Color("42636b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	b.add_theme_stylebox_override("normal", style)
	b.pressed.connect(callback)
	return b
func arrange() -> void:
	if map == null: return
	toolbar.position = Vector2.ZERO
	toolbar.size = Vector2(size.x, 96)
	caption.position = Vector2(8, 108)
	caption.size = Vector2(size.x - 16, 52)
	map.position = Vector2(0, 174)
	var previous_size: Vector2 = map.size
	map.size = Vector2(size.x, maxf(130, size.y - 290))
	if map.size != previous_size: map.fit()
	controls.position = Vector2(0, size.y - 108)
	controls.size = Vector2(size.x, 96)
	if is_instance_valid(detail):
		detail.position = Vector2(12, 108)
		detail.size = Vector2(size.x - 24, maxf(160, size.y - 224))
func clear_detail() -> void:
	if is_instance_valid(detail):
		remove_child(detail)
		detail.queue_free()
		detail = null
func add_node(key: String, title: String, pos: Vector2, sub: String = "", status: String = "", accent: Color = Color("45626d"), dimensions: Vector2 = Vector2(300, 158)) -> void:
	map.nodes.append({"key": key, "title": title, "sub": sub, "status": status, "rect": Rect2(pos, dimensions), "accent": accent, "tag": ""})
func person(who: String, pos: Vector2) -> void:
	var p = Data.profile(cup, who)
	var status: String = "EM PROVA" if p.state != "ELIMINATED" else "ELIMINADO POR " + p.eliminated_by.to_upper()
	if who == "Tu": status = p.meeting.to_upper()
	add_node(who, who.to_upper(), pos, "%d vitórias%s" % [p.wins, " publicadas" if p.confirmed_only else ""], status, MINT if who == "Tu" else (GOLD if who == "Aurel" else Color("547986")), Vector2(420, 210) if who == "Tu" else Vector2(380, 184))
	map.nodes.back().person = who
	map.nodes.back().tag = p.tag
	map.nodes.back().out = p.state == "ELIMINATED"
	if not map.portraits.has(who) and not portrait_queue.has(who): portrait_queue.append(who)
func edge(a: String, b: String, highlight: bool = false) -> void:
	var first: Rect2
	var last: Rect2
	var found = 0
	for node in map.nodes:
		if node.key == a: first = node.rect; found += 1
		if node.key == b: last = node.rect; found += 1
	if found == 2:
		var color = MINT if highlight else Color("466773")
		var a_pos = Vector2(first.get_center().x, first.end.y)
		var b_pos = Vector2(last.get_center().x, last.position.y)
		if a in ["sector", "distant"] and Data.CAST.has(b):
			a_pos = Vector2(first.position.x + 16, first.end.y)
			b_pos = Vector2(last.position.x, last.get_center().y)
			var bus_x = last.position.x - 22
			map.edges.append([a_pos, b_pos, color, PackedVector2Array([a_pos, Vector2(bus_x, a_pos.y + 24), Vector2(bus_x, b_pos.y), b_pos])])
		elif first.position.y == last.position.y:
			map.edges.append([Vector2(first.end.x, first.get_center().y), Vector2(last.position.x, last.get_center().y), color])
		else: map.edges.append([a_pos, b_pos, color])
func show_level(value: int) -> void:
	clear_detail()
	level = value
	following = ""
	map.nodes.clear()
	map.edges.clear()
	if level == 0: overview()
	elif level == 1: sector()
	else: confrontations()
	for i in range(3): toolbar.get_child(i).modulate = Color.WHITE if i == level else Color("78939b")
	map.fit()
	map.queue_redraw()
func overview() -> void:
	caption.text = "1 024 NO FAROL · arrasta, amplia e toca nos pilotos"
	add_node("future", "TAÇA AURORA", Vector2(340, 0), "Grande final · por decidir", "OS DOIS PERCURSOS AINDA ESTÃO ABERTOS", GOLD, Vector2(380, 150))
	add_node("sector", "O TEU LADO", Vector2(20, 220), "Farol · primeiro setor", "TOCAR PARA EXPLORAR", MINT, Vector2(380, 150))
	add_node("distant", "OUTRO LADO", Vector2(600, 220), "Setores distantes", "ENCONTROS FUTUROS NÃO CONFIRMADOS", GOLD, Vector2(380, 150))
	edge("future", "sector", true); edge("future", "distant")
	person("Tu", Vector2(20, 450)); person("Aurel", Vector2(600, 450))
	edge("sector", "Tu", true); edge("distant", "Aurel")
	person("Faroleiro", Vector2(20, 720)); person("Nadir", Vector2(600, 720))
	edge("sector", "Faroleiro"); edge("distant", "Nadir")
	person("Lira", Vector2(20, 990)); person("Vértice", Vector2(20, 1240))
	edge("sector", "Lira"); edge("Lira", "Vértice", true) if cup.wins >= 7 else edge("sector", "Vértice")
	for i in range(5):
		var who: String = ["Mineiro", "Astrónomo", "Sentinela", "Jardineiro", "Relojoeiro"][i]
		person(who, Vector2(600, 990 + i * 250))
		edge("distant", who)
	add_node("entrants", "1 024 INSCRITOS", Vector2(20, 1500), "%d ainda na chave" % (1024 >> mini(cup.wins, 10)), "FIGURANTES AGRUPADOS · ABRIR SETOR", MINT, Vector2(380, 150))
func sector() -> void:
	caption.text = "FAROL · verde: percurso vencido · ramos próximos: final possível"
	var y = 0.0
	for i in range(cup.history.size()):
		var record: Dictionary = cup.history[i]
		add_node("past:%d" % i, "✓ " + record.opponent, Vector2(20, y), "%s–%s · vitória tua" % record.score, "QUALIFICATÓRIA %02d" % (i + 1) if i < 10 else "FINAL DO SETOR", MINT, Vector2(380, 132))
		if i > 0: edge("past:%d" % (i - 1), "past:%d" % i, true)
		y += 186
	person("Tu", Vector2(20, y))
	if not cup.history.is_empty(): edge("past:%d" % (cup.history.size() - 1), "Tu", true)
	if cup.wins < 10:
		add_node("next", cup.opponent().to_upper(), Vector2(20, y + 250), "Proxima qualificatória", "ENCONTRO CONFIRMADO", MINT, Vector2(380, 154))
		edge("Tu", "next", true)
	add_node("future", "FINAL DO SETOR" if cup.wins < 11 else "SETOR CONQUISTADO", Vector2(310, y + 530), "Rival ainda por decidir" if cup.wins < 10 else ("TU × FAROLEIRO" if cup.wins == 10 else "TU · vencedor"), "SÓ QUEM SOBREVIVER CHEGA ATÉ AQUI", GOLD, Vector2(390, 154))
	edge("next" if cup.wins < 10 else "Tu", "future", cup.wins >= 10)
	person("Faroleiro", Vector2(600, y))
	person("Lira", Vector2(600, y + 250))
	person("Vértice", Vector2(600, y + 780))
	add_node("matches", "CHAVE PARALELA", Vector2(600, maxf(0, y - 210)), "%d de 1 024 em prova" % (1024 >> mini(cup.wins, 10)), "ABRIR CONFRONTOS", GOLD, Vector2(380, 150))
	edge("matches", "Faroleiro")
	if cup.wins < 7:
		edge("Lira", "future"); edge("Vértice", "future")
	else:
		add_node("upset", "VÉRTICE → AVANÇOU", Vector2(600, y + 530), str(Data.profile(cup, "Lira").history.back().score) + " contra Lira · ronda 7", "TOCAR PARA VER A ELIMINAÇÃO", Color("e19a83"), Vector2(380, 154))
		edge("Lira", "upset"); edge("upset", "Vértice", true)
		edge("Vértice", "future", cup.wins < 10)
	edge("Faroleiro", "future", cup.wins >= 10)
func confrontations() -> void:
	caption.text = "CONFRONTOS · resultados oficiais · oito encontros por página"
	if cup.rounds.is_empty():
		add_node("sector", "AGUARDA O APITO", Vector2(300, 80), "1 024 pilotos inscritos", "OS RESULTADOS CHEGAM COM A PRIMEIRA VITÓRIA", GOLD, Vector2(420, 180))
		return
	round_index = clampi(round_index, 0, cup.rounds.size() - 1)
	var matches: Array = cup.rounds[round_index].fixtures
	page = clampi(page, 0, maxi(0, (matches.size() - 1) / 8))
	add_node("round_prev", "← RONDA", Vector2(10, 0), "%d / %d" % [round_index + 1, cup.rounds.size()], "ANTERIOR", GOLD)
	add_node("round_next", "RONDA →", Vector2(690, 0), "%d jogos" % matches.size(), "SEGUINTE", GOLD)
	var rows = Data.fixtures(cup, round_index, page)
	for i in range(rows.size()):
		var fixture: Dictionary = rows[i]
		var base = Vector2(40, 220 + i * 240)
		var key = "match:%d" % (page * 8 + i)
		add_node(key, Data.public_name(fixture.loser), base, "ELIMINADO", "RONDA %d" % (round_index + 1), Color("986f66"), Vector2(360, 156))
		add_node(key + ":winner", Data.public_name(fixture.winner), base + Vector2(520, 0), fixture.score + " · AVANÇOU", "TOCAR PARA VER O PERCURSO", MINT, Vector2(360, 156))
		edge(key, key + ":winner", true)
	add_node("page_prev", "← ANTERIORES", Vector2(20, 230 + rows.size() * 240), "Página %d" % (page + 1), "RESULTADOS", GOLD)
	add_node("page_next", "SEGUINTES →", Vector2(680, 230 + rows.size() * 240), "de %d páginas" % ceili(matches.size() / 8.0), "RESULTADOS", GOLD)
func locate_player() -> void:
	show_level(1)
	map.locate("Tu")
func select_node(key: String) -> void:
	if Data.CAST.has(key): open_person(key)
	elif key in ["sector", "entrants"]: show_level(1)
	elif key == "distant": map.locate("Aurel")
	elif key == "matches": round_index = maxi(0, cup.rounds.size() - 1); page = 0; show_level(2)
	elif key == "upset": open_person("Vértice")
	elif key == "round_prev": round_index -= 1; page = 0; show_level(2)
	elif key == "round_next": round_index += 1; page = 0; show_level(2)
	elif key == "page_prev": page -= 1; show_level(2)
	elif key == "page_next": page += 1; show_level(2)
	elif key.begins_with("match:"):
		var index = int(key.split(":")[1])
		var fixture: Dictionary = cup.rounds[round_index].fixtures[index]
		open_person(Data.public_name(fixture.winner if key.ends_with(":winner") else fixture.loser))
	elif key.begins_with("history:"):
		open_person(following)
	elif key.begins_with("past:"):
		open_person("Tu")
	elif key == "future" or key == "next":
		open_person("Tu")
func open_person(who: String) -> void:
	clear_detail()
	var p = Data.profile(cup, who)
	detail = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("112b36")
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	detail.add_theme_stylebox_override("panel", style)
	add_child(detail)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(scroll)
	var stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 20)
	scroll.add_child(stack)
	stack.add_child(button("← VOLTAR À ÁRVORE", clear_detail))
	stack.add_child(label(who.to_upper() + "  /  " + p.sector, 34))
	if map.portraits.has(who):
		var portrait = TextureRect.new()
		portrait.texture = map.portraits[who]
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size.y = 160
		stack.add_child(portrait)
	stack.add_child(label(p.tag + "\n" + ("ELIMINADO POR " + p.eliminated_by.to_upper() if p.state == "ELIMINATED" else "EM PROVA")))
	stack.add_child(label("%d vitórias%s\n%s" % [p.wins, " publicadas" if p.confirmed_only else "", p.meeting]))
	if not p.history.is_empty():
		var last: Dictionary = p.history.back()
		stack.add_child(label("ÚLTIMO RESULTADO\n%s  %s  %s\nJornada %d" % [last.winner, last.score, last.loser, last.round]))
	else: stack.add_child(label("Ainda não há resultados publicados."))
	if p.confirmed_only: stack.add_child(label("Setor distante: apenas resultados já noticiados. O percurso completo ainda não é público.", 21))
	stack.add_child(button("VER PERCURSO", func(): follow(who)))
	arrange()
func follow(who: String) -> void:
	clear_detail()
	following = who
	var p = Data.profile(cup, who)
	map.nodes.clear(); map.edges.clear()
	caption.text = "A SEGUIR: " + who.to_upper() + " · só resultados conhecidos"
	add_node("start", "INÍCIO", Vector2(330, 0), p.sector, "PERCURSO DE " + who.to_upper(), GOLD, Vector2(400, 138))
	var prev = "start"
	for i in range(p.history.size()):
		var record: Dictionary = p.history[i]
		var key = "history:%d" % i
		add_node(key, record.winner + " venceu", Vector2(330, 210 + i * 210), record.score + " contra " + record.loser, "JORNADA %d" % record.round, MINT if record.winner == who else Color("e19a83"), Vector2(400, 158))
		edge(prev, key, record.winner == who)
		prev = key
	person(who, Vector2(330, 210 + p.history.size() * 210))
	edge(prev, who, p.state != "ELIMINATED")
	map.fit(); map.locate(who); map.queue_redraw()
func _process(_dt: float) -> void:
	if loading_portrait or portrait_queue.is_empty() or not is_visible_in_tree(): return
	make_portrait(portrait_queue.pop_front())
func make_portrait(who: String) -> void:
	loading_portrait = true
	var render = SubViewport.new()
	render.size = Vector2i(160, 160)
	render.transparent_bg = true
	render.own_world_3d = true
	render.msaa_3d = Viewport.MSAA_2X
	render.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(render)
	var model = Models.new()
	render.add_child(model)
	var cast: Array = Data.CAST[who]
	var pilot = model.build_player(Color(cast[1]), 0, player_skin if who == "Tu" else cast[0])
	pilot.position = Vector3.ZERO
	pilot.rotation.y = -0.15
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.5
	render.add_child(light)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c9e1df")
	env.environment.ambient_light_energy = 0.8
	render.add_child(env)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.8
	camera.position = Vector3(0.6, 1.4, -3)
	camera.transform = camera.transform.looking_at(Vector3(0, 0.9, 0))
	render.add_child(camera)
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() != "headless":
		var picture = render.get_texture().get_image()
		if picture != null: map.portraits[who] = ImageTexture.create_from_image(picture)
	render.queue_free()
	loading_portrait = false
	map.queue_redraw()
