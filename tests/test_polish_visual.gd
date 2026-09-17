extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png("res://" + path)
	print("SCREENSHOT ", path, " result=", error)
	if error != OK:
		quit(1)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.video.configure(120, 2, false, true)
	game.video.apply(root, game.arena)
	game.hud.sync_video(game.video)
	await create_timer(0.8).timeout
	await capture("preview-menu-r06.png")
	game.hud.open_video()
	await create_timer(0.2).timeout
	await capture("preview-settings-r06.png")
	game.hud.close_video()
	game.start_pve()
	await create_timer(4.0).timeout
	await capture("preview-gameplay-r06.png")
	root.size = Vector2i(1200, 554)
	await create_timer(0.5).timeout
	await capture("preview-mobile-r06.png")
	for pair in [[60, 0], [90, 1], [120, 2]]:
		game.video.configure(pair[0], pair[1], false, true)
		game.video.apply(root, game.arena)
		await create_timer(1.0).timeout
		var start = Time.get_ticks_usec()
		var frames = Engine.get_process_frames()
		var draw_sum = 0.0
		while Time.get_ticks_usec() - start < 3000000:
			await process_frame
			draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var count = Engine.get_process_frames() - frames
		print("RENDER_METRICS target=", pair[0], " quality=", pair[1], " observed_fps=", snappedf(count * 1000000.0 / (Time.get_ticks_usec() - start), 0.1), " average_draws=", roundi(draw_sum / max(count, 1)))
	quit(0)
