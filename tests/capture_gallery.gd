extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(file: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-gallery-" + file + ".png")
func run() -> void:
	root.size = Vector2i(540, 960)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.skins.config_path = "res://tests/gallery-capture.tmp"
	await capture("menu")
	game.hud.open_skins()
	game.hud.preview_skin(1)
	await capture("portrait")
	root.size = Vector2i(1280, 720)
	await capture("landscape")
	game.hud.close_skins()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.skins.config_path))
	quit()
