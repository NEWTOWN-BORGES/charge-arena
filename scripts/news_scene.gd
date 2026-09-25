extends SubViewport
## A press photograph for AURORA EM CAMPO: the game's own pilot models, posed on a set and
## lit, rendered once into a still. Never renders per frame.
##
## Sets: ARENA, DOCK (a platform in open space, a planet and ships going by), BRIDGE (a
## ship's bridge with the stars through the glass), HANGAR, CORRIDOR (a ship's corridor),
## PRESS_ROOM, LOCKER, PLAZA (the Praça da Taça with Rosa's kiosk), BOX (a VIP box over
## the arena) and OBSERVATORY. The scene says what is happening on it.
const Models = preload("res://scripts/indie_arena_view.gd")
const SPACE = preload("res://shaders/press_space.gdshader")
var stage: Node3D
var model
var cast_specs: Dictionary = {}
var variation = 0

const DEFAULT_SET = {
	"ARENA_VICTORY": "ARENA", "ARENA_DEFEAT": "CORRIDOR", "POST_MATCH_INTERVIEW": "PRESS_ROOM",
	"PRESS_CONFERENCE": "PRESS_ROOM", "BACKSTAGE": "LOCKER", "ARENA_ENTRANCE": "DOCK", "FACE_OFF": "CORRIDOR",
	"TRAINING": "HANGAR", "CROWD_CELEBRATION": "ARENA", "UPSET": "ARENA", "FINAL_PROMO": "BRIDGE",
}

func pilot(who: String, pos: Vector3, turn: float = 0.0) -> Node3D:
	var entry: Array = cast_specs.get(who, [101, "719ba3"])
	var p = model.build_player(Color(String(entry[1])), 0, int(entry[0]), stage)
	p.position = pos
	p.rotation.y = turn
	return p

func face(node: Node3D, target: Vector3) -> void:
	# Turn a pilot to look at a point: its front is local -Z.
	var to = target - node.position
	node.rotation.y = atan2(-to.x, -to.z)

func block(pos: Vector3, dimensions: Vector3, color: String, glow: bool = false) -> MeshInstance3D:
	return model.box(stage, pos, dimensions, Color(color), glow, 0.02)

func sign_text(value: String, pos: Vector3, scale_size: float = 0.009, color: String = "e8bd78") -> void:
	var l = Label3D.new()
	l.text = value
	l.font_size = 48
	l.pixel_size = scale_size
	l.position = pos
	l.modulate = Color(color)
	# Labels read from +Z; the camera looks from -Z.
	l.rotation.y = PI
	stage.add_child(l)

func setup(story: Dictionary) -> void:
	cast_specs = story.get("cast", {})
	variation = int(story.get("visual_variant", 0))
	size = Vector2i(960, 600)
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	# Drawn continuously while it develops; the paper reads it back and lets it go.
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage = Node3D.new()
	add_child(stage)
	model = Models.new()
	# Full shading for a still that is only drawn once.
	model.quality_level = 2
	stage.add_child(model)
	var scene: String = String(story.get("cenario", "ARENA_VICTORY"))
	var set_name: String = String(story.get("set", DEFAULT_SET.get(scene, "ARENA")))
	var camera = Camera3D.new()
	camera.fov = 40
	add_child(camera)
	var mood = build_set(set_name, camera)
	stage_actors(scene, set_name, String(story.get("personagemPrincipal", "")), String(story.get("personagemSecundario", "")))
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	if mood.space:
		var sky = Sky.new()
		var sky_material = ShaderMaterial.new()
		sky_material.shader = SPACE
		sky_material.set_shader_parameter("nebula_a", [Color("6b2a86"), Color("1f5a8a"), Color("7a3b2a"), Color("2a7a6a")][variation % 4])
		sky_material.set_shader_parameter("nebula_b", [Color("15576f"), Color("5a2a6f"), Color("2a4a7a"), Color("6a5a2a")][variation % 4])
		sky.sky_material = sky_material
		world.environment.background_mode = Environment.BG_SKY
		world.environment.sky = sky
	else:
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = mood.back
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = mood.ambient
	world.environment.ambient_light_energy = mood.ambient_energy
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.adjustment_enabled = true
	world.environment.adjustment_saturation = 1.12
	add_child(world)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = mood.sun
	light.light_color = mood.sun_color
	light.light_energy = 1.5
	add_child(light)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 160, 0)
	fill.light_color = mood.rim
	fill.light_energy = 0.8
	add_child(fill)

