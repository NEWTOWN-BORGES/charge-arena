extends SceneTree
# Edge quality at each profile (needs a GPU; omit --headless).

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
	await create_timer(1.0).timeout
	game.start_pve()
	game.pause_ai = true
	await create_timer(1.6).timeout
	for quality in range(3):
		game.video.configure(120, quality, false, false)
		game.video.apply(root, game.arena)
		await create_timer(0.8).timeout
		await capture("preview-aa-%d.png" % quality)
	quit(0)
