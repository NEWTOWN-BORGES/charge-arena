extends SceneTree
# Aids for hitting bricks: aiming guide, softer stick, AI difficulty, plus weapon sounds
# and the Jardineiro's glass dome.
const Rules = preload("res://scripts/arena_rules.gd")
const GameSettings = preload("res://scripts/game_settings.gd")
const TMP = "res://tests/game-settings.tmp"
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func count_ai_shots(level: int, seconds: float) -> int:
	var r = Rules.new()
	r.ai_level = level
	r.phase = "play"
	var shots = 0
	for tick in range(roundi(seconds * 60)):
		r.step(1.0 / 60, [{"move": Vector2.ZERO, "fire": false}, r.ai_command()])
		shots += r.events.filter(func(e): return e.kind == "shot" and e.team == 1).size()
	return shots

func run() -> void:
	# Prediction used by the guide agrees with the AI's own shot forecast.
	var r = Rules.new()
	r.phase = "play"
	var aimed_at_brick = INF
	for i in range(61):
		var angle = -0.6 + i * 0.02
		var path: Dictionary = r.predict_path(0, angle)
		var forecast: Dictionary = r.predict_shot(0, angle)
		if path.outcome.get("kind", "") != forecast.get("kind", "") or path.outcome.get("target", -1) != forecast.get("target", -1):
			aimed_at_brick = -INF
			break
		if path.outcome.get("kind", "") == "brick" and aimed_at_brick == INF:
			aimed_at_brick = angle
	check(aimed_at_brick > -INF, "The guide predicts the same outcome as a real shot at every arc position")
	check(aimed_at_brick < INF, "Some arc positions line up a brick hit")
	var sample: Dictionary = r.predict_path(0, aimed_at_brick)
	var muzzle = Rules.track_position(0, aimed_at_brick) + Rules.forward_direction(0, aimed_at_brick) * 0.64
	check(sample.points[0].is_equal_approx(muzzle) and sample.points.size() > 3, "The predicted path starts at the muzzle")
	var state: Dictionary = r.snapshot().duplicate(true)
	r.predict_path(0, 0.3)
	check(r.snapshot() == state and r.events.is_empty(), "Drawing the guide never changes the match")

	# AI difficulty: same planner, slower pace on the easier levels.
	check(Rules.new().ai_level == 2, "Rules default to the full-strength AI used by the AI tests")
	var easy_shots = count_ai_shots(0, 30)
	var normal_shots = count_ai_shots(1, 30)
	var hard_shots = count_ai_shots(2, 30)
	check(easy_shots < normal_shots and normal_shots < hard_shots, "Fácil fires less than Normal, which fires less than Difícil (%d / %d / %d shots in 30 s)" % [easy_shots, normal_shots, hard_shots])
	check(not Rules.AI_LEVELS[0].dodge and Rules.AI_LEVELS[0].move < Rules.AI_LEVELS[1].move and Rules.AI_LEVELS[1].move < Rules.AI_LEVELS[2].move, "Easier AIs move slower and Fácil does not dodge")

	var settings = GameSettings.new()
	settings.config_path = TMP
	check(settings.difficulty == 1 and settings.aim_guide and settings.joystick_sensitivity == 2, "New players start on Normal with the guide and normal stick sensitivity")
	settings.configure(9, false, 99)
	check(settings.difficulty == 2 and settings.joystick_sensitivity == 4 and settings.save_preferences() == OK, "Difficulty and stick sensitivity are clamped and saved")
	var restored = GameSettings.new()
	restored.config_path = TMP
	restored.load_preferences()
	check(restored.difficulty == 2 and not restored.aim_guide and restored.joystick_sensitivity == 4, "Difficulty, guide and sensitivity survive a restart")

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	game.game_settings.config_path = TMP
	var hud = game.hud
	var arena = game.arena

	# The stick: a light push aims finely, full deflection runs.
	game.rules.players[0].angle = 0.0
	hud.move_vector = Vector2(0.5, 0)
	var half: Dictionary = game.local_command()
	hud.move_vector = Vector2(1, 0)
	var full: Dictionary = game.local_command()
	hud.move_vector = Vector2.ZERO
	check(half.move.x > 0.2 and half.move.x < 0.45 and is_equal_approx(full.move.x, 1.0), "Half stick moves slowly for fine aim, full stick still runs")
	hud.move_vector = Vector2(0.75, 0)
	game.game_settings.configure(1, true, 0)
	var slow: float = game.local_command().move.x
	game.game_settings.configure(1, true, 2)
	var normal: float = game.local_command().move.x
	game.game_settings.configure(1, true, 4)
	var fast: float = game.local_command().move.x
	hud.move_vector = Vector2.ZERO
	check(slow < normal and normal < fast and fast <= 1.0, "Five sensitivity levels scale the same stick movement from precise to fast")
	check(hud.sensitivity_choice.item_count == 5, "Options expose five joystick sensitivity levels")

	check(hud.difficulty_buttons.size() == 3, "The menu offers three AI levels")
	hud.difficulty_buttons[0].pressed.emit()
	check(game.rules.ai_level == 0 and game.game_settings.difficulty == 0 and hud.difficulty_buttons[0].button_pressed and not hud.difficulty_buttons[1].button_pressed, "Choosing Fácil in the menu applies and highlights it")
	game.start_pve()
	check(game.rules.ai_level == 0, "The chosen level carries into the match")
	arena = game.arena

	# Guide on a brick-bound angle: dots along the path and a ring on the target brick.
	arena.guide_enabled = true
	game.rules.phase = "play"
	game.rules.players[0].angle = aimed_at_brick
	game.rules.players[0].p = Rules.track_position(0, aimed_at_brick)
	var outcome: Dictionary = game.rules.predict_path(0, aimed_at_brick).outcome
	arena.guide_timer = 0
	arena.update_state(game.rules, 0, 1.0 / 60)
	var shown = arena.guide_dots.filter(func(d): return d.visible).size()
	var target: Dictionary = game.rules.bricks[outcome.target]
	check(arena.aim_guide.visible and shown >= 3 and not arena.aim_line.visible, "The guide draws the shot path instead of the short aim line")
	check(arena.guide_marker.visible and Vector2(arena.guide_marker.position.x, arena.guide_marker.position.z).is_equal_approx(target.p), "A ring marks the brick the shot would hit")
	game.rules.players[0].stun = 0.4
	arena.update_state(game.rules, 0, 1.0 / 60)
	check(not arena.aim_guide.visible, "The guide hides while stunned")
	game.rules.players[0].stun = 0
	hud.guide_choice.button_pressed = false
	arena.update_state(game.rules, 0, 1.0 / 60)
	check(not arena.guide_enabled and not arena.aim_guide.visible and arena.aim_line.visible and not game.game_settings.aim_guide, "Turning the guide off in the options restores the short aim line")
	hud.guide_choice.button_pressed = true

	# Weapon sounds follow the pilot's skin.
	var streams: Array = []
	for skin in range(game.Skins.CATALOG.size()):
		var stream: AudioStream = game.tones.get("shot_%d" % skin)
		check(stream != null and stream.get_length() > 0.1, "Weapon %d has its own shot sound" % skin)
		streams.append(stream)
	check(streams.all(func(a): return streams.count(a) == 1), "No two weapons share a sound")
	arena.set_skin(0, 4)
	game.rules.players[0].cooldown = 0
	game._physics_process(1.0 / 60)
	check(game.audio_voices.any(func(v): return v.stream == game.tones["shot_4"]), "Firing as the Mineiro plays the drill sound")
	for voice in game.audio_voices:
		voice.stop()
	game.play_tone("shot_5")
	var weapon_voice: AudioStreamPlayer = game.audio_voices.filter(func(v): return v.stream == game.tones["shot_5"])[0]
	game.play_tone("bounce")
	check(weapon_voice.playing and game.audio_voices.any(func(v): return v != weapon_voice and v.playing and v.stream == game.tones["bounce"]), "Ricochets overlap a weapon tail instead of cutting it")
	game.play_tone("boost")
	check(game.tones.has("boost") and game.tones.boost != game.tones.bounce and game.audio_voices.any(func(v): return v.playing and v.stream == game.tones.boost), "Boost contact has its own longer rising sound")
	for voice in game.audio_voices:
		voice.stop()
	game.mode = "client"
	game.rules.balls = [{"id": 771, "owner": 0, "p": Vector2.ZERO, "v": Vector2.UP, "boosted": true, "damage": 2, "bounces": 1, "ttl": 2.0}]
	game._process(0.016)
	check(game.client_boosted_ids.has(771) and game.audio_voices.any(func(v): return v.playing and v.stream == game.tones.boost), "PvP client hears the boost when the authoritative projectile becomes charged")
	game.mode = "pve"
	game.return_to_menu()
	hud.open_skins()
	hud.preview_skin(3)
	hud.animate_viewer(0.4)
	check(hud.viewer_audio.stream != null and hud.viewer_audio.stream.resource_path.ends_with("shot_3.wav"), "Previewing a skin plays its weapon sound once")
	hud.close_skins()

	# The Jardineiro's dome uses the rim-lit glass shader.
	game.arena.set_skin(0, 3)
	var glass = game.arena.units[0].find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.material_override is ShaderMaterial and m.material_override.shader == game.arena.GLASS)
	check(glass.size() == 1, "The Jardineiro's dome is drawn as rim-lit glass")
	game.arena.set_skin(0, 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("AIDS_RESULT failures=", failures)
	quit(failures)