func build_set(set_name: String, camera: Camera3D) -> Dictionary:
	var mood = {"space": false, "back": Color("0f1d24"), "ambient": Color("a3ccd1"), "ambient_energy": 0.6, "sun": Vector3(-45, -25, 0), "sun_color": Color("ffe7bd"), "rim": Color("8fc8ff")}
	var side = [-0.6, 0.0, 0.6][variation % 3]
	match set_name:
		"DOCK":
			# A landing platform hanging in open space; a planet low on the horizon and a
			# couple of ships on their way in.
			mood.space = true
			mood.sun = Vector3(-20, -60, 0)
			mood.sun_color = Color("ffd9a8")
			block(Vector3(0, -0.2, 0.5), Vector3(9, 0.4, 7), "2a3a44")
			for x in [-4.3, 4.3]:
				block(Vector3(x, 0.05, 0.5), Vector3(0.12, 0.1, 7), "e8bd78", true)
			for z in [-2.0, 0.5, 3.0]:
				block(Vector3(0, 0.02, z), Vector3(8, 0.02, 0.06), "81d9c4", true)
			var planet = model.sphere(stage, Vector3(-9 + variation % 3 * 3, 1.5, 26), Vector3.ONE * 14, Color("c77a4a"))
			planet.rotation.z = 0.4
			var ring = model.torus(stage, planet.position, 10.5, 0.25, Color("e8c9a0", 0.5), true)
			ring.scale = Vector3(1, 0.08, 1)
			ring.rotation.x = 0.3
			for i in range(2):
				var ship = Node3D.new()
				stage.add_child(ship)
				ship.position = Vector3(5 - i * 9, 4 + i * 1.5, 14 + i * 4)
				model.box(ship, Vector3.ZERO, Vector3(2.2, 0.35, 0.8), Color("8a9aa3"), false, 0.1)
				model.box(ship, Vector3(-1.2, 0, 0), Vector3(0.4, 0.2, 0.5), Color("ff8f5c"), true, 0.05)
				model.box(ship, Vector3(0.6, 0.2, 0), Vector3(0.7, 0.2, 0.5), Color("81d9c4"), true, 0.05)
			camera.position = Vector3(0.5 + side, 1.8, -6.2)
			camera.look_at(Vector3(0, 1.3, 2.0))
		"BRIDGE":
			# A ship's bridge: consoles in a curve, and the big window onto space.
			mood.space = true
			mood.sun = Vector3(-30, 180, 0)
			mood.sun_color = Color("b9d8ff")
			mood.ambient = Color("7fa6c4")
			block(Vector3(0, -0.15, 0), Vector3(10, 0.3, 8), "1b2a33")
			for i in range(7):
				var angle = (i - 3) * 0.28
				var console = Vector3(sin(angle) * 3.4, 0.45, 1.6 + cos(angle) * 0.9)
				var c = block(console, Vector3(0.9, 0.9, 0.5), "223642")
				c.rotation.y = -angle
				var screen = block(console + Vector3(0, 0.5, -0.2), Vector3(0.75, 0.05, 0.35), ["81d9c4", "e8bd78", "ef947e"][i % 3], true)
				screen.rotation.y = -angle
			for x in [-5.0, -1.7, 1.7, 5.0]:
				block(Vector3(x, 2.4, 4.2), Vector3(0.18, 4.8, 0.18), "30414b")
			block(Vector3(0, 4.8, 4.2), Vector3(11, 0.3, 0.4), "30414b")
			block(Vector3(0, 0.3, 4.2), Vector3(11, 0.6, 0.4), "30414b")
			model.sphere(stage, Vector3(4, 2.5, 30), Vector3.ONE * 10, Color("4a7ac9"))
			camera.position = Vector3(side * 0.8, 1.7, -4.8)
			camera.look_at(Vector3(0, 1.4, 2.5))
		"HANGAR":
			# A ship's hangar: ribs overhead, a parked ship, the bay open onto the stars.
			mood.space = true
			mood.sun = Vector3(-50, -20, 0)
			block(Vector3(0, -0.15, 1), Vector3(12, 0.3, 11), "2b3338")
			for z in [-1.0, 1.5, 4.0]:
				for x in [-5.5, 5.5]:
					block(Vector3(x, 2.8, z), Vector3(0.3, 5.6, 0.3), "3a4650")
				var rib = block(Vector3(0, 5.6, z), Vector3(11.4, 0.3, 0.3), "3a4650")
				rib.rotation.z = 0.0
			for x in [-5.5, 5.5]:
				block(Vector3(x, 0.1, 1), Vector3(0.1, 0.1, 10), "e8bd78", true)
			var ship = Node3D.new()
			stage.add_child(ship)
			ship.position = Vector3(3.3, 0.9, 3.4)
			ship.rotation.y = -0.5
			model.box(ship, Vector3.ZERO, Vector3(3.6, 0.9, 1.6), Color("c9d2d6"), false, 0.3)
			model.box(ship, Vector3(1.4, 0.45, 0), Vector3(1.0, 0.45, 1.0), Color("2a3a44"), false, 0.2)
			model.box(ship, Vector3(-1.9, 0, 0), Vector3(0.5, 0.5, 1.2), Color("81d9c4"), true, 0.1)
			for x in [-3, -1.5, 0, 1.5, 3]:
				block(Vector3(x, 0.02, -1.5), Vector3(0.9, 0.02, 0.12), "ffcf5c", true)
			camera.position = Vector3(-1.2 + side, 1.9, -5.8)
			camera.look_at(Vector3(0.4, 1.1, 2.4))
		"CORRIDOR":
			# A ship's corridor: frames repeating into the distance, light strips along the floor.
			mood.back = Color("0a1418")
			mood.ambient_energy = 0.45
			mood.sun = Vector3(-70, 0, 0)
			block(Vector3(0, -0.1, 6), Vector3(4, 0.2, 18), "1f2a30")
			for i in range(8):
				var z = -1.0 + i * 2.2
				block(Vector3(-1.9, 1.5, z), Vector3(0.25, 3.0, 0.4), "34444d")
				block(Vector3(1.9, 1.5, z), Vector3(0.25, 3.0, 0.4), "34444d")
				block(Vector3(0, 3.0, z), Vector3(4.0, 0.25, 0.4), "34444d")
				block(Vector3(0, 2.86, z), Vector3(1.6, 0.04, 0.2), "dff4ff", true)
			for x in [-1.6, 1.6]:
				block(Vector3(x, 0.03, 6), Vector3(0.06, 0.04, 18), "81d9c4" if x < 0 else "ef947e", true)
			block(Vector3(-1.95, 1.6, 4), Vector3(0.05, 1.8, 3.0), "30414b")
			camera.position = Vector3(0.4 + side * 0.4, 1.5, -4.2)
			camera.look_at(Vector3(0, 1.1, 3.0))
		"PRESS_ROOM":
			# The press room: a wall of sponsors behind, a table, microphones, flashes.
			mood.back = Color("141d22")
			block(Vector3(0, -0.15, 0), Vector3(12, 0.3, 9), "22303a")
			block(Vector3(0, 2.2, 2.8), Vector3(9, 4.4, 0.2), "11232c")
			for x in range(-4, 5):
				for y in range(4):
					var logo = "AURORA" if (x + y) % 2 == 0 else "TAÇA"
					sign_text(logo, Vector3(x * 1.0, 0.6 + y * 1.0, 2.68), 0.004, "e8bd78" if logo == "AURORA" else "81d9c4")
			block(Vector3(0, 0.75, 0.9), Vector3(4.4, 0.12, 1.0), "314a50")
			block(Vector3(0, 0.38, 1.35), Vector3(4.4, 0.75, 0.08), "1c2c33")
			for i in range(4):
				var x = -1.5 + i * 1.0
				model.cylinder(stage, Vector3(x, 0.98, 0.6), 0.02, 0.4, Color("aeb7b6"), false, 8)
				model.sphere(stage, Vector3(x, 1.2, 0.55), Vector3(0.1, 0.08, 0.13), Color(["e8bd78", "ef947e", "81d9c4", "c8a8ff"][i]))
			camera.position = Vector3(side, 1.55, -4.0)
			camera.look_at(Vector3(0, 1.25, 1.5))
		"LOCKER":
			# The pilots' locker room: a row of lockers, a bench, a strip light.
			mood.back = Color("121a1d")
			mood.ambient_energy = 0.5
			block(Vector3(0, -0.15, 0), Vector3(10, 0.3, 8), "2a2f33")
			for i in range(9):
				var x = -4.0 + i
				block(Vector3(x, 1.2, 2.6), Vector3(0.92, 2.4, 0.6), ["3a5560", "35505a"][i % 2])
				block(Vector3(x + 0.3, 1.4, 2.28), Vector3(0.06, 0.3, 0.04), "b9c3c6")
				sign_text("%02d" % (i + 1), Vector3(x, 2.1, 2.29), 0.004, "dff4ff")
			block(Vector3(0, 0.3, 1.2), Vector3(5, 0.12, 0.5), "6a5440")
			block(Vector3(0, 3.1, 1.5), Vector3(8, 0.06, 0.2), "fff3d8", true)
			camera.position = Vector3(-1.4 + side, 1.6, -4.4)
			camera.look_at(Vector3(0, 1.1, 2.0))
		"PLAZA":
			# The Praça da Taça at night: Rosa's kiosk with its striped awning, lamp posts,
			# the Taça on a plinth and the planet over the rooftops.
			mood.space = true
			mood.sun = Vector3(-35, 30, 0)
			mood.sun_color = Color("ffd7a0")
			block(Vector3(0, -0.15, 2), Vector3(16, 0.3, 14), "3a3a38")
			for x in range(-7, 8, 2):
				block(Vector3(x, 0.01, 2), Vector3(0.05, 0.02, 14), "4a4a46")
			# The kiosk.
			block(Vector3(-3.4, 0.8, 2.6), Vector3(2.2, 1.6, 1.4), "2d4a52")
			for i in range(6):
				block(Vector3(-4.3 + i * 0.37, 1.95, 1.8), Vector3(0.36, 0.08, 0.9), "e8bd78" if i % 2 == 0 else "f3eee1")
			for i in range(5):
				block(Vector3(-4.1 + i * 0.4, 1.2, 1.88), Vector3(0.32, 0.42, 0.02), "f3eee1")
			sign_text("BANCA DA ROSA", Vector3(-3.4, 2.25, 1.85), 0.005)
			# The Taça.
			model.cylinder(stage, Vector3(3.2, 0.6, 3.5), 0.7, 1.2, Color("1c2c33"))
			model.cylinder(stage, Vector3(3.2, 1.5, 3.5), 0.12, 0.6, Color("e8bd78"))
			model.sphere(stage, Vector3(3.2, 2.05, 3.5), Vector3(0.7, 0.5, 0.7), Color("e8bd78"))
			for x in [-6, 0, 6]:
				model.cylinder(stage, Vector3(x, 1.5, 5.5), 0.06, 3.0, Color("2a3238"))
				model.sphere(stage, Vector3(x, 3.1, 5.5), Vector3.ONE * 0.3, Color("fff0c8"), true)
			for i in range(18):
				var pos = Vector3(-6 + (i % 9) * 1.4, 0.0, 4.2 + (i / 9) * 0.8)
				model.sphere(stage, pos + Vector3.UP * 1.05, Vector3.ONE * 0.26, Color("5f7a80"))
				block(pos + Vector3.UP * 0.45, Vector3(0.4, 0.9, 0.3), "3f5a60")
			model.sphere(stage, Vector3(7, 7, 28), Vector3.ONE * 11, Color("8a6ac9"))
			camera.position = Vector3(0.3 + side, 1.8, -5.6)
			camera.look_at(Vector3(0, 1.3, 2.6))
		"BOX":
			# A VIP box: glass over the arena's lights, deep seats, a low table.
			mood.back = Color("0c1417")
			mood.sun = Vector3(-30, 170, 0)
			mood.sun_color = Color("ffcf8a")
			block(Vector3(0, -0.15, 0), Vector3(9, 0.3, 7), "3a2a22")
			block(Vector3(0, 0.3, 3.2), Vector3(8, 0.6, 0.2), "2a1e18")
			for x in [-3.8, 0, 3.8]:
				block(Vector3(x, 2.0, 3.2), Vector3(0.1, 2.8, 0.1), "c49a4c")
			for i in range(24):
				model.sphere(stage, Vector3(-9 + i * 0.8, 1.0 + sin(i * 1.3) * 0.6, 14 + (i % 3) * 2), Vector3.ONE * 0.25, Color(["fff3d8", "81d9c4", "e8bd78"][i % 3]), true)
			block(Vector3(0, 0.05, 12), Vector3(18, 0.1, 8), "1c3a44", true)
			for x in [-2.2, 2.2]:
				block(Vector3(x, 0.45, 0.6), Vector3(1.4, 0.9, 1.2), "5a1f24")
			block(Vector3(0, 0.35, 0.8), Vector3(1.4, 0.1, 0.8), "c49a4c")
			camera.position = Vector3(-0.5 + side, 1.6, -4.2)
			camera.look_at(Vector3(0, 1.1, 1.6))
		"OBSERVATORY":
			mood.space = true
			mood.sun = Vector3(-40, 20, 0)
			block(Vector3(0, -0.15, 0), Vector3(10, 0.3, 10), "22262e")
			model.torus(stage, Vector3(0, 0.05, 0), 4.2, 0.08, Color("e8bd78"), true)
			var scope = model.cylinder(stage, Vector3(2.6, 1.6, 2.2), 0.3, 3.2, Color("7c8a9a"))
			scope.rotation.x = -0.9
			model.cylinder(stage, Vector3(2.6, 0.6, 1.4), 0.15, 1.2, Color("3a4450"))
			camera.position = Vector3(-0.8 + side, 1.5, -5.0)
			camera.look_at(Vector3(0.4, 1.4, 2.2))
		_:
			# The arena: the floor, the stands and the banners.
			var palette = Color.from_hsv(fmod(variation * 0.137 + 0.46, 1.0), 0.45, 0.5)
			block(Vector3(0, -0.16, 0), Vector3(16, 0.3, 13), "20353e")
			block(Vector3(0, 2, 4.5), Vector3(16, 4, 0.3), "12252e")
			for x in [-6, -3, 0, 3, 6]:
				block(Vector3(x, 2, 4.25), Vector3(0.05, 3.6, 0.05), "81d9c4", true)
			sign_text("C H A R G E   /   A R E N A", Vector3(0, 3.2, 4.2))
			for side_x in [-1, 1]:
				for i in range(3):
					model.box(stage, Vector3(side_x * (3.4 + i * 0.5), 1.0 + i * 0.3, 1.8), Vector3(0.12, 1.8, 0.8), palette.lightened(0.2), true)
			for i in range(30):
				var pos = Vector3(-6.5 + (i % 15) * 0.93, 0.45 + (i / 15) * 0.5, 3.2 + (i / 15) * 0.5)
				model.sphere(stage, pos + Vector3.UP * 0.75, Vector3.ONE * 0.22, Color(["719095", "8a7a6a", "6a7a95"][i % 3]))
				block(pos + Vector3.UP * 0.3, Vector3(0.35, 0.55, 0.25), "3f656c")
			block(Vector3(0, 0.55, 2.8), Vector3(13, 0.08, 0.08), "e8bd78", true)
			camera.position = Vector3(0.5 + side, 2.2, -6.6)
			camera.look_at(Vector3(0, 1.15, 0.6))
	return mood

