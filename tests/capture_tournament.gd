extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot(name_value: String) -> void:
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tournament-" + name_value + ".png")
func run() -> void:
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.cup = preload("res://scripts/cup.gd").new()
	game.cup_screen.cup = game.cup
	game.skins.config_path = "user://capture-tournament-skins.cfg"
	game.power_shop.config_path = "user://capture-tournament-powers.cfg"
	game.open_cup()
	game.cup_screen.tab = 2
	game.cup_screen.refresh()
	await shot("opening")
	game.cup_screen.tab = 1
	game.cup_screen.refresh()
	game.cup_screen.tree_view.open_person("Aurel")
	await shot("favorite")
	game.cup_screen.tab = 0
	game.cup_screen.refresh()
	game.hud.open_skins()
	game.hud.preview_skin(11)
	await shot("skin")
	game.hud.close_skins()
	game.start_cup()
	game.rules.phase = "play"
	game.pause_ai = true
	game.rules.powers[1].charge[2] = game.rules.power_charge_cost(1, 2)
	game.rules.activate_power(1, 2)
	await shot("normal-ultimate")
	game.return_to_menu()
	for i in range(109): game.cup.complete([2, i % 2])
	game.open_cup()
	game.cup_screen.tab = 2
	game.cup_screen.refresh()
	await shot("upset")
	game.cup_screen.tab = 0
	game.cup_screen.refresh()
	await shot("final")
	root.size = Vector2i(1280, 720)
	await shot("landscape")
	game.queue_free()
	await process_frame
	quit()
