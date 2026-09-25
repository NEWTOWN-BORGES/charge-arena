extends Control
## Rosa's kiosk as a place: a press pod on the Praça da Taça. A hovering platform ringed in
## cyan light, a curved shell of ceramic panels with gold seams, a floating halo for an
## awning, and the day's paper in holograms turning around it - the cover projected large
## overhead. Rosa sits at the counter: a robot dog built in the pilots' own hand. Tap her
## and she talks; the paper is one key away.
signal closed
signal read(number: int)
signal archive
const UI = preload("res://scripts/story_ui.gd")
const Press = preload("res://scripts/story_press.gd")
const Models = preload("res://scripts/indie_arena_view.gd")
const SPACE = preload("res://shaders/press_space.gdshader")
const HOLO = Color(0.45, 0.92, 1.0, 0.32)
const ROSE = Color("e0697a")
const MINT = Color("9ff0dc")

var cup
var hud
var viewport: SubViewport
var stage: Node3D
var model
var dog: Node3D
var head: Node3D
var tail: Node3D
var ears: Array = []
var held_paper: Node3D
var holograms: Array = []
var halo: Node3D
var drone: Node3D
var cover: Node3D
var camera: Camera3D
var clock = 0.0
var bubble: Label
var talk_index = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var view = SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.gui_input.connect(_on_view_input)
	add_child(view)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	view.add_child(viewport)
	build_scene()
	build_ui()

func build_scene() -> void:
	stage = Node3D.new()
	viewport.add_child(stage)
	model = Models.new()
	model.quality_level = 2
	stage.add_child(model)
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	var sky = Sky.new()
	var sky_material = ShaderMaterial.new()
	sky_material.shader = SPACE
	# The arena's own night: deep teal with a faint gold haze.
	sky_material.set_shader_parameter("nebula_a", Color("1c4a55"))
	sky_material.set_shader_parameter("nebula_b", Color("3a3320"))
	sky_material.set_shader_parameter("density", 0.99)
	sky.sky_material = sky_material
	world.environment.background_mode = Environment.BG_SKY
	world.environment.sky = sky
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("91b5c5")
	world.environment.ambient_light_energy = 0.5
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.tonemap_exposure = 1.1
	world.environment.adjustment_enabled = true
	world.environment.adjustment_saturation = 1.12
	stage.add_child(world)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 160, 0)
	key.light_color = Color("ffe9cc")
	key.light_energy = 1.25
	stage.add_child(key)
	var rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, -20, 0)
	rim.light_color = Color("8fc8ff")
	rim.light_energy = 0.8
	stage.add_child(rim)
	var glow = OmniLight3D.new()
	glow.position = Vector3(0, 0.6, 0.2)
	glow.light_color = Color("7fe6ff")
	glow.light_energy = 0.7
	glow.omni_range = 3.5
	stage.add_child(glow)
	var warm = OmniLight3D.new()
	warm.position = Vector3(0, 2.8, -0.6)
	warm.light_color = Color("ffd7a0")
	warm.light_energy = 1.3
	warm.omni_range = 5.0
	stage.add_child(warm)
	build_square()
	build_pod()
	build_holograms()
	build_dog()
	camera = Camera3D.new()
	camera.fov = 50
	stage.add_child(camera)
	place_camera()

