extends SceneTree
# Screenshots of the vertical phone layout (needs a GPU; omit --headless).

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var error = image.save_png("res://" + path)
	print("SCREENSHOT ", path, " ", image.get_size(), " result=", error)
	if error != OK:
		quit(1)

func run() -> void:
	root.size = Vector2i(540, 1200)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.8).timeout
	await capture("preview-portrait-menu.png")
	game.hud.open_video()
	await create_timer(0.3).timeout
	await capture("preview-portrait-settings.png")
	game.hud.close_video()
	game.start_pve()
	await create_timer(0.6).timeout
	await capture("preview-portrait-countdown.png")
	await create_timer(5.0).timeout
	game.rules.players[0].stun = 0.4
	await create_timer(0.1).timeout
	await capture("preview-portrait-gameplay.png")
	root.size = Vector2i(720, 1280)
	await create_timer(0.5).timeout
	await capture("preview-portrait-16x9.png")
	root.size = Vector2i(1280, 720)
	await create_timer(0.5).timeout
	await capture("preview-landscape-check.png")
	quit(0)
