extends SceneTree
var failures = 0
var callbacks = 0
func check(ok, message):
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ", message)
func touch(hud, at, down):
	var e = InputEventScreenTouch.new()
	e.index = 0
	e.position = at
	e.pressed = down
	hud._input(e)
func _initialize(): call_deferred("run")
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.game_settings.config_path = "res://tests/controls-fx.tmp"
	game.mode = "pve"
	game.hud.show_game("pve", 0)
	game.rules.phase = "play"
	var hud = game.hud
	for mode in range(3):
		hud.select_fire_mode(mode)
		check(hud.fire_control_choice.selected == mode, "Selected firing mode %d survives settings sync" % mode)
		check(game.local_command().fire == (mode == 0), "Mode %d idle behaviour" % mode)
		touch(hud, hud.move_home, true)
		check(game.local_command().fire == (mode != 1), "Mode %d joystick behaviour" % mode)
		touch(hud, hud.move_home, false)
		game.local_command()
		check(game.local_command().fire == (mode == 0), "Mode %d stops on release" % mode)
		if mode == 1:
			touch(hud, hud.fire_center, true)
			check(game.local_command().fire, "Separate button shoots")
			touch(hud, hud.fire_center, false)
	var saved = game.GameSettings.new()
	saved.config_path = game.game_settings.config_path
	saved.load_preferences()
	check(not saved.auto_fire and saved.fire_control == 1, "Joystick selection survives reload")
	var arena = game.arena
	arena.guide_enabled = false
	arena.set_quality(2)
	var count = arena.get_child_count()
	for i in range(300):
		arena.emitter(Vector3.ZERO, Color.WHITE, 12, 0.3, 2, 30, 0.2)
		arena.flash(Vector3.ZERO, Color.WHITE, 2, 0.2)
	check(arena.active_particles > 0 and arena.active_particles <= arena.PARTICLE_POOL_LIMIT and arena.active_lights > 0 and arena.active_lights <= arena.LIGHT_POOL_LIMIT and arena.effects.size() <= arena.effect_limit, "Simultaneous effects have bounded particle/light counts")
	check(arena.get_child_count() == count, "Effect burst allocates no new emitter or light nodes")
	for i in range(120): arena.update_state(game.rules, 0, 1.0/60)
	check(arena.particle_pool.size() == arena.PARTICLE_POOL_LIMIT and arena.light_pool.size() == arena.LIGHT_POOL_LIMIT, "Expired effects return to pools")
	for i in range(50): arena.schedule(0, func(): callbacks += 1)
	arena.update_state(game.rules, 0, 1.0/60)
	check(callbacks == 4 and arena.pending.size() == 46, "Delayed visual work spreads across frames")
	for i in range(15): arena.update_state(game.rules, 0, 1.0/60)
	check(callbacks == 50 and arena.pending.is_empty(), "Scheduled effects finish without being lost")
	check(arena.quality_level == 2, "Selected graphics quality is preserved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.game_settings.config_path))
	game.queue_free()
	await process_frame
	quit(failures)
