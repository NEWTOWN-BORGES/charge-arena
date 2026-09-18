extends SceneTree
# The looping demonstration of each power (needs a GPU; omit --headless).
const TMP = "res://tests/powers-demo.tmp"

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
	await create_timer(0.6).timeout
	game.hud.open_powers()
	for index in range(game.hud.shop_entries().size()):
		game.hud.preview_power(index)
		for moment in [0.55, 1.9]:
			game.hud.demo_clock = moment
			game.hud.power_demo.queue_redraw()
			await capture("preview-demo-%d-%d.png" % [index, int(moment * 10)])
	game.hud.close_powers()
	quit(0)