func build_square() -> void:
	var DARK: Color = Models.DARK
	var CYAN: Color = Models.CYAN
	var GOLD: Color = Models.GOLD
	# The Praça's floor: the arena's dark plates and seams.
	model.box(stage, Vector3(0, -0.12, 2), Vector3(18, 0.24, 16), Color("16292f"), false, 0.02)
	for x in range(-8, 9, 2):
		model.box(stage, Vector3(x, 0.005, 2), Vector3(0.035, 0.01, 16), Color("27434d"), false, 0.0)
	for z in range(-5, 10, 2):
		model.box(stage, Vector3(0, 0.005, z), Vector3(18, 0.01, 0.035), Color("27434d"), false, 0.0)
	# Towers of the Praça behind, their windows lit.
	for i in range(7):
		var x = -9.0 + i * 3.0
		var height = 5.0 + fmod(i * 2.7, 4.0)
		var z = 10.0 + fmod(i * 1.9, 3.0)
		model.box(stage, Vector3(x, height * 0.5, z), Vector3(2.0, height, 1.6), Color("112229"), false, 0.08)
		for row in range(int(height / 0.9)):
			for col in range(3):
				if fmod(i * 7 + row * 3 + col, 5) < 2: continue
				model.box(stage, Vector3(x - 0.55 + col * 0.55, 0.6 + row * 0.9, z - 0.81), Vector3(0.3, 0.3, 0.02), [CYAN, GOLD, Color("fff0c8")][(i + row + col) % 3], true, 0.0)
	# The Taça on its plinth across the square, and the arena's planet overhead.
	model.cylinder(stage, Vector3(4.2, 0.5, 4.2), 0.6, 1.0, DARK, false, 24)
	model.torus(stage, Vector3(4.2, 1.0, 4.2), 0.6, 0.03, CYAN, true)
	model.cylinder(stage, Vector3(4.2, 1.25, 4.2), 0.1, 0.5, GOLD, false, 16)
	model.sphere(stage, Vector3(4.2, 1.7, 4.2), Vector3(0.6, 0.42, 0.6), GOLD)
	var planet = model.sphere(stage, Vector3(-8, 9, 30), Vector3.ONE * 10, Color("3f6e78"))
	var ring = model.torus(stage, planet.position, 7.8, 0.12, Color(GOLD, 0.45), true)
	ring.scale = Vector3(1, 0.1, 1)
	ring.rotation.x = 0.35

func build_pod() -> void:
	var CREAM: Color = Models.CREAM
	var DARK: Color = Models.DARK
	var GOLD: Color = Models.GOLD
	var CYAN: Color = Models.CYAN
	var center = Vector3(0, 0, 0.9)
	# The hover platform: dark disc, gold inner ring, a ring of cyan light at its edge,
	# lifted off the floor on its own glow.
	model.cylinder(stage, center + Vector3(0, 0.22, 0), 2.2, 0.16, DARK, false, 64)
	model.torus(stage, center + Vector3(0, 0.3, 0), 2.2, 0.035, CYAN, true)
	model.torus(stage, center + Vector3(0, 0.31, 0), 1.7, 0.02, GOLD, false)
	model.torus(stage, center + Vector3(0, 0.06, 0), 1.9, 0.08, Color(CYAN, 0.35), true)
	# The shell: seven ceramic panels on an arc behind the counter, gold seams, light
	# strips between them.
	for i in range(7):
		var angle = lerpf(-1.25, 1.25, i / 6.0)
		var at = center + Vector3(sin(angle) * 1.8, 1.55, cos(angle) * 1.8)
		var panel = model.box(stage, at, Vector3(0.72, 2.5, 0.12), CREAM, false, 0.08)
		panel.rotation.y = angle
		var seam = model.box(stage, at + Vector3(sin(angle), 0, cos(angle)) * -0.07 + Vector3(0, -1.0, 0), Vector3(0.6, 0.05, 0.02), GOLD, false, 0.0)
		seam.rotation.y = angle
		if i < 6:
			var gap_angle = lerpf(-1.25, 1.25, (i + 0.5) / 6.0)
			var strip = model.box(stage, center + Vector3(sin(gap_angle) * 1.74, 1.55, cos(gap_angle) * 1.74), Vector3(0.04, 2.3, 0.04), CYAN, true, 0.0)
			strip.rotation.y = gap_angle
	# The curved counter in front of Rosa, gold lip, cyan light at its foot.
	for i in range(5):
		var angle = lerpf(-0.85, 0.85, i / 4.0)
		var at = center + Vector3(sin(angle) * 0.95, 0.62, -cos(angle) * 0.95 + 0.3)
		var segment = model.box(stage, at, Vector3(0.5, 0.6, 0.14), CREAM, false, 0.06)
		segment.rotation.y = -angle
		var lip = model.box(stage, at + Vector3(0, 0.32, -0.03), Vector3(0.52, 0.05, 0.24), GOLD, false, 0.02)
		lip.rotation.y = -angle
		var light = model.box(stage, at + Vector3(0, -0.22, -0.08), Vector3(0.44, 0.03, 0.02), CYAN, true, 0.0)
		light.rotation.y = -angle
	# The floating halo that stands for an awning, and the sign on it.
	halo = Node3D.new()
	halo.position = center + Vector3(0, 3.1, -0.1)
	stage.add_child(halo)
	var halo_ring = model.torus(halo, Vector3.ZERO, 1.9, 0.09, CREAM, false)
	halo_ring.scale = Vector3(1, 0.6, 1)
	model.torus(halo, Vector3(0, -0.06, 0), 1.9, 0.03, GOLD, false)
	model.torus(halo, Vector3(0, -0.1, 0), 1.86, 0.02, Color("ffe3b0"), true)
	for k in range(12):
		var a = k * TAU / 12.0
		model.sphere(halo, Vector3(cos(a) * 1.9, 0.0, sin(a) * 1.9), Vector3.ONE * 0.06, CYAN, true)
	var sign_label = Label3D.new()
	sign_label.text = Press.KIOSK_NAME
	sign_label.font = load("res://art/fonts/Rajdhani-Bold.ttf")
	sign_label.font_size = 72
	sign_label.pixel_size = 0.005
	sign_label.outline_size = 10
	sign_label.outline_modulate = Color("0b1a20")
	sign_label.position = center + Vector3(0, 3.55, -0.6)
	sign_label.modulate = Color("e8bd78")
	sign_label.rotation.y = PI
	stage.add_child(sign_label)
	# A print drone hovering by the counter, today's paper hanging under it.
	drone = Node3D.new()
	drone.position = center + Vector3(-1.35, 1.9, -0.7)
	stage.add_child(drone)
	model.sphere(drone, Vector3.ZERO, Vector3(0.36, 0.18, 0.36), CREAM)
	model.torus(drone, Vector3.ZERO, 0.24, 0.02, GOLD, false)
	for side in [-1, 1]:
		model.cylinder(drone, Vector3(side * 0.26, 0.05, 0), 0.1, 0.02, CYAN, true, 16)
	model.sphere(drone, Vector3(0, 0, -0.17), Vector3(0.1, 0.06, 0.04), MINT, true)
	model.box(drone, Vector3(0, -0.3, 0), Vector3(0.3, 0.4, 0.015), Color("f3eee1"), false, 0.003)
	model.box(drone, Vector3(0, -0.18, -0.01), Vector3(0.24, 0.05, 0.004), Color("16191c"), false, 0.0)

