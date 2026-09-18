extends SceneTree
# The ultimate block inside the skins panel (needs a GPU; omit --headless).
const TMP = "res://tests/skin-ultimate.tmp"

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
	game.skins.config_path = TMP
	await create_timer(0.8).timeout
	game.hud.open_skins()
	for skin in [10, 3, 1]:
		game.hud.preview_skin(skin)
		game.hud.demo_clock = 1.1
		await create_timer(0.5).timeout
		await capture("preview-skin-ultimate-%d.png" % skin)
	root.size = Vector2i(540, 1200)
	game.hud.preview_skin(2)
	await create_timer(0.6).timeout
	await capture("preview-skin-ultimate-portrait.png")
	quit(0)
