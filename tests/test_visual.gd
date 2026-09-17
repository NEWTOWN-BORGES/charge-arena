extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png("res://" + name)
	print("SCREENSHOT ", name, " result=", error)
	if error != OK:
		quit(error)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.6).timeout
	await capture("preview-menu.png")
	game.start_pve()
	await create_timer(3.5).timeout
	await capture("preview-gameplay-r05.png")
	root.size = Vector2i(1200, 554)
	await create_timer(0.4).timeout
	await capture("preview-mobile.png")
	quit(0)