func build_holograms() -> void:
	# The day's paper in light: pages turning slowly around the pod, and the cover large
	# overhead with its headline.
	var e: Dictionary = Press.edition(cup, Press.editions_available(cup) - 1)
	var center = Vector3(0, 0, 0.9)
	for i in range(6):
		var page = Node3D.new()
		var angle = lerpf(-2.2, 2.2, i / 5.0)
		var radius = 2.5 + (i % 2) * 0.3
		page.position = center + Vector3(sin(angle) * radius, 1.3 + (i % 3) * 0.55, cos(angle) * radius * 0.6 - 0.4)
		page.rotation.y = angle + PI
		stage.add_child(page)
		model.box(page, Vector3.ZERO, Vector3(0.46, 0.6, 0.01), HOLO, true, 0.0)
		model.box(page, Vector3(0, 0.2, -0.006), Vector3(0.38, 0.06, 0.004), Color(1, 1, 1, 0.8), true, 0.0)
		model.box(page, Vector3(0, -0.03, -0.006), Vector3(0.38, 0.22, 0.004), Color(0.5, 0.95, 1.0, 0.45), true, 0.0)
		for line in range(3):
			model.box(page, Vector3(0, -0.2 - line * 0.04, -0.006), Vector3(0.36, 0.012, 0.004), Color(1, 1, 1, 0.5), true, 0.0)
		holograms.append({"node": page, "base": page.position, "phase": i * 1.3})
	cover = Node3D.new()
	cover.position = center + Vector3(0, 4.35, -0.7)
	stage.add_child(cover)
	model.box(cover, Vector3.ZERO, Vector3(2.4, 0.9, 0.01), Color(0.45, 0.92, 1.0, 0.22), true, 0.0)
	for edge in [[Vector3(0, 0.45, 0), Vector3(2.4, 0.02, 0.01)], [Vector3(0, -0.45, 0), Vector3(2.4, 0.02, 0.01)]]:
		model.box(cover, edge[0], edge[1], Color(0.6, 0.95, 1.0, 0.9), true, 0.0)
	var mast = Label3D.new()
	mast.text = "AURORA EM CAMPO  ·  N.º %03d" % int(e.number)
	mast.font = load("res://art/fonts/Rajdhani-Bold.ttf")
	mast.font_size = 40
	mast.pixel_size = 0.004
	mast.modulate = Color("e8bd78")
	mast.position = Vector3(0, 0.28, -0.02)
	mast.rotation.y = PI
	cover.add_child(mast)
	var line = Label3D.new()
	line.text = String(e.headline)
	line.font = load("res://art/fonts/press/PlayfairDisplay.ttf")
	line.font_size = 64
	line.pixel_size = 0.0036
	line.width = 600
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.modulate = Color("dff9ff")
	line.position = Vector3(0, -0.06, -0.02)
	line.rotation.y = PI
	cover.add_child(line)

