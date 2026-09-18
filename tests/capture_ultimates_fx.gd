extends SceneTree
# The five ultimates on the field (needs a GPU; omit --headless).
const TMP = "res://tests/ultimates-fx.tmp"

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
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.power_shop.config_path = TMP
	await create_timer(0.8).timeout
	game.start_pve()
	game.pause_ai = true
	await create_timer(1.4).timeout
	game.rules.phase = "play"
	# Aim at a bank so the sun ray has something to eat.
	game.rules.players[0].angle = -0.34
	game.rules.players[0].p = game.Rules.track_position(0, -0.34)
	for shot in [["sun_ray", 2.35], ["meteors", 2.5], ["thunder", 2.6], ["bloom", 2.1], ["plunder", 2.15]]:
		fire(game, String(shot[0]))
		await create_timer(float(shot[1])).timeout
		await capture("preview-fx-%s.png" % shot[0])
		await create_timer(1.6).timeout
	# The wind-up glow, caught half way.
	fire(game, "sun_ray")
	await create_timer(1.2).timeout
	await capture("preview-fx-windup.png")
	await create_timer(2.5).timeout
	game.return_to_menu()
	quit(0)
