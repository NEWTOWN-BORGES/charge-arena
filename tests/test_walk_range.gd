extends SceneTree
# The pilot has to be able to reach both ends of its arc, not only the angles where the
# rival's bricks happen to be: a tap on an arrow jumps to the next target, holding it
# walks all the way to the wall.
const Rules = preload("res://scripts/arena_rules.gd")
const TMP = "res://tests/walk-range.tmp"
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func hold(game, direction: int, seconds: float) -> void:
	# A finger on the arrow: pressed, held past the delay, then driven tick by tick.
	var hud = game.hud
	var touch = InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	touch.position = hud.aim_right if direction > 0 else hud.aim_left
	hud._input(touch)
	hud._process(hud.AIM_HOLD_DELAY + 0.01)
	for tick in range(roundi(seconds * 60)):
		game.rules.step(1.0 / 60, [game.local_command(), {"move": Vector2.ZERO, "fire": false}])
	touch.pressed = false
	hud._input(touch)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.power_shop.config_path = TMP
	game.start_pve()
	game.pause_ai = true
	await process_frame
	game.rules.phase = "play"
	var hud = game.hud

	# The targets only cover the middle of the arc, which is why stepping is not enough.
	var targets: Array = game.rules.firing_angles(0).map(func(o): return o.angle)
	check(targets.size() > 20, "The wall offers plenty of targets (%d)" % targets.size())
	check(targets.max() < Rules.TRACK_LIMIT - 0.2 and targets.min() > -Rules.TRACK_LIMIT + 0.2, "But they sit well inside the arc, far from either wall")

	var touch = InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = hud.aim_left
	hud._input(touch)
	check(hud.aim_hold() == 0 and hud.take_aim_step() == -1, "A quick tap only asks for the previous target")
	touch.pressed = false
	hud._input(touch)
	check(hud.aim_hold() == 0, "Letting go stops any walking")

	hold(game, -1, 3.0)
	check(game.rules.players[0].angle < -Rules.TRACK_LIMIT + 0.02, "Holding the left arrow walks the pilot to the left wall (%.2f de %.2f)" % [game.rules.players[0].angle, -Rules.TRACK_LIMIT])
	hold(game, 1, 6.0)
	check(game.rules.players[0].angle > Rules.TRACK_LIMIT - 0.02, "And the right arrow takes it all the way back to the other wall (%.2f)" % game.rules.players[0].angle)
	check(game.aim_angle == INF, "Walking by hand drops whatever target was chosen")
	game.return_to_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("WALK_RANGE_RESULT failures=", failures)
	quit(failures)
