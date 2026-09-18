extends SceneTree
# The pilot has to be able to reach both ends of its arc with the stick, well past the
# narrow band where the rival's bricks stand, and the aiming magnetism must only nudge.
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

func push(game, direction: float, seconds: float) -> void:
	# A thumb holding the stick to one side for a while.
	game.hud.move_vector = Vector2(direction, 0)
	for tick in range(roundi(seconds * 60)):
		game.rules.step(1.0 / 60, [game.local_command(), {"move": Vector2.ZERO, "fire": false}])
	game.hud.move_vector = Vector2.ZERO

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

	push(game, -1.0, 3.0)
	check(game.rules.players[0].angle < -Rules.TRACK_LIMIT + 0.02, "Holding the stick left walks the pilot to the left wall (%.2f de %.2f)" % [game.rules.players[0].angle, -Rules.TRACK_LIMIT])
	push(game, 1.0, 6.0)
	check(game.rules.players[0].angle > Rules.TRACK_LIMIT - 0.02, "And to the right wall on the way back (%.2f)" % game.rules.players[0].angle)
	# Magnetism only nudges, and only with the thumb almost still.
	game.rules.players[0].angle = game.rules.firing_angles(0)[3].angle + 0.02
	game.hud.move_vector = Vector2.ZERO
	var pull: float = game.local_command().move.x
	game.hud.move_vector = Vector2(1.0, 0)
	var pushed: float = game.local_command().move.x
	game.hud.move_vector = Vector2.ZERO
	check(absf(pull) > 0.0 and absf(pull) < 0.4, "Standing beside a target, the pilot is eased onto it (%.2f)" % pull)
	check(is_equal_approx(pushed, 1.0), "A real push of the stick is never fought by the magnetism")
	game.return_to_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("WALK_RANGE_RESULT failures=", failures)
	quit(failures)
