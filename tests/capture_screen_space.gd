extends SceneTree
# The match HUD on a phone held upright and on a wide screen: the band at the top, the
# stadium between, the thumb controls and their captions at the bottom. Needs a GPU, so
# run it without --headless.

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
	await create_timer(0.4).timeout
	game.start_pve()
	game.pause_ai = true
	await create_timer(1.2).timeout
	game.rules.phase = "play"
	game.rules.powers[0].charge = [99, 4, 0]
	game.rules.powers[1].charge = [99, 99, 0]
	game.rules.players[1].stun = 1.4
	await create_timer(0.4).timeout
	await capture("preview-screen-portrait.png")
	root.size = Vector2i(1280, 720)
	await create_timer(0.8).timeout
	game.rules.players[1].stun = 1.4
	await capture("preview-screen-landscape.png")
	game.return_to_menu()
	quit(0)
