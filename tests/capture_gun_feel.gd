extends SceneTree
# The shot as it is seen: muzzle, floor light, round, impact, a broken brick
# (needs a GPU; omit --headless).

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", path, " result=", root.get_texture().get_image().save_png("res://" + path))

func run() -> void:
	root.size = Vector2i(720, 1440)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.8).timeout
	game.game_settings.auto_fire = false
	game.hud.sync_game(game.game_settings)
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.start_pve()
	game.pause_ai = true
	while game.rules.phase != "play":
		await process_frame
	await create_timer(0.3).timeout
	game.pending_clicks += 1
	for n in range(2):
		await physics_frame
	await capture("preview-gunfeel-1-muzzle.png")
	await create_timer(0.45).timeout
	# Break one brick in front of the local pilot to see the destruction.
	for i in range(game.rules.bricks.size()):
		var b = game.rules.bricks[i]
		if b.team == 1 and b.alive:
			game.rules.damage_brick(i, 9, 0, b.p, false, Vector2.UP)
			break
	game.play_events()
	await process_frame
	await process_frame
	await capture("preview-gunfeel-2-break.png")
	for i in range(game.rules.bricks.size()):
		var b = game.rules.bricks[i]
		if b.team == 1 and b.alive and i % 2 == 0:
			game.rules.damage_brick(i, 1, 0, b.p, false, Vector2.UP)
			if b.hp == 1: continue
			game.rules.damage_brick(i, 1, 0, b.p, false, Vector2.UP)
	await create_timer(0.6).timeout
	await capture("preview-gunfeel-3-cracks.png")
	quit(0)
