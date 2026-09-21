extends SceneTree
# The three ultimates that open the campaign, on a phone held upright.
# Needs a GPU, so run it without --headless.
const TMP = "res://tests/new-ultimates.tmp"

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", path, " result=", root.get_texture().get_image().save_png("res://" + path))

func fire(game, id: String) -> void:
	game.rules.loadouts[0] = ["blast", "air", id]
	game.rules.powers[0].charge[2] = game.rules.power_charge_cost(0, 2)
	game.rules.activate_power(0, 2)

func run() -> void:
	root.size = Vector2i(540, 1200)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.power_shop.config_path = TMP
	await create_timer(0.8).timeout
	game.start_pve()
	game.pause_ai = true
	await create_timer(1.4).timeout
	game.rules.phase = "play"
	game.rules.players[0].angle = -0.34
	game.rules.players[0].p = game.Rules.track_position(0, -0.34)
	for pair in [["volley", 0.7], ["gravity", 2.2], ["surge", 0.5]]:
		var id: String = pair[0]
		fire(game, id)
		await create_timer(game.Rules.ULTIMATE_WINDUP + float(pair[1])).timeout
		await capture("preview-ult-%s.png" % id)
		await create_timer(2.4 if id == "gravity" else 1.4).timeout
		await create_timer(5.0 if id == "gravity" else 0.1).timeout
	game.return_to_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	quit(0)
