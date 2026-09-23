extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot(id: String) -> void:
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-story-" + id + ".png")
func run() -> void:
	root.size = Vector2i(540, 960)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if root.focus_exited.is_connected(game.pause_pve): root.focus_exited.disconnect(game.pause_pve)
	game.skins.config_path = "res://tests/story-capture-skins.tmp"
	game.power_shop.config_path = "res://tests/story-capture-powers.tmp"
	game.cup = preload("res://scripts/cup.gd").new()
	game.cup.path = "res://tests/story-capture.tmp"
	game.cup_screen.cup = game.cup
	await shot("menu")
	game.open_cup()
	game.cup_screen.tab = 1
	game.cup_screen.refresh()
	await shot("tree")
	for n in range(5):
		game.start_cup()
		game.pause_ai = true
		await shot("arena-%d" % n)
		game.return_to_menu()
		game.cup.complete([2, n % 2])
	game.open_cup()
	game.cup_screen.tab = 2
	game.cup_screen.refresh()
	await shot("boss-cover")
	var journal = game.cup_screen.content.get_child(0)
	journal.edition_number = 4
	journal.front()
	await shot("upset-cover")
	journal.edition_number = 1
	journal.front()
	await shot("action-cover")
	game.cup_screen.tab = 1
	game.cup_screen.refresh()
	await shot("tree-boss")
	game.queue_free()
	await process_frame
	quit()
