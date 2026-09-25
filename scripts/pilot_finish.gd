extends RefCounted
## Fitted equipment for the existing cast. All additions are cosmetic, attached to the
## animated body/legs/gun, and merged by material once when a pilot is constructed.
const ENAMEL = preload("res://shaders/pilot_enamel.gdshader")
const ENAMEL_LOW = preload("res://shaders/pilot_enamel_low.gdshader")
const INK = Color("142938")
const IVORY = Color("f3eee1")
const TITANIUM = Color("a9bdce")
const BRASS = Color("edbd6a")

static func apply(view, body: Node3D, skin: int, palette: Dictionary, team_color: Color) -> void:
	if body.has_node("Finish"):
		return
	var coat: Color = palette.body
	var glow: Color = palette.light
	var station = skin >= 100
	var style = posmod(skin - 100, 10) if station else skin
	var metal = TITANIUM if skin in [0, 4, 7] or station else BRASS
	var armor = IVORY if skin in [0, 1, 10, 11] else coat.lightened(0.14)
	var finish = _mount(body, "Finish")
	finish.set_meta("skin", skin)
	finish.set_meta("finish_revision", 1)
	# Broad, curved shells change the silhouette; small grooves are subordinate to it.
	for side in [-1, 1]:
		var origin = Vector3(side * 0.455, 0.935, 0.015)
		var wide = 1.12 if skin in [4, 5, 10, 11] else 1.0
		_shell(view, finish, origin + Vector3(0, -0.03, 0), Vector3(0.44 * wide, 0.20, 0.47), INK, 0)
		var guard = _shell(view, finish, origin + Vector3(side * 0.014, 0.038, 0), Vector3(0.43 * wide, 0.245, 0.45), armor, 0)
		guard.rotation.z = -side * 0.16
		# The forward lip follows the armour instead of floating above the shoulder.
		var lip = _plate(view, finish, origin + Vector3(0, 0.005, -0.217), Vector3(0.335 * wide, 0.055, 0.048), metal, 1)
		lip.rotation.z = -side * 0.16
		_disk(view, finish, Vector3(side * 0.60, 0.83, -0.025), 0.10, 0.046, INK, 0, Vector3(0, 0, PI * 0.5))
		_disk(view, finish, Vector3(side * 0.628, 0.83, -0.025), 0.067, 0.016, metal, 1, Vector3(0, 0, PI * 0.5))
		_plate(view, finish, Vector3(side * 0.475, 0.695, -0.245), Vector3(0.205, 0.22, 0.072), armor, 0).rotation.z = -side * 0.13
		_plate(view, finish, Vector3(side * 0.475, 0.72, -0.287), Vector3(0.102, 0.026, 0.017), glow, 2)
		var leg = body.get_node_or_null("LegL" if side == -1 else "LegR")
		if leg != null:
			var greave = _mount(leg, "Finish")
			_shell(view, greave, Vector3(0, -0.025, -0.093), Vector3(0.295, 0.245, 0.23), armor, 0)
			_plate(view, greave, Vector3(0, -0.085, -0.21), Vector3(0.20, 0.047, 0.06), metal, 1)
			_plate(view, greave, Vector3(0, -0.19, -0.305), Vector3(0.245, 0.063, 0.05), armor, 0)
			for stripe in [-1, 1]:
				_plate(view, greave, Vector3(stripe * 0.065, -0.195, -0.334), Vector3(0.033, 0.034, 0.012), INK, 0)
			_bake(greave)
	# Neck gasket and fitted cheek guards frame, but never replace, the existing eyes.
	_ring(view, finish, Vector3(0, 1.015, -0.015), 0.291, 0.019, metal, 1)
	if not station:
		# Aurel inherits the conical station helmet and its flat visor.
		if skin != 11:
			_visor_frame(view, finish, skin, metal)
		_signature(view, finish, skin, coat, glow, metal)
	else:
		_station_details(view, finish, style, team_color, glow, metal)
	_bake(finish)
	var gun = body.get_node_or_null("Gun")
	if gun != null:
		var weapon = _mount(gun, "Finish")
		_weapon(view, weapon, skin, coat, glow, metal)
		_bake(weapon)

static func _mount(parent: Node3D, label: String) -> Node3D:
	var node = Node3D.new()
	node.name = label
	parent.add_child(node)
	return node

