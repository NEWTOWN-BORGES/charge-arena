extends Node3D
## Lightweight procedural 3D art: no downloads, external assets or plug-ins.
const CYAN = Color("42e4ef")
const CORAL = Color("ff758d")
const LIME = Color("c9fa75")
var units: Array = []
var brick_nodes: Array = []
var goals: Array = []
var projectiles: Dictionary = {}
var effects: Array = []
var aim_line: MeshInstance3D
var camera: Camera3D
var ring: MeshInstance3D
var materials: Dictionary = {}

func material(color: Color, luminous: bool = false) -> StandardMaterial3D:
	var key = str(color) + str(luminous)
	if materials.has(key):
		return materials[key]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	mat.metallic = 0.25 if not luminous else 0.0
	if luminous:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials[key] = mat
	return mat

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color, luminous: bool = false) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material(color, luminous)
	if luminous:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = pos
	parent.add_child(node)
	return node

func box(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color, luminous: bool = false) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = dimensions
	return mesh(parent, shape, pos, color, luminous)

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, luminous: bool = false) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 32
	return mesh(parent, shape, pos, color, luminous)

func torus(parent: Node3D, pos: Vector3, radius: float, thickness: float, color: Color) -> MeshInstance3D:
	var shape = TorusMesh.new()
	shape.inner_radius = radius - thickness
	shape.outer_radius = radius + thickness
	shape.rings = 48
	shape.ring_segments = 8
	return mesh(parent, shape, pos, color, true)

func segment(parent: Node3D, a: Vector3, b: Vector3, width: float, height: float, color: Color, luminous: bool = false) -> MeshInstance3D:
	var node = box(parent, (a + b) * 0.5, Vector3(a.distance_to(b), height, width), color, luminous)
	node.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	return node

func build() -> void:
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("070d1a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("8ca5d1")
	environment.environment.ambient_light_energy = 0.75
	add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -30, 0)
	light.light_color = Color("d1e6ff")
	light.light_energy = 1.6
	light.shadow_enabled = true
	add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 21.5
	camera.position = Vector3(0, 23, 15)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var outline = preload("res://scripts/arena_rules.gd").WALLS
	# Solid octagonal floor, constructed as a triangle fan.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		for v in [Vector2.ZERO, outline[i], outline[(i + 1) % outline.size()]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, -0.04, v.y))
	mesh(self, st.commit(), Vector3.ZERO, Color("172a40"))
	for i in range(outline.size()):
		var a = Vector3(outline[i].x, 0.03, outline[i].y)
		var b = Vector3(outline[(i + 1) % outline.size()].x, 0.03, outline[(i + 1) % outline.size()].y)
		segment(self, a, b, 0.55, 0.7, Color("233956"))
		segment(self, a + Vector3.UP * 0.38, b + Vector3.UP * 0.38, 0.055, 0.025, CYAN if i < 4 else CORAL, true)
		segment(self, a * 1.06 - Vector3.UP * 0.3, b * 1.06 - Vector3.UP * 0.3, 0.4, 0.35, Color("0c192b"))
	# Floor seams and center court markings.
	for x in range(-4, 5):
		segment(self, Vector3(x, 0.002, -6.7), Vector3(x, 0.002, 6.7), 0.012, 0.008, Color("243b50"), true)
	for z in range(-6, 7):
		segment(self, Vector3(-5.1, 0.003, z), Vector3(5.1, 0.003, z), 0.012, 0.008, Color("243b50"), true)
	for x in range(-10, 11):
		box(self, Vector3(x * 0.46, 0.015, 0), Vector3(0.18, 0.015, 0.045), Color("7293a4"), true)
	cylinder(self, Vector3(0, 0.018, 0), 2.25, 0.025, Color("101f33"))
	torus(self, Vector3(0, 0.045, 0), 2.2, 0.028, Color("4d7687"))
	torus(self, Vector3(0, 0.05, 0), 1.92, 0.012, Color("324b61"))
	var bolt = [Vector3(0.4, 0.07, -1.2), Vector3(-0.55, 0.07, 0.1), Vector3(0.45, 0.07, 0.1), Vector3(-0.4, 0.07, 1.2)]
	for i in range(bolt.size() - 1):
		segment(self, bolt[i], bolt[i + 1], 0.18, 0.015, Color("83a8b8"), true)
	for team in range(2):
		var color = CYAN if team == 0 else CORAL
		var sign_z = 1 if team == 0 else -1
		box(self, Vector3(0, 0.035, 7.75 * sign_z), Vector3(6.6, 0.045, 1.3), Color(color, 0.1), true)
		var gate = box(self, Vector3(0, 0.42, 8.25 * sign_z), Vector3(6.65, 0.8, 0.07), Color(color, 0.21), true)
		goals.append(gate)
		for x in [-3.5, 3.5]:
			box(self, Vector3(x, 0.6, 8.25 * sign_z), Vector3(0.16, 1.2, 0.32), color, true)
		box(self, Vector3(0, 1.2, 8.25 * sign_z), Vector3(7.15, 0.13, 0.18), color, true)
		for i in range(7):
			var brick = Node3D.new()
			add_child(brick)
			brick.position = Vector3((i - 3) * 0.94, 0, 7.15 * sign_z)
			box(brick, Vector3(0, 0.31, 0), Vector3(0.82, 0.62, 0.45), color)
			box(brick, Vector3(0, 0.63, 0), Vector3(0.72, 0.025, 0.36), color.lightened(0.3), true)
			box(brick, Vector3(0, 0.32, -0.232 * sign_z), Vector3(0.58, 0.06, 0.025), Color("ffffff"), true)
			brick_nodes.append(brick)
		units.append(build_player(color))
	for z in [-5.5, -3.6, 3.6, 5.5]:
		for x in [-5.18, 5.18]:
			box(self, Vector3(x, 0.43, z), Vector3(0.13, 0.035, 0.7), CYAN if z > 0 else CORAL, true)
	aim_line = box(self, Vector3.ZERO, Vector3(0.026, 0.015, 2.1), Color(CYAN, 0.38), true)

