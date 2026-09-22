extends SubViewport
## A still press photograph, staged with the actual gameplay models; never renders per frame.
const Models = preload("res://scripts/indie_arena_view.gd")
var stage: Node3D
var model
func pilot(who: String, pos: Vector3, turn: float = 0.0) -> Node3D:
	var entry: Array = preload("res://scripts/cup_tree_data.gd").CAST.get(who, [101, "719ba3"])
	var p = model.build_player(Color(entry[1]), 0, entry[0], stage)
	p.position = pos
	p.rotation.y = turn
	return p
func block(pos: Vector3, dimensions: Vector3, color: String, glow: bool = false) -> void:
	model.box(stage, pos, dimensions, Color(color), glow)
func sign_text(value: String, pos: Vector3, scale_size: float = 0.009) -> void:
	var l = Label3D.new()
	l.text = value
	l.font_size = 48
	l.pixel_size = scale_size
	l.position = pos
	l.modulate = Color("e8bd78")
	l.rotation.y = PI
	stage.add_child(l)
func setup(story: Dictionary) -> void:
	size = Vector2i(960, 540)
	own_world_3d = true
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_ONCE
	stage = Node3D.new()
	add_child(stage)
	model = Models.new()
	stage.add_child(model)
	var scene: String = story.cenario
	var press = scene in ["POST_MATCH_INTERVIEW", "PRESS_CONFERENCE"]
	var quiet = scene in ["BACKSTAGE", "TRAINING", "ARENA_ENTRANCE"]
	block(Vector3(0, -0.16, 0), Vector3(16, 0.3, 13), "20353e")
	block(Vector3(0, 2, 4), Vector3(16, 4, 0.3), "12252e")
	for x in [-6, -3, 0, 3, 6]:
		block(Vector3(x, 2, 3.75), Vector3(0.05, 3.6, 0.05), "81d9c4", true)
	sign_text("A U R O R A   /   P R E S S" if press else "C H A R G E   /   A R E N A", Vector3(0, 3.2, 3.5))
	for z in [-2, 1, 3]:
		block(Vector3(0, 0.012, z), Vector3(12, 0.02, 0.035), "648c8f", true)
	var main = pilot(story.personagemPrincipal, Vector3(-0.65, 0, -0.4), -0.18)
	if quiet:
		main.position = Vector3(-1, 0, 0.5)
		main.rotation.y = -0.7
		for x in [-3.5, 3.5]:
			block(Vector3(x, 1.1, 1), Vector3(1.5, 2.2, 1), "314b55")
			block(Vector3(x, 1.4, 0.48), Vector3(1.1, 0.08, 0.04), "e8bd78", true)
		block(Vector3(1.8, 0.4, 1), Vector3(2.6, 0.15, 0.9), "718383")
		if scene == "TRAINING":
			for i in range(3): block(Vector3(1.7 + i * 0.6, 0.35, -0.5), Vector3(0.45, 0.7, 0.45), "d1a968")
	else:
		# Low-cost audience silhouettes give depth without duplicating full skin meshes.
		for i in range(24):
			var pos = Vector3(-6.5 + (i % 12) * 1.15, 0.45 + (i / 12) * 0.5, 2.6 + (i / 12) * 0.5)
			model.sphere(stage, pos + Vector3.UP * 0.75, Vector3.ONE * 0.22, Color("719095"))
			block(pos + Vector3.UP * 0.3, Vector3(0.35, 0.55, 0.25), "3f656c")
		block(Vector3(0, 0.55, 2.2), Vector3(13, 0.08, 0.08), "e8bd78", true)
	if press:
		pilot("Mineiro", Vector3(2.4, 0, -1.6), -1.0)
		for i in range(3):
			var x = -1.4 + i * 0.8
			model.cylinder(stage, Vector3(x, 0.6, -1.25), 0.035, 1.2, Color("aeb7b6"), false, 12)
			model.sphere(stage, Vector3(x, 1.23, -1.25), Vector3(0.13, 0.10, 0.17), Color("15222a"))
		if scene == "PRESS_CONFERENCE": block(Vector3(-0.4, 0.7, -1.0), Vector3(3.8, 0.12, 0.65), "314a50")
	if scene in ["FACE_OFF", "FINAL_PROMO"]:
		main.position.x = -1.6
		main.rotation.y = -0.9
		pilot(story.get("personagemSecundario", "Tu"), Vector3(1.6, 0, -0.2), 0.9)
		sign_text("T A Ç A   A U R O R A", Vector3(0, 2.6, 2))
	elif scene in ["UPSET", "ARENA_VICTORY", "CROWD_CELEBRATION", "ARENA_DEFEAT"]:
		var loser = pilot(story.get("personagemSecundario", "") if not str(story.get("personagemSecundario", "")).is_empty() else "Lira", Vector3(2, 0, 0.8), 0.65)
		loser.get_node("Body").rotation.z = -0.25
		loser.get_node("Body").position.y = -0.25
		main.get_node("Body").rotation.z = 0.08
		if scene == "ARENA_DEFEAT":
			main.get_node("Body").rotation.x = -0.25
			loser.hide()
	if scene in ["CROWD_CELEBRATION", "FINAL_PROMO"]:
		model.cylinder(stage, Vector3(-2, 0.45, -0.1), 0.45, 0.9, Color("172b33"))
		model.cylinder(stage, Vector3(-2, 1.1, -0.1), 0.09, 0.4, Color("e8bd78"))
		model.sphere(stage, Vector3(-2, 1.38, -0.1), Vector3(0.34, 0.24, 0.34), Color("e8bd78"))
		for side in [-1, 1]:
			var handle = model.torus(stage, Vector3(-2 + side * 0.32, 1.4, -0.1), 0.16, 0.035, Color("e8bd78"))
			handle.rotation.x = PI / 2
		for i in range(35):
			block(Vector3(sin(i * 2.3) * 4, 1.5 + (i % 7) * 0.3, cos(i * 1.7)), Vector3(0.06, 0.12, 0.025), "e8bd78" if i % 2 == 0 else "81d9c4", true)
	# A broadcast camera in the foreground makes the frame a witnessed event.
	if not quiet:
		block(Vector3(3.0, 0.75, -2), Vector3(0.06, 1.5, 0.06), "7e9294")
		block(Vector3(3.0, 1.55, -2), Vector3(0.6, 0.4, 0.6), "101e27")
		block(Vector3(2.72, 1.57, -2.25), Vector3(0.06, 0.08, 0.06), "e87659", true)
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("12252e")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a3ccd1")
	world.environment.ambient_light_energy = 0.65
	add_child(world)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.light_color = Color("ffe7bd")
	light.light_energy = 1.6
	add_child(light)
	var camera = Camera3D.new()
	camera.position = Vector3(-2.5, 2.1, -5.5) if quiet else Vector3(0.5, 2.2, -6.6)
	camera.fov = 43
	if press:
		camera.position = Vector3(-0.2, 1.65, -4.2)
		camera.fov = 38
	camera.transform = camera.transform.looking_at(Vector3(-0.65, 1.0, -0.2) if press else Vector3(0, 1.15, 0.6))
	add_child(camera)

