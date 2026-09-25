extends RefCounted
## Analytic, pooled shock fronts. Every card shares the arena's existing effect
## limit; particles and lamps still use its prewarmed 2.9.5 pools.
const Rules = preload("res://scripts/arena_rules.gd")
const FRONT = preload("res://shaders/combat_front.gdshader")
const ECLIPSE = preload("res://shaders/combat_eclipse.gdshader")
const POOL_SIZE = 28
const META = "combat_finish_pool"

static func prepare(view) -> void:
	if view.has_meta(META): return
	var pool: Array[MeshInstance3D] = []
	var quad = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	for i in range(POOL_SIZE):
		var card = MeshInstance3D.new()
		card.mesh = quad
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.ignore_occlusion_culling = true
		var front = ShaderMaterial.new()
		front.shader = FRONT
		var eclipse = ShaderMaterial.new()
		eclipse.shader = ECLIPSE
		card.set_meta("front", front)
		card.set_meta("eclipse", eclipse)
		card.material_override = front
		card.hide()
		view.add_child(card)
		pool.append(card)
	view.set_meta(META, pool)
	view.set_meta("combat_finish_last", {})
	# The two shader variants draw transparently during arena preparation, so the
	# first actual ultimate does not also have to compile its render pipeline.
	for is_void in [false, true]:
		var card: MeshInstance3D = pool.pop_back()
		card.material_override = card.get_meta("eclipse" if is_void else "front")
		card.material_override.set_shader_parameter("age", 1.0)
		card.position = Vector3(0, 1, 0)
		card.rotation.x = -PI * 0.5
		card.show()
		view.effects.append({"node": card, "v": Vector3.ZERO, "ttl": 0.1, "life": 0.1, "gravity": false, "base": Vector3.ONE, "keep": true, "combat_finish": true, "warm": true})

static func animate(effect: Dictionary, remaining: float) -> void:
	var material: ShaderMaterial = effect.node.material_override
	material.set_shader_parameter("age", 1.0 if effect.get("warm", false) else 1.0 - remaining)

static func recycle(view, card: MeshInstance3D) -> void:
	card.hide()
	var pool: Array = view.get_meta(META)
	pool.append(card)

static func active_count(view) -> int:
	return POOL_SIZE - (view.get_meta(META) as Array).size() if view.has_meta(META) else 0

