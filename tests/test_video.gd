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
	for limit in Settings.FPS_OPTIONS:
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
	check(restored.fps == 60, "A setting of 120 saved by an older build lands on 60")
	restored.configure(90, 2, false, false)
	restored.apply(root, game.arena)
	var lit: bool = game.arena.key_light.shadow_enabled
	var energy: float = game.arena.key_light.light_energy
	for i in range(Settings.GRACE_WINDOWS + 4):
		restored.adapt(root, 45, true)
	check(restored.runtime_fps == 90 and root.msaa_3d == Viewport.MSAA_4X, "A phone that cannot hold 90 gives up antialiasing before a single frame")
	check(game.arena.key_light.shadow_enabled == lit and game.arena.key_light.light_energy == energy, "And the lighting never changes mid-match: that is what turned the arena dark")
	for i in range(200):
		if restored.runtime_fps < 90:
			break
		restored.adapt(root, 45, true)
	check(restored.runtime_fps == 60 and root.msaa_3d == Viewport.MSAA_2X and is_equal_approx(root.scaling_3d_scale, Settings.MIN_RENDER_SCALES[2]), "Then 3D resolution, and only then 90 becomes 60")
	for i in range(Settings.GRACE_WINDOWS + Settings.RECOVER_WINDOWS):
		restored.adapt(root, 60, true)
	check(restored.runtime_fps == 90, "Steady play climbs back to the 90 that was chosen instead of staying down for good")
	var climbed: int = restored.level
	for i in range(Settings.GRACE_WINDOWS + 4):
		restored.adapt(root, 45, true)
	check(restored.level == climbed + 1 and restored.recover_after == Settings.RECOVER_WINDOWS * 2, "A climb that does not hold falls back and waits twice as long before trying again")
	restored.hold()
	for i in range(Settings.GRACE_WINDOWS):
		restored.adapt(root, 5, true)
	check(restored.level == climbed + 1, "Readings right after a pause or a countdown are not taken for a slow phone")
	restored.configure(90, 2, true, false)
	restored.apply(root, game.arena)
	for i in range(Settings.GRACE_WINDOWS + 1):
		restored.adapt(root, 60, true, 60.0)
	check(restored.panel_cap == 60 and restored.runtime_fps == 60 and root.msaa_3d == Settings.AA_LEVELS[2] and is_equal_approx(root.scaling_3d_scale, 1.0), "A screen refreshing at 60 Hz caps the target at 60 without taking a thing from the picture")
	for i in range(Settings.GRACE_WINDOWS + 1):
		restored.adapt(root, 60, true, 120.0)
	check(restored.panel_cap == 0 and restored.runtime_fps == 90, "And when the screen goes faster, the 90 comes back")
	restored.mobile = true
	restored.configure(90, 2, false, false)
	restored.apply(root, game.arena)
	check(root.msaa_3d == Viewport.MSAA_4X and restored.build_ladder(60.0)[0][0] == Viewport.MSAA_4X, "A phone's Refinado stops at 4x MSAA, as far as mobile GPUs go")
	var phone_ladder: Array = restored.build_ladder(90.0)
	check(phone_ladder.size() > 1 and phone_ladder.all(func(step): return step[0] == phone_ladder[0][0] and is_equal_approx(step[1], phone_ladder[0][1])), "On a phone the ladder only lowers the frame limit: the 3D image is never resized or re-sampled mid-match")
	var Finish = preload("res://scripts/arena_finish.gd")
	game.arena.phone = true
	Finish.phone = true
	game.arena.set_quality(2)
	var env: Environment = game.arena.presentation_environment
	check(not game.arena.key_light.shadow_enabled and is_equal_approx(game.arena.key_light.light_energy, 1.35) and env.tonemap_mode == Environment.TONE_MAPPER_FILMIC and is_equal_approx(env.tonemap_white, 1.0), "A phone's Refinado keeps the grade that works without light past white: no real shadows, the old sun, filmic")
	game.arena.phone = false
	Finish.phone = false
	game.arena.set_quality(2)
	restored.mobile = false
	restored.configure(60, 0, false, false)
	restored.apply(root, game.arena)
	for i in range(Settings.GRACE_WINDOWS + 2):
		restored.adapt(root, 20, true)
	check(root.scaling_3d_scale < Settings.RENDER_SCALES[0], "Leve lowers its 3D resolution on a weak phone")
	settings.configure(90, 2, true, true)
	game.hud.sync_video(settings)
	check(game.hud.fps_choice.selected == Settings.FPS_OPTIONS.find(90) and game.hud.quality_choice.selected == 2 and game.hud.fps_label.visible, "Settings menu and real FPS counter reflect selected preferences")
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