func build_player(color: Color) -> Node3D:
	var root = Node3D.new()
	add_child(root)
	cylinder(root, Vector3(0, 0.045, 0), 0.5, 0.025, Color(color, 0.13), true)
	torus(root, Vector3(0, 0.07, 0), 0.47, 0.025, color)
	var body = Node3D.new()
	root.add_child(body)
	body.name = "Body"
	for x in [-0.16, 0.16]:
		box(body, Vector3(x, 0.18, 0), Vector3(0.21, 0.3, 0.31), Color("19283a"))
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.27
	capsule.height = 0.64
	mesh(body, capsule, Vector3(0, 0.62, 0), color)
	var helmet = SphereMesh.new()
	helmet.radius = 0.29
	helmet.height = 0.48
	mesh(body, helmet, Vector3(0, 1.09, -0.035), Color("dbe8ec"))
	box(body, Vector3(0, 1.1, -0.27), Vector3(0.38, 0.13, 0.065), Color("0a1727"))
	box(body, Vector3(0, 1.11, -0.31), Vector3(0.24, 0.035, 0.015), color, true)
	for x in [-0.35, 0.35]:
		box(body, Vector3(x, 0.76, -0.025), Vector3(0.19, 0.23, 0.27), color.darkened(0.1))
	box(body, Vector3(0.28, 0.65, -0.37), Vector3(0.22, 0.22, 0.49), Color("243c55"))
	box(body, Vector3(0.28, 0.65, -0.63), Vector3(0.14, 0.14, 0.06), color, true)
	var halo = torus(root, Vector3(0, 1.52, 0), 0.43, 0.035, LIME)
	halo.name = "Stun"
	halo.visible = false
	return root

func update_state(rules, local_team: int, dt: float) -> void:
	for team in range(2):
		var data: Dictionary = rules.players[team]
		var node: Node3D = units[team]
		var desired = Vector3(data.p.x, 0, data.p.y)
		node.position = node.position.lerp(desired, minf(dt * 24, 1))
		node.get_node("Body").rotation.y = atan2(-data.aim.x, -data.aim.y)
		var halo: Node3D = node.get_node("Stun")
		halo.visible = data.stun > 0
		halo.rotation.z = sin(rules.elapsed * 8) * 0.2
		halo.scale = Vector3.ONE * (1.0 + sin(rules.elapsed * 12) * 0.08)
		goals[team].material_override = material(Color(LIME if rules.brick_count(team) == 0 else (CYAN if team == 0 else CORAL), 0.25), true)
	for i in range(rules.bricks.size()):
		if brick_nodes[i].visible and not rules.bricks[i].alive:
			burst(rules.bricks[i].p, CYAN if rules.bricks[i].team == 0 else CORAL)
		brick_nodes[i].visible = rules.bricks[i].alive
	var active: Array = []
	for ball in rules.balls:
		active.append(ball.id)
		if not projectiles.has(ball.id):
			var color = CYAN if ball.owner == 0 else CORAL
			var root = Node3D.new()
			add_child(root)
			var sphere = SphereMesh.new()
			sphere.radius = 0.16
			sphere.height = 0.32
			mesh(root, sphere, Vector3.ZERO, color.lightened(0.35), true)
			box(root, Vector3(0, 0, 0.3), Vector3(0.09, 0.09, 0.5), Color(color, 0.6), true)
			projectiles[ball.id] = root
		var node: Node3D = projectiles[ball.id]
		node.position = Vector3(ball.p.x, 0.58, ball.p.y)
		node.rotation.y = atan2(-ball.v.x, -ball.v.y)
	for id in projectiles.keys():
		if not active.has(id):
			projectiles[id].queue_free()
			projectiles.erase(id)
	var player: Dictionary = rules.players[local_team]
	aim_line.visible = rules.phase == "play" and player.stun <= 0
	aim_line.position = Vector3(player.p.x + player.aim.x * 1.7, 0.08, player.p.y + player.aim.y * 1.7)
	aim_line.rotation.y = atan2(player.aim.x, player.aim.y)
	for effect in effects.duplicate():
		effect.ttl -= dt
		effect.node.position += effect.v * dt
		effect.node.scale = Vector3.ONE * maxf(effect.ttl * 1.6, 0.01)
		if effect.ttl <= 0:
			effect.node.queue_free()
			effects.erase(effect)

func burst(pos: Vector2, color: Color) -> void:
	for i in range(7):
		var node = box(self, Vector3(pos.x, 0.5, pos.y), Vector3.ONE * 0.15, color, true)
		var angle = float(i) / 7 * TAU
		effects.append({"node": node, "v": Vector3(cos(angle) * 2, 1.1, sin(angle) * 2), "ttl": 0.6})

func world_at(screen: Vector2) -> Vector2:
	var point = Plane(Vector3.UP, 0.58).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	return Vector2(point.x, point.z) if point != null else Vector2.ZERO