func build_dog() -> void:
	# Rosa, drawn in the same hand as the pilots: the ceramic helmet, the polished dark
	# visor with mint eyes, gold at the joints, rounded plates - a robot dog in a newsboy
	# cap and her rose scarf, sitting behind the counter.
	var CREAM: Color = Models.CREAM
	var DARK: Color = Models.DARK
	var GOLD: Color = Models.GOLD
	dog = Node3D.new()
	# On a stool behind the counter, so she stands over it from the chest up.
	dog.position = Vector3(0.0, 0.62, 1.25)
	dog.scale = Vector3.ONE * 1.15
	stage.add_child(dog)
	# Sitting: haunches and hind paws in the pilots' boots.
	for side in [-1, 1]:
		model.sphere(dog, Vector3(side * 0.22, 0.2, 0.18), Vector3(0.3, 0.34, 0.42), CREAM)
		model.box(dog, Vector3(side * 0.24, 0.05, -0.06), Vector3(0.22, 0.12, 0.3), CREAM, false, 0.06)
		model.box(dog, Vector3(side * 0.24, -0.005, -0.06), Vector3(0.23, 0.04, 0.31), DARK, false, 0.0)
	# Chest: an upright rounded plate, a rose panel, a gold press badge.
	model.box(dog, Vector3(0, 0.46, 0.02), Vector3(0.5, 0.56, 0.44), CREAM, false, 0.16)
	model.box(dog, Vector3(0, 0.44, -0.2), Vector3(0.3, 0.3, 0.04), ROSE, false, 0.05)
	var badge = model.cylinder(dog, Vector3(0, 0.46, -0.225), 0.075, 0.02, GOLD, false, 20)
	badge.rotation_degrees.x = 90
	model.box(dog, Vector3(0, 0.46, -0.24), Vector3(0.07, 0.05, 0.01), Color("f3eee1"), true, 0.0)
	# Shoulders in her colour and front legs with dark joints, like a pilot's arms.
	for side in [-1, 1]:
		model.sphere(dog, Vector3(side * 0.22, 0.64, -0.1), Vector3(0.22, 0.24, 0.24), ROSE)
		model.sphere(dog, Vector3(side * 0.19, 0.36, -0.2), Vector3(0.14, 0.3, 0.14), DARK)
		model.box(dog, Vector3(side * 0.19, 0.08, -0.26), Vector3(0.16, 0.1, 0.2), CREAM, false, 0.05)
	var scarf = model.torus(dog, Vector3(0, 0.76, -0.04), 0.24, 0.05, ROSE, false)
	scarf.scale = Vector3(1, 1.2, 0.9)
	var knot = model.box(dog, Vector3(0.17, 0.66, -0.2), Vector3(0.08, 0.2, 0.04), ROSE, false, 0.03)
	knot.rotation.z = 0.3
	head = Node3D.new()
	head.position = Vector3(0, 1.06, -0.04)
	dog.add_child(head)
	# The helmet and the visor are the pilots' own.
	model.sphere(head, Vector3.ZERO, Vector3(0.78, 0.7, 0.7), CREAM)
	var visor = model.sphere(head, Vector3(0, 0.03, -0.23), Vector3(0.62, 0.34, 0.28), DARK)
	visor.material_override = model.visor_glass()
	for x in [-0.13, 0.13]:
		# Happy eyes: two small arcs of mint light.
		var inner = model.box(head, Vector3(x - 0.02 * signf(x), 0.065, -0.37), Vector3(0.06, 0.03, 0.02), MINT, true, 0.01)
		inner.rotation.z = 0.4 * signf(x)
		var outer = model.box(head, Vector3(x + 0.025 * signf(x), 0.065, -0.37), Vector3(0.06, 0.03, 0.02), MINT, true, 0.01)
		outer.rotation.z = -0.4 * signf(x)
	for glint in [[-0.18, 0.12, 0.12, 0.022], [-0.05, 0.15, 0.03, 0.022]]:
		var streak = model.box(head, Vector3(glint[0], glint[1], -0.355), Vector3(glint[2], glint[3], 0.008), Color(1, 1, 1, 0.55), true, 0.004)
		streak.rotation_degrees.z = -16
	# The muzzle under the visor and a dark nose.
	model.box(head, Vector3(0, -0.16, -0.3), Vector3(0.26, 0.15, 0.2), CREAM, false, 0.07)
	model.sphere(head, Vector3(0, -0.12, -0.41), Vector3(0.09, 0.07, 0.06), DARK)
	# Ears: ceramic shells hinged on the gold discs where a pilot wears its earphones.
	for side in [-1, 1]:
		model.sphere(head, Vector3(side * 0.37, 0.02, 0.02), Vector3(0.12, 0.26, 0.26), GOLD)
		var ear = Node3D.new()
		ear.position = Vector3(side * 0.3, 0.26, 0.04)
		head.add_child(ear)
		var shell = model.sphere(ear, Vector3(side * 0.06, -0.14, 0.0), Vector3(0.14, 0.36, 0.2), CREAM)
		shell.rotation.z = side * 0.35
		ears.append(ear)
	# The newsboy cap: soft crown, short brim, gold button, a press card in the band.
	model.sphere(head, Vector3(0, 0.3, 0.02), Vector3(0.66, 0.24, 0.62), DARK)
	model.box(head, Vector3(0, 0.23, -0.3), Vector3(0.42, 0.035, 0.18), Color("1a2e36"), false, 0.02)
	model.sphere(head, Vector3(0, 0.42, 0.02), Vector3.ONE * 0.07, GOLD)
	var press_card = model.box(head, Vector3(0.24, 0.32, -0.12), Vector3(0.12, 0.09, 0.01), Color("f3eee1"), false, 0.004)
	press_card.rotation.y = -0.6
	# Tail: cream segments ending in a mint light, like a pilot's antenna.
	tail = Node3D.new()
	tail.position = Vector3(0, 0.22, 0.38)
	dog.add_child(tail)
	for k in range(3):
		model.sphere(tail, Vector3(0, 0.05 + k * 0.1, 0.05 + k * 0.06), Vector3.ONE * (0.12 - k * 0.015), CREAM)
	model.sphere(tail, Vector3(0, 0.36, 0.22), Vector3.ONE * 0.07, MINT, true)
	# Today's paper, held up in a paw now and then.
	held_paper = Node3D.new()
	held_paper.position = Vector3(-0.34, 0.5, -0.32)
	dog.add_child(held_paper)
	model.box(held_paper, Vector3.ZERO, Vector3(0.36, 0.46, 0.02), Color("f3eee1"), false, 0.004)
	model.box(held_paper, Vector3(0, 0.15, -0.012), Vector3(0.3, 0.06, 0.005), Color("16191c"), false, 0.0)
	model.box(held_paper, Vector3(0, 0.0, -0.012), Vector3(0.3, 0.16, 0.005), Color("5f7f8a"), false, 0.0)