static func card(view, at: Vector2, radius: float, tint: Color, life: float, motif: int = 0, billboard: bool = false, height: float = 0.09) -> MeshInstance3D:
	if not view.has_meta(META): prepare(view)
	var pool: Array = view.get_meta(META)
	if pool.is_empty() or view.effects.size() >= view.effect_limit or active_count(view) >= [8, 18, 28][view.quality_level]: return null
	var node: MeshInstance3D = pool.pop_back()
	node.position = Vector3(at.x, height, at.y)
	node.basis = view.camera.global_basis if billboard else Basis(Vector3.RIGHT, -PI * 0.5)
	node.scale = Vector3.ONE * radius
	var material: ShaderMaterial = node.get_meta("eclipse" if motif == 4 else "front")
	node.material_override = material
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("age", 0.0)
	material.set_shader_parameter("seed", fmod(at.x * 1.73 + at.y * 2.13, TAU))
	if motif != 4:
		material.set_shader_parameter("motif", float(motif))
		material.set_shader_parameter("hot", tint.lerp(Color("fff4dc"), 0.83))
	node.show()
	view.effects.append({"node": node, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": node.scale, "keep": true, "combat_finish": true})
	return node

static func impact(view, at: Vector2, radius: float, tint: Color, motif: int = 1, life: float = 0.48) -> void:
	card(view, at, radius, tint, life, motif)
	if view.quality_level > 0:
		card(view, at, minf(radius * 0.66, 1.2), tint, 0.19, 6, true, 0.44)

static func beam(view, at: Vector2, heading: Vector2, length_value: float, width: float, tint: Color) -> void:
	if length_value < 0.05: return
	var middle = at + heading * length_value * 0.5
	var node = card(view, middle, 1.0, tint, 0.17, 5, false, 0.62)
	if node == null: return
	# Local X spans the beam; local Y follows its path on the arena floor.
	var direction = Vector3(heading.x, 0, heading.y).normalized()
	node.basis = Basis(Vector3(direction.z, 0, -direction.x), direction, Vector3.UP)
	node.scale = Vector3(width, length_value * 0.5, 1.0)

static func wall_center(event_data: Dictionary, rules) -> Vector2:
	var result: Vector2 = event_data.get("p", Vector2.ZERO)
	if rules == null or not event_data.has("bricks") or event_data.bricks.is_empty(): return result
	result = Vector2.ZERO
	for index in event_data.bricks: result += Vector2(rules.bricks[int(index)].p)
	return result / float(event_data.bricks.size())

static func motif_for(id: String) -> int:
	if id in ["thunder", "shock", "shock_wave", "surge", "magnet", "laser"]: return 2
	if id in ["bloom", "weld", "rebuild", "thorns"]: return 3
	if id in ["singularity", "swallow"]: return 4
	if id in ["meteors", "blast", "sun_ray"]: return 1
	return 0

static func event(view, data: Dictionary, rules = null) -> void:
	if not data.has("p"): return
	if not view.has_meta(META): prepare(view)
	var kind = String(data.get("kind", ""))
	var at: Vector2 = data.p
	var team = clampi(int(data.get("team", 0)), 0, 1)
	var tint: Color = view.shot_colors[team]
	var id = String(data.get("id", kind))
	# A machine gun or a mass heal must not turn every brick into a new full-screen
	# effect. Essential gameplay feedback continues through the original callbacks.
	var last: Dictionary = view.get_meta("combat_finish_last")
	var key = kind + str(team)
	var spacing = 0.08 if kind in ["brick_hit", "brick", "bounce", "spent", "laser"] else 0.035
	var now: float = view.clock
	if now - float(last.get(key, -100.0)) < spacing: return
	last[key] = now
	match kind:
		"brick", "brick_hit", "player_hit", "mirror":
			card(view, at, 0.69 if kind == "brick" else 0.42, tint, 0.28 if kind == "brick" else 0.18)
			if kind == "brick" and view.quality_level > 0:
				card(view, at, 0.45, tint, 0.14, 6, true, 0.55)
		"boost":
			impact(view, at, 0.8, Color("ffce63"), 2, 0.28)
			view.flash(Vector3(at.x, 0.7, at.y), Color("ffd175"), 2.3, 0.13, 3.2)
		"explosion":
			impact(view, at, float(data.get("radius", 1.2)) * 1.05, Color("ff843c"), 1)
		"meteor":
			var radius = float(data.get("radius", 1.2)) * 1.7
			view.schedule(0.34, func(): impact(view, at, radius, Color("ffad53"), 1, 0.6))
		"thunder":
			var radius = float(data.get("radius", 1.0)) * 1.7
			view.schedule(0.16, func(): impact(view, at, radius, Color("72cfff"), 2, 0.46))
		"bloom", "weld", "rebuild":
			var middle = wall_center(data, rules)
			card(view, middle, 3.0 if kind == "bloom" else 1.75, Color("a8ff8d"), 0.85, 3)
		"singularity":
			card(view, at, 2.0, Color("bb94ff"), minf(float(data.get("seconds", 1.2)), 1.6), 4)
		"singularity_wave", "swallow":
			impact(view, at, 2.3, Color("c5a1ff"), 2, 0.55)
		"laser":
			var path: Array = data.get("path", [])
			if path.size() >= 2:
				for i in range(mini(path.size() - 1, 3)):
					var a: Vector2 = path[i]
					var b: Vector2 = path[i + 1]
					beam(view, a, a.direction_to(b), a.distance_to(b), 0.5, Color("79eaff"))
			else:
				beam(view, at, data.get("heading", Vector2.UP), float(data.get("length", 8.0)), 0.5, Color("79eaff"))
		"sun_ray":
			impact(view, at + Vector2(data.get("heading", Vector2.UP)) * 0.9, 1.2, Color("ffcc63"), 1, 0.34)
		"ultimate":
			var color = Rules.power_color(id)
			card(view, at, 1.6, color, 0.55, motif_for(id))
		"power":
			card(view, at, 0.95, Rules.power_color(id), 0.34, motif_for(id))
		"plunder_land":
			card(view, at, 1.85, Color("76f6dd"), 0.58, 0)
		"freeze":
			card(view, at, 1.85, Color("a4eaff"), 0.6, 2)
		"shock_wave", "shock":
			card(view, at, 2.2, Color("b2a0ff"), 0.48, 2)
