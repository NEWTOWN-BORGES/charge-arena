extends SceneTree

var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func swipe(hud, from: Vector2, to: Vector2) -> void:
	var t_down = InputEventScreenTouch.new()
	t_down.index = 0
	t_down.pressed = true
	t_down.position = from
	hud._input(t_down)

	var t_up = InputEventScreenTouch.new()
	t_up.index = 0
	t_up.pressed = false
	t_up.position = to
	hud._input(t_up)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	await process_frame

	var hud = game.hud
	check(hud.menu_page == 0, "Initial menu page is 0 (Campanha)")
	check(hud.page_containers.size() == 6, "Menu has 6 page containers")
	check(hud.page_buttons.size() == 6, "Menu has 6 page action buttons")
	check(hud.page_containers[0].visible, "Page 0 container is visible")
	check(not hud.page_containers[1].visible, "Page 1 container is hidden initially")

	var middle = hud.swipe_area().get_center()

	# Vertical swipe UP (dragging fingers up = feed down, moves to page 1)
	swipe(hud, middle + Vector2(0, 100), middle - Vector2(0, 100))
	check(hud.menu_page == 1, "Vertical swipe up moves to Page 1 (Taça Aurora)")
	check(hud.page_containers[1].visible and not hud.page_containers[0].visible, "Page 1 container is visible")
	check(game.arena.map.id == "taca_colosseum", "Arena updates to Taça Colosseum on Page 1")

	# Vertical swipe UP to Page 2
	swipe(hud, middle + Vector2(0, 100), middle - Vector2(0, 100))
	check(hud.menu_page == 2, "Vertical swipe up moves to Page 2 (Jogo Rápido)")
	check(hud.page_containers[2].visible, "Page 2 container is visible")

	# Vertical swipe DOWN back to Page 1
	swipe(hud, middle - Vector2(0, 100), middle + Vector2(0, 100))
	check(hud.menu_page == 1, "Vertical swipe down moves back to Page 1")

	# Tap TikTok indicator directly (Page 4: Skins)
	var strip_x = hud.size.x - 22.0
	var strip_cy = hud.size.y * 0.45
	var spacing = 26.0
	var start_y = strip_cy - (hud.MENU_PAGE_COUNT - 1) * 0.5 * spacing
	var page4_y = start_y + 4 * spacing
	var tap = InputEventScreenTouch.new()
	tap.index = 0
	tap.pressed = true
	tap.position = Vector2(strip_x, page4_y)
	hud._input(tap)
	check(hud.menu_page == 4, "Tapping indicator 4 switches to Page 4 (Skins)")
	check(game.arena.map.id == "skins_bay", "Arena updates to Skins bay on Page 4")

	# Go back to Page 0
	hud.set_menu_page(0)
	check(hud.menu_page == 0, "Set menu page to 0 works")
	check(hud.page_containers[0].visible, "Page 0 container is visible again")

	# Horizontal swipe on Page 0 changes level
	var old_level = hud.menu_level
	swipe(hud, middle + Vector2(120, 0), middle - Vector2(120, 0))
	check(hud.menu_level == old_level + 1, "Horizontal swipe on Page 0 changes campaign level")

	print("MENU_TIKTOK_RESULT failures=", failures)
	game.queue_free()
	quit(failures)