func place_camera() -> void:
	# Wide enough on a tall screen to take in the pod, the halo and the cover above it.
	var sway = sin(clock * 0.25) * 0.4
	camera.fov = 60.0 if size.y > size.x else 46.0
	camera.position = Vector3(sway, 2.4, -5.4)
	camera.look_at(Vector3(0.0, 2.1, 1.0))

func build_ui() -> void:
	var top = HBoxContainer.new()
	top.name = "Top"
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	top.add_child(UI.key(hud, "‹  TAÇA", false, func(): closed.emit(), 52))
	var title = UI.label(Press.KIOSK_NAME, 22, UI.GOLD, "display", false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	var bottom = VBoxContainer.new()
	bottom.name = "Bottom"
	bottom.add_theme_constant_override("separation", 10)
	add_child(bottom)
	var speech = PanelContainer.new()
	speech.add_theme_stylebox_override("panel", UI.panel_style(Color(0.03, 0.09, 0.11, 0.88), Color(Models.CYAN, 0.6), 16, 18))
	bottom.add_child(speech)
	var speech_box = VBoxContainer.new()
	speech.add_child(speech_box)
	speech_box.add_child(UI.label("ROSA  ·  BANCA DA TAÇA", 15, UI.GOLD, "display", false))
	bubble = UI.label("«%s»" % Press.kiosk_line(cup), 20, UI.WHITE, "italic")
	speech_box.add_child(bubble)
	var keys = HBoxContainer.new()
	keys.add_theme_constant_override("separation", 12)
	bottom.add_child(keys)
	var fresh = Press.has_new_edition(cup)
	keys.add_child(UI.key(hud, "LER A EDIÇÃO DE HOJE" + ("  •" if fresh else ""), true, func(): read.emit(Press.editions_available(cup) - 1), 76))
	var archive_key = UI.key(hud, "ARQUIVO", false, func(): archive.emit(), 76)
	archive_key.size_flags_stretch_ratio = 0.5
	keys.add_child(archive_key)
	resized.connect(arrange)
	arrange()
	call_deferred("arrange")

func arrange() -> void:
	var top: Control = get_node("Top")
	var bottom: Control = get_node("Bottom")
	var safe = 16.0
	if OS.has_feature("mobile"):
		var area = DisplayServer.get_display_safe_area()
		var screen = DisplayServer.screen_get_size()
		if screen.y > 0: safe += float(area.position.y) / screen.y * size.y
	var width = minf(size.x - 32, 760)
	top.position = Vector2((size.x - width) * 0.5, safe)
	top.size = Vector2(width, 52)
	bottom.size = Vector2(width, 0)
	bottom.size = Vector2(width, bottom.get_combined_minimum_size().y)
	bottom.position = Vector2((size.x - width) * 0.5, size.y - bottom.size.y - 24)

func _on_view_input(event: InputEvent) -> void:
	# Tap the scene and Rosa says something else about today.
	var tapped = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not tapped: return
	talk_index += 1
	var lines: Array = [Press.kiosk_line(cup)]
	var e: Dictionary = Press.edition(cup, Press.editions_available(cup) - 1)
	lines.append("Hoje a capa é \"%s\". Leva um, que esgota." % String(e.headline).capitalize())
	if cup.champion():
		lines.append("Campeão. Ainda não acredito que te vendi o primeiro jornal.")
	elif cup.entrance_passed:
		lines.append("%d pilotos ainda em prova. Eu aposto em ti - mas não digas a ninguém." % (1024 >> cup.wins))
	else:
		lines.append("A admissão é já ali. A Aurora não deixa passar quase ninguém.")
	bubble.text = "«%s»" % String(lines[talk_index % lines.size()])
	held_paper.position.y = 0.95

func _process(dt: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(dog): return
	clock += dt
	# Rosa idles: the head bobs, the tail wags, an ear flicks, the paper comes up.
	head.rotation.x = sin(clock * 1.6) * 0.06
	head.rotation.z = sin(clock * 0.9) * 0.08
	tail.rotation.y = sin(clock * 9.0) * 0.6
	for i in range(ears.size()):
		ears[i].rotation.x = -0.35 if sin(clock * 0.7 + i * 2.0) > 0.9 else 0.0
	var target_y = 0.95 if fmod(clock, 7.0) < 2.2 else 0.5
	held_paper.position.y = lerpf(held_paper.position.y, target_y, minf(1.0, dt * 4.0))
	# The pod lives: the halo turns, the drone hovers, the pages drift and turn.
	halo.rotation.y = clock * 0.25
	drone.position.y = 2.8 + sin(clock * 1.7) * 0.08
	drone.rotation.y = sin(clock * 0.6) * 0.4
	cover.position.y = 4.35 + sin(clock * 0.8) * 0.05
	for h in holograms:
		var node: Node3D = h.node
		node.position = h.base + Vector3(0, sin(clock * 0.9 + h.phase) * 0.08, 0)
		node.rotation.y += dt * 0.15
	place_camera()
