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
	# Aiming is by target now, and only through the two keys: touching the stadium does
	# nothing, which is what keeps the frame from stalling on a drag.
	var spot = hud.arena_rect.get_center()
	touch(hud, 0, spot, true)
	check(hud.take_target() == Vector2.INF and hud.take_aim_step() == 0, "Touching the stadium no longer aims")
	check(scene.local_command().fire, "The pilot fires on its own, with no button to hold")
	drag(hud, 0, spot + Vector2(40, 10))
	check(hud.take_target() == Vector2.INF, "Dragging over the stadium does nothing either")
	touch(hud, 0, spot + Vector2(40, 10), false)
	touch(hud, 1, hud.aim_right, true)
	check(hud.take_aim_step() == 1 and hud.take_aim_step() == 0, "The right key asks for the next target, once")
	touch(hud, 1, hud.aim_right, false)
	touch(hud, 2, hud.aim_left, true)
	check(hud.take_aim_step() == -1, "The left key asks for the previous one")
	touch(hud, 2, hud.aim_left, false)
	check(hud.arrow_at(hud.aim_left) == -1 and hud.arrow_at(hud.aim_right) == 1 and hud.arrow_at(hud.power_centers[0]) == 0, "Only the keys themselves answer to a tap")
	touch(hud, 4, hud.power_centers[0], true)
	check(hud.power_request == 0 and hud.take_target() == Vector2.INF, "A tap on a power key asks for the power and never picks a target")
	hud.take_power()
	touch(hud, 5, hud.arena_rect.get_center(), true)
	scene.return_to_menu()
	check(hud.take_target() == Vector2.INF and hud.take_aim_step() == 0, "Leaving a match clears anything still held")
	print("TOUCH_RESULT failures=", failures)
	quit(failures)
