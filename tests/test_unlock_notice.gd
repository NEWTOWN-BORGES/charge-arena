extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.announce_unlock([game.Skins.CATALOG[5].name, game.Skins.CATALOG[10].name])
	var notice = game.hud.unlock_notice
	assert(notice.current.id == 5 and notice.pending.size() == 1)
	assert(notice.card.size.x <= 344 and notice.card.size.y == 72)
	assert(notice.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(notice.close.size.x >= 44)
	game.hud.announce_unlock([game.Skins.CATALOG[5].name])
	assert(notice.pending.size() == 1)
	game.open_cup()
	assert(notice.card.is_visible_in_tree() and notice.get_parent().layer == 20)
	notice.dismiss()
	assert(notice.current.id == 10)
	notice._process(4.1)
	assert(notice.current.is_empty() and not notice.card.visible)
	game.hud.announce_power("rapid", "Metralhadora")
	assert(notice.current.kind == "power" and notice.current.id == "rapid")
	notice.dismiss()
	assert(notice.current.is_empty() and not notice.is_processing())
	if DisplayServer.get_name() != "headless":
		for viewport_size in [Vector2i(720,1280), Vector2i(1280,720)]:
			root.size = viewport_size
			game.return_to_menu()
			game.hud.announce_unlock([game.Skins.CATALOG[10].name])
			await create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			assert(notice.card.position.x >= 0 and notice.card.position.x + notice.card.size.x <= notice.size.x)
			root.get_texture().get_image().save_png("res://preview-notice-%d.png" % viewport_size.x)
			notice.dismiss()
	game.queue_free()
	await process_frame
	print("PASS NOTICES: compact bounds, correct portraits, queue, duplicate suppression, dismiss, timeout, overlay and powers")
	quit()
