extends SceneTree
# Menu and power buttons, portrait and landscape (needs a GPU; omit --headless).

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", path, " result=", root.get_texture().get_image().save_png("res://" + path))

func run() -> void:
	root.size = Vector2i(540, 1200)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.2).timeout
	await capture("preview-menu-look-portrait.png")
	root.size = Vector2i(1280, 720)
	await create_timer(0.8).timeout
	await capture("preview-menu-look-landscape.png")
	quit(0)