func stage_actors(scene: String, set_name: String, who: String, other: String) -> void:
	if who == "": return
	var main = pilot(who, Vector3(-0.65, 0, -0.2), -0.2)
	match scene:
		"FACE_OFF", "FINAL_PROMO":
			main.position = Vector3(-1.3, 0, 0.2)
			main.rotation.y = -0.9
			if other != "":
				pilot(other, Vector3(1.3, 0, 0.2), 0.9)
		"ARENA_VICTORY", "UPSET", "CROWD_CELEBRATION":
			main.get_node("Body").rotation.z = 0.08
			if other != "":
				var loser = pilot(other, Vector3(1.8, 0, 0.9), 0.7)
				loser.get_node("Body").rotation.z = -0.25
				loser.get_node("Body").position.y = -0.25
			if scene == "CROWD_CELEBRATION":
				# The Taça held high, and gold paper falling.
				model.cylinder(stage, Vector3(-1.2, 1.2, -0.3), 0.08, 0.5, Color("e8bd78"))
				model.sphere(stage, Vector3(-1.2, 1.55, -0.3), Vector3(0.36, 0.26, 0.36), Color("e8bd78"))
				for i in range(40):
					block(Vector3(sin(i * 2.3) * 4, 1.2 + (i % 8) * 0.35, cos(i * 1.7) * 1.5 + 0.5), Vector3(0.06, 0.12, 0.025), "e8bd78" if i % 2 == 0 else "81d9c4", true)
		"ARENA_DEFEAT":
			main.get_node("Body").rotation.x = -0.25
			main.rotation.y = PI + 0.6
			main.position = Vector3(0, 0, 1.2)
		"POST_MATCH_INTERVIEW", "PRESS_CONFERENCE":
			main.position = Vector3(0, 0, 1.2)
			main.rotation.y = 0.0
			if other != "":
				pilot(other, Vector3(1.9, 0, 1.4), 0.4)
			# Reporters with their recorders out, backs to us, in the foreground.
			for i in range(2):
				var reporter = pilot("Repórter", Vector3(-2.5 + i * 5.0, 0, 0.1))
				reporter.scale = Vector3.ONE * 0.9
				face(reporter, main.position)
		"BACKSTAGE":
			main.position = Vector3(-1.4, 0, 0.6)
			main.rotation.y = -0.7
		"TRAINING":
			main.position = Vector3(-1.0, 0, 0.5)
			main.rotation.y = -0.5
			if other != "":
				pilot(other, Vector3(1.2, 0, 0.3), 0.6)
			for i in range(3): block(Vector3(1.8 + i * 0.6, 0.35, -0.6), Vector3(0.45, 0.7, 0.45), "d1a968")
		"ARENA_ENTRANCE":
			main.position = Vector3(0, 0, 0.6)
			main.rotation.y = -0.25
	# A broadcast camera in the foreground makes the frame a witnessed event.
	if set_name in ["ARENA", "DOCK", "PLAZA"]:
		block(Vector3(3.0, 0.75, -2), Vector3(0.06, 1.5, 0.06), "7e9294")
		block(Vector3(3.0, 1.55, -2), Vector3(0.6, 0.4, 0.6), "101e27")
		block(Vector3(2.72, 1.57, -2.25), Vector3(0.06, 0.08, 0.06), "e87659", true)
