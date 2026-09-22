extends SceneTree
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS ", message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.skins.config_path = "res://tests/gallery-skins.tmp"
	game.power_shop.config_path = "res://tests/gallery-powers.tmp"
	check(game.arena.visible and not game.cup_screen.visible, "3D menu is the entry screen")
	var old = game.menu_level
	game.step_menu_level(1)
	game.show_menu_preview()
	check(game.arena.map.id == game.Campaign.LEVELS[game.menu_level].map.id, "Carousel shows selected map")
	check(game.arena.unit_skins[1] == game.Campaign.LEVELS[game.menu_level].boss, "Carousel shows its opponent")
	game.hud.open_skins()
	for i in range(11):
		game.hud.preview_skin(i)
		check(game.music.track == ("match" if i == 0 else "skin_%d" % i), "Skin theme %d" % i)
	game.hud.close_skins()
	check(game.music.track == "menu", "Closing gallery restores menu music")
	game.open_cup()
	check(game.cup_screen.visible and not game.arena.visible, "Cup remains accessible")
	game.cup_action("menu")
	check(game.arena.visible and not game.cup_screen.visible, "Return to map demonstrations")
	for path in [game.skins.config_path, game.power_shop.config_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	print("GALLERY failures=", failures)
	quit(failures)
