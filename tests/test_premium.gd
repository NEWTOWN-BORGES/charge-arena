extends SceneTree
## Regression checks for animated attachments, bounded VFX and graphics profiles.
const View = preload("res://scripts/indie_arena_view.gd")
const Rules = preload("res://scripts/arena_rules.gd")
const Video = preload("res://scripts/video_settings.gd")
const Audio = preload("res://scripts/combat_audio.gd")
var failures = 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _initialize(): call_deferred("run")

func run():
	var view = View.new()
	root.add_child(view)
	view.build()
	view.guide_enabled = false
	var rules = Rules.new()
	var video = Video.new()
	for skin in range(12) + range(100, 110):
		var pilot = view.build_player(View.CYAN, 0, skin)
		var body = pilot.get_node("Body")
		var valid = true
		for part in ["Finish", "LegL/Finish", "LegR/Finish", "Gun/Finish", "Gun/Flash"]:
			valid = valid and body.has_node(part)
		check(valid, "Skin %d keeps animated body, legs, weapon and muzzle" % skin)
		var batch_ok = true
		for part in ["Finish", "LegL/Finish", "LegR/Finish", "Gun/Finish"]:
			var mount = body.get_node(part)
			batch_ok = batch_ok and mount.get_child_count() <= 8
			batch_ok = batch_ok and mount.get_meta("authored_pieces", 0) > mount.get_child_count()
			for child in mount.get_children():
				batch_ok = batch_ok and child.mesh.get_aabb().position.is_finite() and child.mesh.get_aabb().size.is_finite()
		check(batch_ok, "Skin %d merges its fittings into bounded, finite meshes" % skin)
		pilot.free()
	# Switching profiles must be reversible, including glow, normal maps and MSAA.
	var ivory = view.material(View.CREAM)
	for quality in [2, 0, 1, 2]:
		video.configure(60, quality, false, false)
		video.apply(root, view)
		check(ivory.normal_enabled == (quality == 2) and (ivory.albedo_texture != null) == (quality > 0), "Profile %d uses the intended texture budget" % quality)
		check(view.presentation_environment.glow_enabled == (quality == 2) and root.msaa_3d == Video.AA_LEVELS[quality], "Profile %d applies glow and anti-aliasing" % quality)
		var finish = view.units[0].get_node("Body/Finish/Surface0").material_override
		var paint = finish.get_shader_parameter("paint_color")
		check(finish.shader.resource_path.ends_with("pilot_enamel_low.gdshader") == (quality == 0) and paint != null, "Profile %d preserves armour colours with the intended shader" % quality)
		var new_paint = view.material(Color(0.43, 0.38, 0.49 + quality * 0.03))
		check((new_paint.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED) == (quality == 0), "Newly created materials respect the current profile")
		for tick in range(120): view.update_state(rules, 0, 1.0 / 60.0)
		var nodes_before = view.get_child_count()
		for request in range(200):
			View.CombatFinish.card(view, Vector2.ZERO, 1.0, Color.CYAN, 0.2, request % 7)
		check(View.CombatFinish.active_count(view) == [8, 18, 28][quality], "Profile %d bounds simultaneous shock fronts" % quality)
		check(view.get_child_count() == nodes_before, "Impact burst creates no extra nodes")
		for tick in range(30): view.update_state(rules, 0, 1.0 / 60.0)
		check(View.CombatFinish.active_count(view) == 0 and (view.get_meta(View.CombatFinish.META) as Array).size() == 28, "All shock fronts return to the pool")
	# Recycled beam cards must reset their basis and size when reused as impacts.
	View.CombatFinish.beam(view, Vector2.ZERO, Vector2.UP, 8.0, 0.5, Color.CYAN)
	view.update_state(rules, 0, 0.05)
	var beam = view.effects.back().node
	check(beam.scale.is_equal_approx(Vector3(0.5, 4.0, 1.0)), "Beam retains its path dimensions while animating")
	for tick in range(30): view.update_state(rules, 0, 1.0 / 60.0)
	var ring = View.CombatFinish.card(view, Vector2.ZERO, 1.2, Color.CYAN, 0.2)
	check(ring.scale.is_equal_approx(Vector3.ONE * 1.2) and ring.basis.y.is_equal_approx(Vector3(0, 0, -1.2)), "Reused card resets its transform after a beam")
	for tick in range(30): view.update_state(rules, 0, 1.0 / 60.0)
	View.CombatFinish.event(view, {"kind": "bloom", "p": rules.players[0].p, "team": 0, "bricks": [0, 1]}, rules)
	check(View.CombatFinish.active_count(view) > 0, "Healing has a visible premium effect")
	var clips_ok = Audio.TRACKS.size() == 83
	for clip in Audio.TRACKS.values():
		clips_ok = clips_ok and clip.get_length() > 0.08 and clip.loop_mode == AudioStreamWAV.LOOP_DISABLED
	check(clips_ok, "All 83 combat cues are loaded, nonempty and do not loop")
	var bus = Audio.prepare_bus()
	Audio.prepare_bus()
	var index = AudioServer.get_bus_index(bus)
	check(index > 0 and AudioServer.get_bus_effect_count(index) == 1 and AudioServer.get_bus_effect(index, 0) is AudioEffectHardLimiter, "Combat gets one dedicated limiter without changing Master")
	view.free()
	print("PREMIUM_RESULT failures=", failures)
	quit(failures)
