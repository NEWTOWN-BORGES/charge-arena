extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func shot(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-cup-" + name_value + ".png")
func run() -> void:
	root.size = Vector2i(540, 960)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.power_shop.config_path = "res://tests/cup-capture-powers.tmp"
	game.skins.config_path = "res://tests/cup-capture-skins.tmp"
	game.cup = load("res://scripts/cup.gd").new()
	game.cup_screen.cup = game.cup
	game.cup_screen.refresh()
	await create_timer(0.8).timeout
	await shot("home")
	game.hud.open_video()
	await create_timer(0.2).timeout
	await shot("options")
	game.hud.close_video()
	for i in range(8):
		game.cup.complete([2, 0])
	game.cup_screen.tab = 1
	game.cup_screen.refresh()
	await create_timer(0.4).timeout
	await shot("tree")
	game.cup_screen.tab = 2
	game.cup_screen.refresh()
	await create_timer(0.4).timeout
	await shot("news")
	game.cup.wins = 10
	game.start_cup()
	game.pause_ai = true
	game.pve_paused = true
	game.rules.phase = "play"
	game.pve_paused = false
	await create_timer(0.4).timeout
	await shot("arena")
	game.arena.explosion(Vector2(0, 0), 1.65)
	await create_timer(0.12).timeout
	await shot("effect")
	game.return_to_menu()
	root.size = Vector2i(1280, 720)
	game.cup_screen.tab = 0
	game.cup_screen.refresh()
	await create_timer(0.4).timeout
	await shot("wide")
	game.hud.open_video()
	await create_timer(0.2).timeout
	await shot("options-wide")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.power_shop.config_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.skins.config_path))
	quit()
