extends RefCounted
## Shared surface treatment. Tiny repeatable maps, no runtime texture generation.
const SURFACES = {
	"ceramic": [preload("res://art/materials/ceramic_albedo.png"), preload("res://art/materials/ceramic_roughness.png"), preload("res://art/materials/ceramic_normal.png")],
	"alloy": [preload("res://art/materials/alloy_albedo.png"), preload("res://art/materials/alloy_roughness.png"), preload("res://art/materials/alloy_normal.png")],
	"graphite": [preload("res://art/materials/graphite_albedo.png"), preload("res://art/materials/graphite_roughness.png"), preload("res://art/materials/graphite_normal.png")]
}
static var studio_sky: Sky

static func environment(env: Environment, quality: int) -> void:
	if studio_sky == null:
		studio_sky = Sky.new()
		studio_sky.radiance_size = Sky.RADIANCE_SIZE_128
		var sky = ProceduralSkyMaterial.new()
		sky.sky_top_color = Color("20364f")
		sky.sky_horizon_color = Color("c5e4e5")
		sky.ground_bottom_color = Color("182a34")
		sky.ground_horizon_color = Color("bda586")
		studio_sky.sky_material = sky
	env.sky = studio_sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.42 if quality < 2 else 0.5
	env.ambient_light_color = Color("91b5c5")
	# Refinado is the showcase: ACES for rich, saturated highlights, a wide soft bloom so
	# anything that emits light actually glows, and stronger colour grading. The lighter
	# profiles keep the old, cheaper look.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES if quality == 2 else Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08 if quality == 2 else 1.12
	env.tonemap_white = 4.0 if quality == 2 else 1.0
	env.glow_enabled = quality == 2
	env.glow_normalized = false
	env.glow_intensity = 0.95 if quality == 2 else 0.5
	env.glow_strength = 1.05
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN if quality == 2 else Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.75 if quality == 2 else 1.12
	env.glow_hdr_scale = 2.2 if quality == 2 else 1.1
	env.glow_hdr_luminance_cap = 16.0
	# Mid levels carry the wide halo; level 1 keeps a tight core on small lights.
	var levels = [0.6, 0.9, 1.0, 0.85, 0.6, 0.0, 0.0] if quality == 2 else [0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0]
	for i in range(7):
		env.set_glow_level(i, levels[i])
	env.adjustment_enabled = quality > 0
	env.adjustment_saturation = 1.3 if quality == 2 else 1.13
	env.adjustment_contrast = 1.1 if quality == 2 else 1.04
	env.adjustment_brightness = 1.0

static func surface(mat: StandardMaterial3D, quality: int) -> void:
	if mat.get_meta("custom_finish", false):
		return
	var luminous = bool(mat.get_meta("always_unshaded", false))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if quality == 0 or luminous else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if luminous:
		# An unshaded material ignores emission, so on Refinado the light is written into
		# the colour itself, past white: that is what crosses the bloom threshold and makes
		# eyes, neon lines, shots and rings actually glow. The original colour is kept so a
		# lighter profile can put it back.
		if not mat.has_meta("base_albedo"):
			mat.set_meta("base_albedo", mat.albedo_color)
		var base: Color = mat.get_meta("base_albedo")
		var boost: float = (1.42 if base.a >= 0.7 else 1.2) if quality == 2 else 1.0
		mat.albedo_color = Color(base.r * boost, base.g * boost, base.b * boost, base.a)
		mat.emission_enabled = false
		return
	if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return
	var kind = "alloy" if mat.metallic > 0.5 else ("graphite" if mat.albedo_color.v < 0.35 else "ceramic")
	mat.set_meta("surface_finish", kind)
	mat.albedo_texture = SURFACES[kind][0] if quality > 0 else null
	mat.roughness_texture = SURFACES[kind][1] if quality == 2 else null
	mat.normal_enabled = quality == 2
	mat.normal_texture = SURFACES[kind][2] if quality == 2 else null
	mat.normal_scale = 0.28
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 2.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.65 if kind == "graphite" else (0.52 if kind == "alloy" else 0.7)
	mat.metallic_specular = 0.7
	mat.clearcoat_enabled = quality == 2 and kind != "graphite"
	mat.clearcoat = 0.45
	mat.clearcoat_roughness = 0.25
	# A light rim on every lit edge: pilots, bricks and walls separate from the floor.
	mat.rim_enabled = quality == 2
	mat.rim = 0.4
	mat.rim_tint = 0.35

static func architecture(view) -> void:
	# Insets stay outside the playable wall; physics and all sightlines stay untouched.
	for index in range(view.walls.size()):
		var a: Vector2 = view.walls[index]
		var b: Vector2 = view.walls[(index + 1) % view.walls.size()]
		var edge = b-a
		var outer = Vector2(edge.y, -edge.x).normalized()
		var tone = view.CYAN if (a.y+b.y) > 0 else view.CORAL
		var begin = a.lerp(b, 0.06) + outer*0.13
		var end = a.lerp(b, 0.94) + outer*0.13
		view.segment(view, Vector3(begin.x, -0.25, begin.y), Vector3(end.x, -0.25, end.y), 0.16, 0.07, tone, true)
		var joints = maxi(1, int(edge.length()/1.5))
		for j in range(joints):
			var pos = a.lerp(b, (j+0.5)/joints)
			var node = view.box(view, Vector3(pos.x, 0.405, pos.y), Vector3(0.11,0.028,0.42), Color("536b75"), false, 0.008)
			node.rotation.y = -edge.angle()
			for side in [-1,1]:
				var screw = pos + outer * (0.155*side)
				view.cylinder(view, Vector3(screw.x,0.425,screw.y), 0.035,0.012,Color("b7c5c7"),false,10)
	# Recessed machinery and warm/cool side washes lend scale to the floating plinth.
	for side in [-1,1]:
		for z in [-5.2,5.2]:
			var x = side*(view.Rules.outline_x_at(view.walls,z)+0.36)
			var tone = view.CYAN if z > 0 else view.CORAL
			view.box(view,Vector3(x,-0.55,z),Vector3(0.35,0.38,1.9),Color("10222e"),false,0.09)
			for vent in range(5):
				view.box(view,Vector3(x,-0.38,z+(vent-2)*0.29),Vector3(0.39,0.06,0.12),tone,true,0.018)
