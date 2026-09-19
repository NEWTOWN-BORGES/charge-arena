extends SceneTree
# The Relojoeiro's sentries, once posted and firing (needs a GPU; omit --headless).
const TMP = "res://tests/sentries-fx.tmp"

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", path, " result=", root.get_texture().get_image().save_png("res://" + path))

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
	game.rules.loadouts[0] = ["blast", "air", "sentries"]
	game.rules.powers[0].charge[2] = game.rules.power_charge_cost(0, 2)
	game.rules.activate_power(0, 2)
	await create_timer(game.Rules.ULTIMATE_WINDUP + 1.2).timeout
	await capture("preview-fx-sentries.png")
	# One of them takes a beating, so the health pips show.
	game.rules.turrets[0].hp = 2
	await create_timer(0.7).timeout
	await capture("preview-fx-sentries-hurt.png")
	await create_timer(0.4).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	quit(0)
