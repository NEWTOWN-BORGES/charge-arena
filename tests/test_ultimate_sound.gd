extends SceneTree
# Every ultimate has a voice: the charge, the discharge and the effect itself.
const Rules = preload("res://scripts/arena_rules.gd")
const Powers = preload("res://scripts/powers.gd")
const TMP = "res://tests/ult-sound.tmp"
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func heard(game, name: String) -> bool:
	return game.audio_voices.any(func(v): return v.stream == game.tones.get(name))

func hush(game) -> void:
	for voice in game.audio_voices:
		voice.stop()
		voice.stream = null

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.power_shop.config_path = TMP
	game.skins.config_path = TMP + "s"
	game.start_pve()
	game.pause_ai = true
	await process_frame
	var names = ["charging", "unleash", "sun_ray", "meteor", "thunder", "bloom", "plunder"]
	check(names.all(func(n): return game.tones.has(n) and game.tones[n].data.size() > 1000), "Each ultimate cue is a real waveform")
	var voices: Array = names.map(func(n): return game.tones[n])
	check(voices.all(func(v): return voices.count(v) == 1), "No two of them share a sound")

	for id in ["sun_ray", "meteors", "thunder", "bloom", "plunder"]:
		game.rules.phase = "play"
		game.rules.loadouts[0] = ["blast", "air", id]
		game.rules.powers[0].charge[2] = game.rules.power_charge_cost(0, 2)
		hush(game)
		game.hud.request_power(2)
		game._physics_process(1.0 / 60)
		check(heard(game, "charging"), "%s: the two seconds of charge are heard" % id)
		hush(game)
		for tick in range(roundi(Rules.ULTIMATE_WINDUP * 60) + 4):
			game._physics_process(1.0 / 60)
		check(heard(game, "unleash"), "%s: the discharge is heard" % id)
		# The beam, the rocks and the bolts keep sounding while they work.
		if id in ["sun_ray", "thunder"]:
			hush(game)
			for tick in range(60):
				game._physics_process(1.0 / 60)
			check(heard(game, "sun_ray" if id == "sun_ray" else "thunder"), "%s: the effect itself is heard while it lasts" % id)
		game.rules.powers[0] = Rules.new_power_state()
	game.return_to_menu()
	for leftover in [TMP, TMP + "s"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(leftover))
	print("ULT_SOUND_RESULT failures=", failures)
	quit(failures)
