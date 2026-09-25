extends SceneTree
# Gun feel: the shot, the impact, the broken brick and the goal are told through one hub,
# with a recoil curve, a micro-pause, a layered camera, a mixed and ducked soundscape and
# haptic categories - and none of it ever reaches the simulation.
const Rules = preload("res://scripts/arena_rules.gd")
const View = preload("res://scripts/indie_arena_view.gd")
const CombatFeel = preload("res://scripts/combat_feel.gd")
var failures = 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# --- The recoil curve: snap, hold, return, settle ---------------------------------
	var peak_at = 0.0
	var peak = -1.0
	for ms in range(0, 400):
		var v = View.recoil_curve(ms / 1000.0, CombatFeel.default_of("fire_recoil_duration"), CombatFeel.default_of("fire_return_duration"))
		if v > peak:
			peak = v
			peak_at = ms
	check(peak_at >= 50 and peak_at <= 80, "Recoil peaks between 50 and 80 ms (%d ms)" % peak_at)
	check(View.recoil_curve(0.02, 0.065, 0.15) > 0.8, "It snaps: over 80 % of the kick inside 20 ms")
	var back = CombatFeel.default_of("fire_return_duration")
	check(back >= 0.12 and back <= 0.18, "Recovery is set between 120 and 180 ms")
	check(absf(View.recoil_curve(0.065 + 0.15, 0.065, 0.15)) < 0.07 and View.recoil_curve(0.4, 0.065, 0.15) == 0.0, "It returns, settles and rests")

	# --- Hierarchy and categories --------------------------------------------------------
	var order = ["ambient", "ricochet", "shot", "brick_hit", "brick", "power", "ultimate", "goal"]
	var rising = true
	for i in range(1, order.size()):
		rising = rising and CombatFeel.level_of(order[i]) > CombatFeel.level_of(order[i - 1])
	check(rising, "The hierarchy climbs: ambient < ricochet < shot < impact < destruction < power < ultimate < goal")
	var feel = CombatFeel.new()
	var buzz = ["fire", "destroy", "power", "ultimate", "goal"].map(func(k): return feel.haptic_for(k).y)
	check(buzz[0] < buzz[1] and buzz[1] < buzz[2] and buzz[2] < buzz[3] and buzz[3] < buzz[4], "Haptic categories rise from FIRE to GOAL")
	feel.set_value("haptic_fire_strength", 0.0)
	check(feel.haptic_for("fire") == Vector2.ZERO, "FIRE haptics can be tuned off on their own")
	feel.set_value("fire_recoil_duration", 9.0)
	check(feel.value("fire_recoil_duration") == float(CombatFeel.PARAMS["fire_recoil_duration"][2]), "Tuning is clamped to its range")
	feel.config_path = "res://tests/gun-feel.tmp"
	feel.set_value("trail_length", 1.5)
	feel.effects_reduced = true
	feel.save_preferences()
	var again = CombatFeel.new()
	again.config_path = feel.config_path
	again.load_preferences()
	check(again.value("trail_length") == 1.5 and again.effects_reduced, "Tuning and the reduced-effects choice are saved")
	check(again.hitstop_for("brick") == 0.0, "Reduced effects drop the micro-pauses")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(feel.config_path))
	check(CombatFeel.material_of({"kind": "bounce", "surface": "obstacle"}) == "metal" and CombatFeel.material_of({"kind": "brick_hit", "soaked": true}) == "shield" and CombatFeel.material_of({"kind": "player_hit"}) == "shield" and CombatFeel.material_of({"kind": "bounce", "surface": "wall"}) == "wall" and CombatFeel.material_of({"kind": "brick"}) == "brick", "Every surface answers in its own material")
	feel.free()
	again.free()

	# --- The game: one hub, many listeners ------------------------------------------------
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.feel.config_path = "res://tests/gun-feel-game.tmp"
	game.feel.reset()
	game.feel.effects_reduced = false
	game.start_pve()
	game.pause_ai = true
	game.set_physics_process(false)
	await process_frame
	var heard: Array = []
	game.feel.weapon_fired.connect(func(info): heard.append(info))
	game.rules.phase = "play"
	game.rules.events = []
	game.rules.shoot(0)
	game.rules.shoot(1)
	game.play_events()
	check(heard.size() == 2 and heard[0].local and not heard[1].local, "Each shot is announced once as weapon_fired, marked local or not")
	check(game.arena.shot_age == [0.0, 0.0] and game.hud.fire_pop == 0.0 and game.hud.fire_cool_left > 0.0, "Picture and HUD both answer the same announcement")
	check(game.arena.shake_layers.size() >= 1, "The local shot nudges the camera")
	check(game.audio_voices.any(func(v): return v.playing and v.stream == game.tones["shot_air"]), "The local shot has its air layer")
	var pitches: Array = []
	for n in range(12):
		pitches.append(game.feel.pitch())
	check(pitches.max() - pitches.min() > 0.005 and pitches.max() <= 1.0 + game.feel.value("audio_pitch_variation"), "Shots drift in pitch, within ±%.1f %%" % (game.feel.value("audio_pitch_variation") * 100))

	# The fire button: 100 -> 94 -> 103 -> 100.
	var hud = game.hud
	hud.fire_pop = 1.0
	check(is_equal_approx(hud.fire_scale(true), 0.94) and hud.fire_scale(false) == 1.0, "The button squeezes to 94 % under the thumb")
	hud.on_weapon_fired({"local": true, "power": 0})
	hud.fire_pop = hud.FIRE_POP_SECONDS * 0.5
	check(hud.fire_scale(false) > 1.025, "It pops to 103 % as the round leaves")
	hud.fire_pop = hud.FIRE_POP_SECONDS
	check(hud.fire_scale(false) == 1.0, "And settles")
	hud._process(Rules.FIRE_INTERVAL + 0.01)
	check(hud.fire_cool_left == 0.0 and hud.fire_ready_pulse < hud.READY_PULSE_SECONDS, "The reload ring runs out and the ready pulse fires")

	# --- Presentation never reaches the simulation ------------------------------------------
	# Two identical simulations; one of them is told through everything the game has.
	var told = Rules.new()
	var twin = Rules.new()
	for sim in [told, twin]:
		sim.set_map(game.rules.map)
		sim.reset_match()
	var own_rules = game.rules
	game.rules = told
	var arena = game.arena
	var fire_every = 0
	for tick in range(60 * 8):
		var command = {"move": Vector2(0.4 if (tick / 90) % 2 == 0 else -0.4, 0), "fire": tick % 25 == 0, "power": -1}
		var still = {"move": Vector2.ZERO, "fire": tick % 40 == 0, "power": -1}
		told.step(1.0 / 60.0, [command, still])
		twin.step(1.0 / 60.0, [command.duplicate(), still.duplicate()])
		game.play_events()
		if tick % 50 == 0:
			arena.hitstop(0.05)
			arena.goal_payoff(0)
		arena.update_state(game.rules, 0, 1.0 / 60.0)
	check(told.events.size() >= 0 and twin.elapsed > 7.9 and var_to_str(told.snapshot()) == var_to_str(twin.snapshot()), "Recoil, flashes, micro-pauses and the goal payoff leave the simulation identical")
	game.rules = own_rules

	# --- The micro-pause holds effects, not play --------------------------------------------
	arena.pending.clear()
	arena.effects.clear()
	arena.hitstop_left = 0.0
	arena.fx_dilation_left = 0.0
	arena.fx_time_scale = 1.0
	arena.impact_feedback({"kind": "bounce", "p": Vector2.ZERO, "team": 0, "surface": "obstacle", "heading": Vector2.UP, "normal": Vector2.DOWN})
	var probe: Dictionary = arena.effects.back()
	var spark_life: float = probe.ttl
	arena.hitstop(0.05)
	arena.update_state(game.rules, 0, 0.02)
	check(is_equal_approx(probe.ttl, spark_life), "Through a micro-pause, effects hold")
	arena.update_state(game.rules, 0, 0.04)
	arena.update_state(game.rules, 0, 0.02)
	check(probe.ttl < spark_life, "And then move on")

	# --- Layered camera ------------------------------------------------------------------
	arena.shake_scale = 1.0
	arena.clear_shake()
	arena.feel_shake("brick", Vector3.FORWARD)
	arena.feel_shake("shot", Vector3.BACK)
	check(arena.shake_layers.size() == 2 and arena.shake_offset(0.02) != Vector3.ZERO, "Camera shakes stack as layers, each with its own direction")
	for n in range(40):
		arena.shake_offset(0.02)
	check(arena.shake_layers.is_empty() and arena.shake_power == 0.0, "And every layer dies out")
	arena.shake_scale = 0.0
	arena.feel_shake("goal", Vector3.FORWARD)
	check(arena.shake_layers.is_empty(), "Camera shake Off stays off")
	arena.shake_scale = 1.0

	# --- LEVE and reduced effects keep FIRE -> IMPACT -> DESTROY, without the light ---------
	arena.set_quality(0)
	var glows = arena.glow_pool.size() + arena.glow_allocated
	arena.shot_feedback(0, true)
	check(arena.glow_pool.size() + arena.glow_allocated == glows and arena.effects.any(func(e): return e.get("pooled", false)), "On Leve the shot keeps its sparks but throws no light")
	arena.set_quality(2)
	game.feel.effects_reduced = true
	var lit = arena.effects.filter(func(e): return e.get("glow_pool", false)).size()
	arena.shot_feedback(0, true)
	check(arena.effects.filter(func(e): return e.get("glow_pool", false)).size() == lit, "Reduced effects throw no light either")
	game.feel.effects_reduced = false
	arena.shot_feedback(0, true)
	check(arena.effects.filter(func(e): return e.get("glow_pool", false)).size() > lit, "Refinado lights the floor at the muzzle")

	# --- Bricks wear their damage ------------------------------------------------------------
	game.rules.reset_match()
	arena.update_state(game.rules, 0, 0.016)
	var index = game.rules.bricks.find(game.rules.bricks.filter(func(b): return b.team == 1)[0])
	var brick: Node3D = arena.brick_nodes[index]
	check(not brick.get_node("CrackA0").visible, "A whole brick has no cracks")
	game.rules.bricks[index].hp = 2
	arena.update_state(game.rules, 0, 0.016)
	check(brick.get_node("CrackA0").visible and not brick.get_node("CrackB0").visible, "One hit: hairline cracks")
	game.rules.bricks[index].hp = 1
	arena.update_state(game.rules, 0, 0.016)
	check(brick.get_node("CrackB0").visible, "Two hits: split")
	var drawn = false
	for binding in arena.brick_instances[index]:
		if binding.part == brick.get_node("CrackB0"):
			drawn = binding.batch.get_instance_transform(binding.slot).basis.get_scale().x > 0.5
	check(drawn, "The cracks are drawn in the brick's shared batch")

	# --- Mix: the goal pushes everything under it down, and lets go -------------------------
	game.play_tone("ricochet")
	game.play_tone("goal")
	game.duck("goal")
	game.update_feedback_mix(0.25)
	var low = game.audio_voices.filter(func(v): return v.playing and int(v.get_meta("level", 0)) == 1)
	var top = game.audio_voices.filter(func(v): return v.playing and int(v.get_meta("level", 0)) == 7)
	check(game.arena_duck_db < -6.0 and not low.is_empty() and not top.is_empty() and low[0].volume_db < float(low[0].get_meta("mix_gain")) - 5.0 and top[0].volume_db > float(top[0].get_meta("mix_gain")) - 1.5, "A goal ducks the ricochets under it, never itself")
	game.update_feedback_mix(1.2)
	game.update_feedback_mix(0.5)
	check(game.arena_duck_db == 0.0, "The mix comes back after the goal")

	# --- PvP guest: its own tap is told at once, and not told twice -------------------------
	game.predicted_shots.clear()
	game.predicted_shots.append(Time.get_ticks_msec())
	check(game.consume_prediction() and not game.consume_prediction(), "The host's shot is recognised once as the guest's own tap")
	game.predicted_shots.append(Time.get_ticks_msec() - 5000)
	check(not game.consume_prediction(), "A tap the host turned down is forgotten")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.feel.config_path))
	game.queue_free()
	await process_frame
	print("GUN_FEEL_RESULT failures=", failures)
	quit(failures)
