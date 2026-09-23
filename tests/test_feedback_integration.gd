extends SceneTree
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.game_settings.config_path = "res://tests/feedback-settings.tmp"
	game.mode = "pve"
	game.hud.show_game("pve", 0)
	game.rules.phase = "play"
	game.change_feedback(0, false, false, 0.7)
	check(game.local_command().fire == false, "Manual mode does not auto-fire")
	var touch = InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = game.hud.fire_center
	game.hud._input(touch)
	touch.pressed = false
	game.hud._input(touch)
	var command: Dictionary = game.local_command()
	check(command.fire and command.tap, "A released short tap survives to simulation and PvP RPC")
	check(not game.local_command().fire, "Manual short tap consumed once")
	game.rules.events = []
	game.rules.shoot(0)
	game.rules.shoot(1)
	game.play_events()
	check(game.arena.shot_age == [0.0, 0.0], "Both pilots receive event-driven recoil")
	check(game.audio_voices.filter(func(v): return v.playing and v.get_meta("weapon_voice")).size() == 2, "Both sides audible with independent voices")
	var started: Array = game.audio_voices.filter(func(v): return v.playing and v.get_meta("weapon_voice"))
	var stream = started[0].stream
	for n in range(40): game.play_tone("blast")
	check(started[0].playing and started[0].stream == stream, "Impact saturation cannot steal weapon tails")
	game.arena.shake(0.9)
	check(game.arena.shake_power == 0.0, "Disabled camera shake stays disabled")
	game.rules.powers[0].ultimate_windup = 0.15
	game.update_feedback_mix(0.10)
	check(game.arena_duck_db < -4.0, "Secondary sounds duck before ultimate release")
	game.rules.powers[0].ultimate_windup = 0.0
	game.update_feedback_mix(0.3)
	check(game.arena_duck_db == 0.0, "Arena mix recovers after ultimate")
	var settings = load("res://scripts/game_settings.gd").new()
	settings.config_path = game.game_settings.config_path
	settings.load_preferences()
	check(not settings.auto_fire and not settings.haptics and settings.camera_feedback == 0 and is_equal_approx(settings.sfx_volume, 0.7), "Feedback preferences persist")
	game.change_feedback(1, true, true, 0.85)
	check(game.local_command().fire, "Automatic mode remains available")
	# All 12 skins have distinct original timbres and three short ready-to-play variations.
	for skin in range(12):
		for variant in range(3):
			check(game.tones.has("shot_%d_%d" % [skin, variant]), "Shot audio %d/%d loads" % [skin, variant])
	game.queue_free()
	await process_frame
	print("FEEDBACK_INTEGRATION_RESULT failures=", failures)
	quit(failures)
