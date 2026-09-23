extends VBoxContainer
const Data = preload("res://scripts/cup_route_data.gd")
const Models = preload("res://scripts/indie_arena_view.gd")
const MINT = Color("81d9c4")
const GOLD = Color("e8bd78")
var cup
var player_skin = 0
var last_result = ""
var public_route: Dictionary
var avatar: TextureRect
func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	resized.connect(arrange_portrait)
	public_route = Data.snapshot(cup)
	var future = panel(Color("172c34"), GOLD)
	future.add_child(label("CONQUISTADO" if public_route.state == "COMPLETE" else "SE VENCER  /  O TEU PRÓXIMO PASSO", 22, GOLD))
	future.add_child(label(public_route.consequence, 28))
	link(true)
	var current = panel(Color("1c3b44"), MINT, 3)
	current.add_child(label("TU ESTÁS AQUI   •   %02d VITÓRIAS" % cup.wins, 25, MINT))
	current.add_child(label(public_route.stage.to_upper(), 38))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	current.add_child(row)
	var words = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	if public_route.state == "COMPLETE":
		words.add_child(label("ESTE É O CAMINHO QUE CONSTRUÍSTE", 28, GOLD))
		words.add_child(label("Todas as tuas vitórias estão guardadas abaixo.", 25))
	elif public_route.state == "WAITING":
		words.add_child(label("PRÓXIMO ADVERSÁRIO", 23, GOLD))
		words.add_child(label("ADVERSÁRIO A DEFINIR", 38))
		words.add_child(label("A aguardar o resultado da chave. O encontro ainda não está confirmado.", 25))
	else:
		words.add_child(label(("GRANDE FINAL · CONFIRMADA" if public_route.grand_final else "FINAL DO SETOR · CONFIRMADA") if public_route.large_encounter else "PRÓXIMO CONFRONTO CONFIRMADO", 22, GOLD))
		words.add_child(label(public_route.opponent.to_upper(), 44))
		words.add_child(label("Tu contra quem chegou até aqui.", 24))
	portrait(row)
	if not last_result.is_empty(): current.add_child(label("ÚLTIMO COMBATE   /   " + last_result, 23, MINT))
	link(false)
	add_child(label("FICARAM PARA TRÁS   /   AS TUAS VITÓRIAS", 23, GOLD))
	link(false)
	if public_route.history.is_empty():
		var start = panel(Color("122730"), Color("36535c"))
		start.add_child(label("O teu caminho começa agora.", 30))
		start.add_child(label("Ainda não há vitórias no teu histórico.", 24))
	else:
		for i in range(public_route.history.size()):
			var record: Dictionary = public_route.history[i]
			var past = panel(Color("122730"), Color("36535c"))
			past.add_child(label("✓  FINAL DO SETOR · RONDA %02d" % record.round if record.get("boss", 0) > 0 else "✓  RONDA %02d" % record.round, 22, MINT))
			past.add_child(label(record.opponent.to_upper(), 32))
			past.add_child(label("Vitória %s–%s%s" % [record.score[0], record.score[1], "   •   o último adversário que venceste" if i == 0 else ""], 25))
			link(false)
	add_child(label("INÍCIO   /   TAÇA AURORA", 22, Color("8fa8b0")))
func label(value: String, points: int, color: Color = Color("eef0e5")) -> Label:
	var l = Label.new()
	l.text = value
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", points)
	l.add_theme_color_override("font_color", color)
	return l
func panel(color: Color, edge: Color, width: int = 1) -> VBoxContainer:
	var frame = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	frame.add_child(stack)
	return stack
func link(future: bool) -> void:
	var line = Control.new()
	line.custom_minimum_size.y = 42
	line.draw.connect(func():
		var x = line.size.x * 0.5
		var color = GOLD if future else MINT.darkened(0.25)
		line.draw_line(Vector2(x, 0), Vector2(x, 42), color, 3, true)
		if future:
			line.draw_line(Vector2(x, 8), Vector2(x - 8, 18), color, 3, true)
			line.draw_line(Vector2(x, 8), Vector2(x + 8, 18), color, 3, true)
	)
	add_child(line)
func portrait(parent: Control) -> void:
	var image = TextureRect.new()
	avatar = image
	image.custom_minimum_size = Vector2(160, 160)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var identity = VBoxContainer.new()
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(identity)
	identity.add_child(image)
	var tag = label("TU", 22, MINT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.add_child(tag)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(320, 280)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	image.add_child(viewport)
	var models = Models.new()
	viewport.add_child(models)
	var player = models.build_player(MINT, 0, player_skin)
	player.position = Vector3.ZERO
	player.rotation.y = -0.15
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.6
	viewport.add_child(light)
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b4dce3")
	world.environment.ambient_light_energy = 0.7
	viewport.add_child(world)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0.6, 1.4, -3)
	camera.transform = camera.transform.looking_at(Vector3(0, 0.8, 0))
	viewport.add_child(camera)
	image.texture = viewport.get_texture()

func arrange_portrait() -> void:
	if is_instance_valid(avatar): avatar.custom_minimum_size = Vector2(160, 140) if size.x < 720 else Vector2(220, 180)
