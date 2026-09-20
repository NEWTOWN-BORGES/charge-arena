extends SceneTree
# Battery: the game must not paint a still screen as fast as a live match. Outside a
# match — menu, shop, skins, pause — the frame rate drops to IDLE_FPS, and it comes back
# the moment a match starts.
const TMP = "res://tests/power-use"
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.campaign.unlock_all = true
	game.power_shop.config_path = TMP + "-powers.tmp"
	game.skins.config_path = TMP + "-skins.tmp"
	await process_frame
	game._process(0.016)
	check(Engine.max_fps == game.IDLE_FPS, "The menu paints at %d, not at the match rate" % game.IDLE_FPS)

	game.start_level(0)
	await process_frame
	game._process(0.016)
	check(Engine.max_fps == game.video.runtime_fps and game.video.runtime_fps > game.IDLE_FPS, "A live match gets the full rate (%d)" % game.video.runtime_fps)

	game.pve_paused = true
	game._process(0.016)
	check(Engine.max_fps == game.IDLE_FPS, "Pausing drops it again")
	game.pve_paused = false
	game._process(0.016)
	check(Engine.max_fps == game.video.runtime_fps, "And resuming brings it back")

	# The options panel counts as resting too: it sits over a still arena.
	game.hud.video_overlay.visible = true
	game._process(0.016)
	check(Engine.max_fps == game.IDLE_FPS, "The options panel rests as well")
	game.hud.video_overlay.visible = false

	game.return_to_menu()
	await process_frame
	game._process(0.016)
	check(Engine.max_fps == game.IDLE_FPS, "Back in the menu it rests once more")
	for leftover in ["-powers.tmp", "-skins.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + leftover))
	print("POWER_USE_RESULT failures=", failures)
	quit(failures)
