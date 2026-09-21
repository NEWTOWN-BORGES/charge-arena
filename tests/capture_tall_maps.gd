extends SceneTree
# Every campaign arena on a phone held upright, now that they are all stretched and
# leaning. Needs a GPU, so run it without --headless.
const Campaign = preload("res://scripts/campaign.gd")

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png("res://" + path)
	print("SCREENSHOT ", path, " result=", error)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(540, 1200)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.campaign.unlock_all = true
	await create_timer(0.4).timeout
	for level in [1, 4, 7, 10]:
		game.start_level(level)
		game.pause_ai = true
		await create_timer(1.1).timeout
		game.rules.phase = "play"
		await create_timer(0.3).timeout
		await capture("preview-tall-level-%02d.png" % (level + 1))
		game.return_to_menu()
		await create_timer(0.5).timeout
	quit(0)