static func _material(view, tint: Color, treatment: int) -> Material:
	var key = "pilot_finish_%s_%d" % [tint.to_html(), treatment]
	if not view.materials.has(key):
		var mat = ShaderMaterial.new()
		# Shader changes may reset uniforms; this immutable recipe restores every one.
		mat.set_meta("pilot_finish_parameters", {
			"paint_color": tint,
			"metal_amount": 0.80 if treatment == 1 else 0.20,
			"surface_roughness": 0.26 if treatment == 1 else 0.36,
			"light_amount": 1.6 if treatment == 2 else 0.0,
		})
		mat.set_meta("always_unshaded", treatment == 2)
		_configure_material(mat, view.quality_level)
		view.materials[key] = mat
	elif int(view.materials[key].get_meta("pilot_finish_quality", -1)) != clampi(view.quality_level, 0, 2):
		_configure_material(view.materials[key], view.quality_level)
	return view.materials[key]

static func set_quality(view, level: int) -> void:
	# Shared materials update gallery and gameplay meshes without rebuilding geometry.
	for mat in view.materials.values():
		if mat is ShaderMaterial and mat.has_meta("pilot_finish_parameters"):
			_configure_material(mat, level)

static func _configure_material(mat: ShaderMaterial, level: int) -> void:
	var quality = clampi(level, 0, 2)
	var desired = ENAMEL_LOW if quality == 0 else ENAMEL
	if mat.shader != desired:
		mat.shader = desired
	var parameters: Dictionary = mat.get_meta("pilot_finish_parameters")
	for key in parameters:
		if quality == 0 and key in ["metal_amount", "surface_roughness"]:
			continue
		mat.set_shader_parameter(key, parameters[key])
	mat.set_meta("pilot_finish_quality", quality)

static func _coat(view, node: MeshInstance3D, tint: Color, treatment: int) -> MeshInstance3D:
	node.material_override = _material(view, tint, treatment)
	return node

static func _plate(view, parent: Node3D, at: Vector3, size: Vector3, tint: Color, treatment: int = 0) -> MeshInstance3D:
	var shape = view.rounded_pilot_shape(size, minf(size.x, minf(size.y, size.z)) * 0.44)
	return _coat(view, view.mesh(parent, shape, at, tint), tint, treatment)

static func _orb(view, parent: Node3D, at: Vector3, size: Vector3, tint: Color, treatment: int = 0) -> MeshInstance3D:
	return _coat(view, view.sphere(parent, at, size, tint), tint, treatment)

