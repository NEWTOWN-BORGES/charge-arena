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
	# The stick is grabbed wherever the thumb lands in the lower band.
	var grab = hud.move_home
	touch(hud, 0, grab, true)
	drag(hud, 0, grab + Vector2(55, 0))
	check(hud.move_vector.x > 0.8 and hud.move_id == 0 and hud.move_center == grab, "The stick takes the thumb where it lands and follows the drag")
	check(scene.local_command().fire, "The pilot fires on its own, with no button to hold")
	touch(hud, 0, grab + Vector2(55, 0), false)
	check(hud.move_vector == Vector2.ZERO and hud.move_id == -1 and hud.move_center == hud.move_home, "Releasing stops the movement and the stick returns home")
	touch(hud, 2, Vector2(900, 300), true)
	check(hud.move_id == -1, "Touches high on the screen, near the arena and the cards, are ignored")
	touch(hud, 2, Vector2(900, 300), false)
	var left_side = Vector2(90, hud.move_home.y)
	touch(hud, 3, left_side, true)
	check(hud.move_id == 3 and hud.move_center == left_side, "Either side of the band drives the stick")
	touch(hud, 3, left_side, false)
	touch(hud, 4, hud.power_centers[0], true)
	check(hud.power_request == 0 and hud.move_id == -1, "A tap on a power key asks for the power and never grabs the stick")
	hud.take_power()
	touch(hud, 5, hud.move_home + Vector2(20, 10), true)
	scene.return_to_menu()
	check(hud.move_id == -1 and hud.move_vector == Vector2.ZERO and hud.move_center == hud.move_home, "Leaving a match clears held touches")
	print("TOUCH_RESULT failures=", failures)
	quit(failures)
