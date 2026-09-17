extends SceneTree
var failures = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func touch(hud, id: int, position: Vector2, down: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.index = id
	event.position = position
	event.pressed = down
	hud._input(event)

func drag(hud, id: int, position: Vector2) -> void:
	var event = InputEventScreenDrag.new()
	event.index = id
	event.position = position
	hud._input(event)

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.start_pve()
	await process_frame
	var hud = scene.hud
	touch(hud, 0, Vector2(120, 560), true)
	drag(hud, 0, Vector2(175, 560))
	var spot = Vector2(900, 800)
	touch(hud, 1, spot, true)
	check(hud.move_vector.x > 0.8 and hud.touch_fire and hud.fire_center == spot, "Two fingers: the stick moves and a tap anywhere on the lower right fires at once")
	touch(hud, 0, Vector2(175, 560), false)
	check(hud.move_vector == Vector2.ZERO and hud.touch_fire, "Releasing movement keeps the firing finger active")
	drag(hud, 1, spot + Vector2(140, 60))
	check(hud.touch_fire and hud.fire_center == spot + Vector2(140, 60), "The fire button follows the thumb while it slides")
	touch(hud, 1, spot + Vector2(140, 60), false)
	check(not hud.touch_fire and hud.fire_id == -1 and hud.fire_center == hud.fire_home, "Releasing stops firing and the button returns home")
	touch(hud, 2, Vector2(900, 300), true)
	check(not hud.touch_fire, "Touches high on the screen, near the arena and buttons, do not fire")
	touch(hud, 2, Vector2(900, 300), false)
	touch(hud, 3, Vector2(520, 900), true)
	check(not hud.touch_fire and hud.move_id == 3, "The left half still belongs to the movement stick")
	touch(hud, 3, Vector2(520, 900), false)
	touch(hud, 4, hud.fire_home, true)
	check(hud.touch_fire and hud.fire_center == hud.fire_home, "Tapping the resting fire button still fires")
	scene.return_to_menu()
	check(hud.move_id == -1 and hud.fire_id == -1 and not hud.touch_fire and hud.fire_center == hud.fire_home, "Leaving a match clears held touches")
	print("TOUCH_RESULT failures=", failures)
	quit(failures)
