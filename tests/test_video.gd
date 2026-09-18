extends SceneTree
const Settings = preload("res://scripts/video_settings.gd")
var failures = 0
var checks = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	var settings = Settings.new()
	for limit in [60, 90, 120]:
		for quality in range(3):
			settings.configure(limit, quality, false, true)
			settings.apply(root, game.arena)
			check(Engine.max_fps == limit and root.msaa_3d == Settings.AA_LEVELS[quality] and Engine.physics_ticks_per_second == 60, "FPS %d / quality %d apply without changing physics speed" % [limit, quality])
	settings.configure(90, 2, true, true)
	var path = "res://tests/video-preferences.tmp"
	check(settings.save_preferences(path) == OK, "Display preferences save successfully")
	var restored = Settings.new()
	restored.load_preferences(path)
	check(restored.fps == 90 and restored.quality == 2 and restored.vsync and restored.show_fps, "FPS, quality, VSync and counter survive reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	restored.configure(-1, 500, false, false)
	check(restored.fps == 60 and restored.quality == 2, "Invalid settings are clamped safely")
	restored.configure(120, 2, false, false)
	restored.apply(root, game.arena)
	for i in range(4):
		restored.adapt(root, 45, true)
	check(restored.runtime_fps == 90 and is_equal_approx(root.scaling_3d_scale, 1.0) and root.msaa_3d == Settings.AA_LEVELS[2], "Refinado falls from 120 to 90 FPS without lowering graphics")
	for i in range(4):
		restored.adapt(root, 45, true)
	check(restored.runtime_fps == 60 and is_equal_approx(root.scaling_3d_scale, 1.0), "Refinado falls from 90 to 60 FPS while preserving native 3D resolution")
	restored.configure(60, 0, false, false)
	restored.apply(root, game.arena)
	for i in range(2):
		restored.adapt(root, 20, true)
	check(root.scaling_3d_scale < Settings.RENDER_SCALES[0], "Only Leve may reduce 3D resolution on a weak phone")
	settings.configure(90, 2, true, true)
	game.hud.sync_video(settings)
	check(game.hud.fps_choice.selected == 1 and game.hud.quality_choice.selected == 2 and game.hud.fps_label.visible, "Settings menu and real FPS counter reflect selected preferences")
	game.start_pve()
	game.hud.move_vector = Vector2.RIGHT
	game.mouse_firing = true
	game.hud.open_video()
	game.hud.request_power(0)
	check(game.local_command() == {"move": Vector2.ZERO, "fire": false, "power": -1} and not game.mouse_firing and game.hud.power_request == -1, "Opening graphics settings releases movement, firing and powers")
	var before: Dictionary = game.rules.snapshot().duplicate(true)
	game._physics_process(0.1)
	check(game.rules.snapshot() == before, "PvE simulation pauses while changing graphics settings")
	game.hud.close_video()
	check(not game.hud.video_overlay.visible and game.local_command().fire and game.hud.move_vector == Vector2.ZERO, "Closing settings hands the pilot back, firing on its own and standing still")
	game.rules.phase = "play"
	game.arena.capture_motion(game.rules)
	game.rules.step(0.1, [{"move": Vector2.RIGHT}, {"move": Vector2.ZERO}])
	game.arena.update_state(game.rules, 0, 0.008, 0.5)
	var mid: Vector2 = game.Rules.track_position(0, game.rules.players[0].angle * 0.5)
	check(game.arena.units[0].position.is_equal_approx(Vector3(mid.x, 0, mid.y)), "High-refresh visual frames interpolate the player along the actual arc")
	check(game.arena.obstacle_nodes[0].position.x > 0 and game.arena.obstacle_nodes[0].position.x < game.rules.obstacles[0].p.x, "Moving obstacles interpolate between simulation ticks")
	check(game.arena.static_batch_count > 0 and game.arena.static_batch_count < 60 and game.arena.brick_batches.size() < 20, "Architecture and 560 brick pieces are grouped into a bounded number of draws")
	game.rules.bricks[0].hp = 1
	game.arena.update_state(game.rules, 0, 0.008)
	var body_binding = game.arena.brick_instances[0][2]
	var pose: Transform3D = body_binding.batch.get_instance_transform(body_binding.slot)
	if DisplayServer.get_name() != "headless":
		check(is_equal_approx(pose.basis.x.length(), 0.52), "Batched brick geometry shrinks to match its remaining life")
	game.rules.bricks[0].hp = 0
	game.rules.bricks[0].alive = false
	game.arena.update_state(game.rules, 0, 0.008)
	if DisplayServer.get_name() != "headless":
		check(body_binding.batch.get_instance_transform(body_binding.slot).origin.y < -50, "Destroyed brick is removed from the visible batch")
	game.rules.reset_round()
	game.arena.update_state(game.rules, 0, 0.008)
	if DisplayServer.get_name() != "headless":
		check(is_equal_approx(body_binding.batch.get_instance_transform(body_binding.slot).basis.x.length(), 1.0), "New round restores batched bricks at full size")
	else:
		print("GPU_ONLY: 3 MultiMesh readback checks require a graphical renderer; dummy rendering returns identity transforms.")
	print("BATCH_METRICS architecture=", game.arena.static_batch_count, " brick_batches=", game.arena.brick_batches.size())
	print("VIDEO_RESULT ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)