static func _disk(view, parent: Node3D, at: Vector3, radius: float, depth: float, tint: Color, treatment: int = 0, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node = _coat(view, view.cylinder(parent, at, radius, depth, tint, false, 32), tint, treatment)
	node.rotation = rotation
	return node

static func _ring(view, parent: Node3D, at: Vector3, radius: float, thickness: float, tint: Color, treatment: int = 0, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key = "finish_ring_%s_%s" % [radius, thickness]
	if not view.shapes.has(key):
		var shape = TorusMesh.new()
		shape.inner_radius = radius - thickness
		shape.outer_radius = radius + thickness
		shape.rings = 40
		shape.ring_segments = 8
		view.shapes[key] = shape
	var node = _coat(view, view.mesh(parent, view.shapes[key], at, tint), tint, treatment)
	node.rotation = rotation
	return node

static func _rod(view, parent: Node3D, from: Vector3, to: Vector3, radius: float, tint: Color, treatment: int = 0) -> MeshInstance3D:
	var node = _disk(view, parent, (from + to) * 0.5, radius, from.distance_to(to), tint, treatment)
	var direction = (to - from).normalized()
	var axis = Vector3.UP.cross(direction)
	if axis.length_squared() > 0.00001:
		node.basis = Basis(axis.normalized(), acos(clampf(Vector3.UP.dot(direction), -1.0, 1.0)))
	elif direction.y < 0:
		node.rotation.x = PI
	return node

static func _shell(view, parent: Node3D, at: Vector3, size: Vector3, tint: Color, treatment: int) -> MeshInstance3D:
	# A crown with a rolled edge and tapered underside, rather than another box/sphere.
	const KEY = "pilot_finish_shell_v1"
	if not view.shapes.has(KEY):
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings = [Vector2(0.03, 0.5), Vector2(0.46, 0.44), Vector2(0.80, 0.25), Vector2(0.98, 0.0), Vector2(1.0, -0.27), Vector2(0.85, -0.47), Vector2(0.025, -0.5)]
		for row in range(rings.size() - 1):
			for spoke in range(32):
				for cell in [Vector2i(row, spoke), Vector2i(row + 1, spoke), Vector2i(row + 1, spoke + 1), Vector2i(row, spoke), Vector2i(row + 1, spoke + 1), Vector2i(row, spoke + 1)]:
					var angle = cell.y * TAU / 32.0
					var profile: Vector2 = rings[cell.x]
					st.add_vertex(Vector3(cos(angle) * profile.x * 0.5, profile.y, sin(angle) * profile.x * 0.5))
		st.generate_normals()
		view.shapes[KEY] = st.commit()
	var node = _coat(view, view.mesh(parent, view.shapes[KEY], at, tint), tint, treatment)
	node.scale = size
	return node

static func _visor_frame(view, parent: Node3D, skin: int, metal: Color) -> void:
	# The gardener's smaller helmet remains completely visible inside its glass dome.
	var gardener = skin == 3
	# Clear the curved helmet instead of intersecting it at the top of the rim.
	var center = Vector3(0, 1.255 if gardener else 1.285, -0.333 if gardener else -0.416)
	var ring = _ring(view, parent, center, 0.293 if gardener else 0.371, 0.011, metal, 1, Vector3(PI * 0.5, 0, 0))
	ring.scale.z = 0.40 if skin == 1 else 0.50
	for side in [-1, 1]:
		if gardener:
			continue
		var cheek = _plate(view, parent, Vector3(side * 0.287, 1.11, -0.307), Vector3(0.18, 0.105, 0.125), IVORY, 0)
		cheek.rotation.z = side * 0.30
		cheek.rotation.y = -side * 0.30
		_plate(view, parent, Vector3(side * 0.255, 1.112, -0.38), Vector3(0.08, 0.019, 0.025), INK, 0).rotation.z = side * 0.30

static func _signature(view, parent: Node3D, skin: int, coat: Color, glow: Color, metal: Color) -> void:
	match skin:
		0:
			# Aurora: a clean racing suit, broad shoulder panels and an open energy crest.
			for side in [-1, 1]:
				_plate(view, parent, Vector3(side * 0.20, 0.93, -0.262), Vector3(0.23, 0.095, 0.06), IVORY, 0).rotation.z = side * 0.27
				_plate(view, parent, Vector3(side * 0.47, 1.075, -0.01), Vector3(0.10, 0.024, 0.28), coat, 0)
			_ring(view, parent, Vector3(0, 0.68, -0.325), 0.105, 0.012, glow, 2, Vector3(PI * 0.5, 0, 0))
		1:
			# Brass ribbing turns each shoulder into a miniature beacon.
			for side in [-1, 1]:
				_disk(view, parent, Vector3(side * 0.475, 1.086, 0.015), 0.113, 0.045, metal, 1)
				_disk(view, parent, Vector3(side * 0.475, 1.115, 0.015), 0.083, 0.019, glow, 2)
				for offset in [-0.055, 0.055]:
					_plate(view, parent, Vector3(side * 0.475 + offset, 1.133, 0.015), Vector3(0.017, 0.018, 0.175), metal, 1)
				_plate(view, parent, Vector3(side * 0.24, 0.63, -0.269), Vector3(0.032, 0.25, 0.037), metal, 1)
		2:
			for side in [-1, 1]:
				var orbit = _ring(view, parent, Vector3(side * 0.49, 1.046, -0.01), 0.14, 0.012, metal, 1)
				orbit.rotation.z = side * 0.35
				_orb(view, parent, Vector3(side * 0.54, 1.068, -0.11), Vector3.ONE * 0.055, glow, 2)
				for star in range(3):
					_plate(view, parent, Vector3(side * (0.11 + star * 0.06), 0.56 + star * 0.055, -0.281), Vector3(0.038, 0.038, 0.018), glow, 2).rotation.z = PI * 0.25
		3:
			for side in [-1, 1]:
				for tier in range(2):
					var leaf = _orb(view, parent, Vector3(side * (0.45 + tier * 0.045), 1.045 - tier * 0.075, -0.025), Vector3(0.41, 0.09, 0.31), Color("93c878").darkened(tier * 0.13), 0)
					leaf.rotation.z = -side * 0.35
				_rod(view, parent, Vector3(side * 0.32, 1.09, -0.03), Vector3(side * 0.64, 0.98, -0.03), 0.012, glow, 2)
		4:
			for side in [-1, 1]:
				for rivet in [-1, 1]:
					_disk(view, parent, Vector3(side * 0.48 + rivet * 0.105, 0.986, -0.224), 0.027, 0.019, metal, 1, Vector3(PI * 0.5, 0, 0))
				for stripe in range(3):
					_plate(view, parent, Vector3(side * 0.49, 1.071, -0.09 + stripe * 0.078), Vector3(0.21, 0.018, 0.034), glow if stripe == 1 else INK, 2 if stripe == 1 else 0).rotation.z = -side * 0.16
		5:
			for side in [-1, 1]:
				for tier in range(2):
					var wing = _shell(view, parent, Vector3(side * (0.52 + tier * 0.055), 1.012 - tier * 0.105, 0.05), Vector3(0.43 - tier * 0.05, 0.145, 0.48), coat, 0)
					wing.rotation.z = -side * 0.27
				_plate(view, parent, Vector3(side * 0.555, 0.995, -0.187), Vector3(0.24, 0.024, 0.026), metal, 1).rotation.z = -side * 0.27
				_rod(view, parent, Vector3(side * 0.275, 0.965, 0.346), Vector3(side * 0.285, 0.26, 0.395), 0.014, metal, 1)
		6:
			for side in [-1, 1]:
				_gear(view, parent, Vector3(side * 0.49, 1.065, -0.015), 0.12, metal)
				_disk(view, parent, Vector3(side * 0.49, 1.096, -0.015), 0.055, 0.02, glow, 2)
				_plate(view, parent, Vector3(side * 0.25, 0.73, -0.267), Vector3(0.035, 0.35, 0.04), metal, 1).rotation.z = side * 0.1
		7:
			for side in [-1, 1]:
				for fin in range(3):
					var rib = _plate(view, parent, Vector3(side * (0.38 + fin * 0.095), 1.11 - fin * 0.022, 0.04), Vector3(0.045, 0.14, 0.34), metal, 1)
					rib.rotation.z = -side * 0.2
				_rod(view, parent, Vector3(side * 0.35, 1.1, -0.15), Vector3(side * 0.61, 1.04, -0.15), 0.019, glow, 2)
		8:
			for side in [-1, 1]:
				_ring(view, parent, Vector3(side * 0.465, 1.07, 0.0), 0.115, 0.025, Color("de9860"), 1)
				for vial in range(2):
					var at = Vector3(side * (0.47 + vial * 0.10), 0.918, -0.245)
					_disk(view, parent, at, 0.026, 0.14, glow, 2)
					_disk(view, parent, at + Vector3.UP * 0.077, 0.033, 0.027, metal, 1)
		9:
			for side in [-1, 1]:
				for fringe in range(4):
					var x = side * (0.35 + fringe * 0.075)
					_rod(view, parent, Vector3(x, 0.973, -0.205), Vector3(x + side * 0.018, 0.83 - absf(fringe - 1.5) * 0.012, -0.205), 0.014, metal, 1)
				var tail = _plate(view, parent, Vector3(side * 0.265, 0.38, 0.17), Vector3(0.23, 0.45, 0.13), coat, 0)
				tail.rotation.z = side * 0.16
				_plate(view, parent, Vector3(side * 0.27, 0.78, -0.287), Vector3(0.023, 0.32, 0.031), metal, 1).rotation.z = side * 0.14
		10, 11:
			for side in [-1, 1]:
				for tier in range(3):
					var wing = _shell(view, parent, Vector3(side * (0.44 + tier * 0.085), 1.00 - tier * 0.078, 0.035), Vector3(0.43 - tier * 0.065, 0.155, 0.47), metal if tier % 2 == 0 else IVORY, 1 if tier % 2 == 0 else 0)
					wing.rotation.z = -side * 0.3
				_plate(view, parent, Vector3(side * 0.21, 0.74, -0.277), Vector3(0.052, 0.35, 0.038), metal, 1).rotation.z = side * 0.20
				_orb(view, parent, Vector3(side * 0.56, 1.075, -0.01), Vector3(0.10, 0.10, 0.10), glow, 2)

static func _station_details(view, parent: Node3D, style: int, color: Color, glow: Color, metal: Color) -> void:
	for side in [-1, 1]:
		if style % 3 == 0:
			_disk(view, parent, Vector3(side * 0.49, 1.075, 0), 0.09, 0.04, glow, 2)
		elif style % 3 == 1:
			_plate(view, parent, Vector3(side * 0.49, 1.07, 0), Vector3(0.09, 0.025, 0.29), color, 0)
		else:
			for tooth in range(2):
				_plate(view, parent, Vector3(side * (0.41 + tooth * 0.13), 1.10, 0.025), Vector3(0.034, 0.105, 0.27), metal, 1)
		_plate(view, parent, Vector3(side * 0.225, 0.68, -0.27), Vector3(0.055, 0.20, 0.025), color, 0)

static func _gear(view, parent: Node3D, at: Vector3, radius: float, tint: Color) -> void:
	_disk(view, parent, at, radius, 0.034, tint, 1)
	for tooth in range(10):
		var angle = tooth * TAU / 10.0
		var block = _plate(view, parent, at + Vector3(cos(angle), 0, sin(angle)) * radius, Vector3(radius * 0.43, 0.041, radius * 0.32), tint, 1)
		block.rotation.y = -angle

static func _weapon(view, parent: Node3D, skin: int, coat: Color, glow: Color, metal: Color) -> void:
	var shell = IVORY if skin in [0, 1, 2, 5, 10, 11] else coat.lightened(0.13)
	var forward = Vector3(PI * 0.5, 0, 0)
	# Fitted receiver plates, trigger housing, hand grip and three recessed indicators.
	# The muzzle/flash and shared recoil origin remain exactly where the simulation puts them.
	for side in [-1, 1]:
		_plate(view, parent, Vector3(0.29 + side * 0.155, 0.7, -0.385), Vector3(0.065, 0.24, 0.33), shell, 0)
		_plate(view, parent, Vector3(0.29 + side * 0.193, 0.72, -0.415), Vector3(0.018, 0.044, 0.18), glow, 2)
	_plate(view, parent, Vector3(0.29, 0.855, -0.37), Vector3(0.22, 0.043, 0.25), metal, 1)
	_plate(view, parent, Vector3(0.29, 0.544, -0.285), Vector3(0.18, 0.155, 0.15), INK, 0).rotation.x = -0.17
	for groove in range(3):
		_plate(view, parent, Vector3(0.39, 0.51 + groove * 0.04, -0.285), Vector3(0.014, 0.012, 0.12), metal, 1)
	match skin:
		0, 11:
			_ring(view, parent, Vector3(0.29, 0.7, -0.805), 0.142, 0.021, metal, 1, forward)
			for side in [-1, 1]:
				_plate(view, parent, Vector3(0.29 + side * 0.13, 0.78, -0.64), Vector3(0.055, 0.07, 0.25), shell, 0)
		1:
			for side in [-1, 1]:
				_rod(view, parent, Vector3(0.29 + side * 0.11, 0.7, -0.5), Vector3(0.29 + side * 0.075, 0.7, -0.88), 0.024, metal, 1)
			_ring(view, parent, Vector3(0.29, 0.7, -0.9), 0.12, 0.018, metal, 1, forward)
			_plate(view, parent, Vector3(0.29, 0.91, -0.35), Vector3(0.06, 0.075, 0.11), INK, 0)
		2:
			_ring(view, parent, Vector3(0.29, 0.7, -0.665), 0.231, 0.015, metal, 1, forward)
			for side in [-1, 1]:
				_rod(view, parent, Vector3(0.29 + side * 0.14, 0.7, -0.48), Vector3(0.29 + side * 0.22, 0.7, -0.67), 0.025, metal, 1)
				_orb(view, parent, Vector3(0.29 + side * 0.22, 0.7, -0.67), Vector3.ONE * 0.06, glow, 2)
		3:
			for side in [-1, 1]:
				var petal = _orb(view, parent, Vector3(0.29 + side * 0.08, 0.76, -0.67), Vector3(0.08, 0.14, 0.31), coat.lightened(0.22), 0)
				petal.rotation.z = side * 0.40
			_ring(view, parent, Vector3(0.29, 0.79, -0.875), 0.092, 0.019, metal, 1, forward)
		4:
			_ring(view, parent, Vector3(0.29, 0.7, -0.60), 0.163, 0.027, metal, 1, forward)
			for tooth in range(6):
				var angle = tooth * TAU / 6.0
				_plate(view, parent, Vector3(0.29 + cos(angle) * 0.16, 0.7 + sin(angle) * 0.16, -0.6), Vector3(0.045, 0.045, 0.09), INK, 0).rotation.z = angle
			for side in [-1, 1]:
				_plate(view, parent, Vector3(0.29 + side * 0.195, 0.79, -0.38), Vector3(0.02, 0.065, 0.10), glow, 2)
		5:
			for side in [-1, 1]:
				var rail = _plate(view, parent, Vector3(0.29 + side * 0.07, 0.7, -0.735), Vector3(0.045, 0.11, 0.43), metal, 1)
				rail.rotation.y = side * 0.085
			_ring(view, parent, Vector3(0.29, 0.7, -1.015), 0.153, 0.014, metal, 1, forward)
		6:
			var disk = _gear_mount(parent, Vector3(0.49, 0.7, -0.375), Vector3(0, 0, PI * 0.5))
			_gear(view, disk, Vector3.ZERO, 0.087, metal)
			_flatten(disk, parent)
			for side in [-1, 1]:
				_rod(view, parent, Vector3(0.29 + side * 0.12, 0.7, -0.5), Vector3(0.29 + side * 0.12, 0.7, -0.81), 0.018, metal, 1)
			_ring(view, parent, Vector3(0.29, 0.7, -0.875), 0.111, 0.018, metal, 1, forward)
		7:
			for side in [-1, 1]:
				_rod(view, parent, Vector3(0.29 + side * 0.13, 0.7, -0.48), Vector3(0.29 + side * 0.10, 0.7, -0.90), 0.029, metal, 1)
				_orb(view, parent, Vector3(0.29 + side * 0.10, 0.7, -0.9), Vector3.ONE * 0.078, glow, 2)
			for z in [-0.57, -0.69]:
				_ring(view, parent, Vector3(0.29, 0.7, z), 0.119, 0.012, glow, 2, forward)
		8:
			for side in [-1, 1]:
				_rod(view, parent, Vector3(0.29 + side * 0.10, 0.7, -0.54), Vector3(0.29 + side * 0.175, 0.7, -0.74), 0.017, metal, 1)
				_rod(view, parent, Vector3(0.29 + side * 0.175, 0.7, -0.74), Vector3(0.29 + side * 0.065, 0.7, -0.92), 0.017, metal, 1)
			_ring(view, parent, Vector3(0.29, 0.7, -0.75), 0.168, 0.015, metal, 1, forward)
		9:
			for z in [-0.54, -0.75]:
				_ring(view, parent, Vector3(0.29, 0.7, z), 0.078, 0.02, metal, 1, forward)
			_ring(view, parent, Vector3(0.29, 0.7, -1.029), 0.137, 0.017, metal, 1, forward)
			_plate(view, parent, Vector3(0.29, 0.80, -0.62), Vector3(0.045, 0.035, 0.39), metal, 1)
		10:
			_ring(view, parent, Vector3(0.29, 0.7, -1.0), 0.205, 0.016, metal, 1, forward)
			for ray in range(4):
				var angle = ray * TAU / 4.0
				var jewel = _plate(view, parent, Vector3(0.29 + cos(angle) * 0.205, 0.7 + sin(angle) * 0.205, -1.0), Vector3(0.085, 0.045, 0.045), glow, 2)
				jewel.rotation.z = angle
		_:
			_ring(view, parent, Vector3(0.30, 0.7, -0.8), 0.125, 0.016, metal, 1, forward)
			_plate(view, parent, Vector3(0.30, 0.84, -0.60), Vector3(0.10, 0.035, 0.3), glow, 2)

static func _gear_mount(parent: Node3D, at: Vector3, rotation: Vector3) -> Node3D:
	var mount = _mount(parent, "GearMount")
	mount.position = at
	mount.rotation = rotation
	return mount

static func _flatten(branch: Node3D, parent: Node3D) -> void:
	for child in branch.get_children():
		var pose = branch.transform * child.transform
		branch.remove_child(child)
		parent.add_child(child)
		child.transform = pose
	branch.free()

static func _bake(parent: Node3D) -> void:
	# One draw per material per animated attachment, rather than one per rivet.
	var surfaces: Dictionary = {}
	var count = 0
	for child in parent.get_children():
		if not child is MeshInstance3D:
			continue
		var mat: Material = child.material_override
		var key = mat.get_instance_id()
		if not surfaces.has(key):
			var builder = SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[key] = {"builder": builder, "material": mat}
		for index in range(child.mesh.get_surface_count()):
			surfaces[key].builder.append_from(child.mesh, index, child.transform)
		count += 1
		child.free()
	for key in surfaces:
		var batch = MeshInstance3D.new()
		batch.name = "Surface%d" % parent.get_child_count()
		batch.mesh = surfaces[key].builder.commit()
		batch.material_override = surfaces[key].material
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(batch)
	parent.set_meta("authored_pieces", count)
	parent.set_meta("draw_surfaces", surfaces.size())
