extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(540, 960)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_pve()
	game.rules.phase = "play"
	game.pause_ai = true
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-r03-game.png")
	game.pause_pve()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-r03-pause.png")
	quit()
