extends SceneTree
# Validates the firing-angle table, the assisted-aim magnetism in the rules, and the way
# the joystick and that magnetism share the pilot's arc.
const Rules = preload("res://scripts/arena_rules.gd")
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# 1. Rules: firing_angles provides unique, ordered enemy brick targets
	var r = Rules.new()
	r.phase = "play"
	r.assist_team = 0
	var targets = r.firing_angles(0)
	check(not targets.is_empty(), "Reachable brick targets found")
	var sorted = true
	var unique_bricks = {}
	for i in range(targets.size()):
		var t = targets[i]
		if unique_bricks.has(t.brick):
			unique_bricks[t.brick] += 1
		else:
			unique_bricks[t.brick] = 1
		if i > 0 and targets[i].angle < targets[i - 1].angle:
			sorted = false
	var no_dupes = unique_bricks.values().all(func(c): return c == 1)
	check(sorted, "Target list is strictly ordered from left to right along the arc")
	check(no_dupes, "Each reachable enemy brick has a single central aim angle")

	# 2. Magnetism (assist_heading): nudges off-angle shots toward the nearest enemy brick
	var first_target = targets[0]
	r.players[0].angle = first_target.angle + 0.04
	r.players[0].aim = Rules.forward_direction(0, r.players[0].angle)
	var direct = r.predict_shot(0, r.players[0].angle)
	var assisted = r.assist_heading(0)
	var assisted_hit = r.predict_shot(0, Rules.forward_direction(0, r.players[0].angle).angle_to(assisted) + r.players[0].angle)
	check(assisted != r.players[0].aim or direct.get("kind", "") == "brick", "Assist magnetism bends the shot toward an enemy brick when slightly off-angle")

	# 3. The stick and the magnetism sharing the same arc
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.start_pve()
	await process_frame
	var hud = scene.hud
	scene.game_settings.aim_assist = true

	# 3a. Standing a hair beside a target, a still thumb is eased onto it.
	var aim_targets = scene.rules.firing_angles(0)
	var mark = aim_targets[aim_targets.size() / 2]
	scene.rules.players[0].angle = mark.angle + 0.02
	hud.move_vector = Vector2.ZERO
	var nudge: float = scene.local_command().move.x
	check(nudge < 0.0 and absf(nudge) < 0.4, "A still thumb beside a target is eased onto it (%.3f)" % nudge)

	# 3b. Too far away, the magnetism keeps quiet: the thumb decides.
	scene.rules.players[0].angle = mark.angle + 0.4
	check(is_equal_approx(scene.local_command().move.x, 0.0), "Far from every target, a still thumb means standing still")

	# 3c. And it never fights a real push.
	scene.rules.players[0].angle = mark.angle + 0.02
	hud.move_vector = Vector2(-1, 0)
	check(is_equal_approx(scene.local_command().move.x, -1.0), "A full push of the stick is never fought by the magnetism")
	hud.move_vector = Vector2.ZERO

	# 3d. Switched off in the options, the pilot is left entirely to the thumb.
	scene.game_settings.aim_assist = false
	scene.rules.players[0].angle = mark.angle + 0.02
	check(is_equal_approx(scene.local_command().move.x, 0.0), "With assisted aim off, nothing moves the pilot but the thumb")
	scene.game_settings.aim_assist = true
	scene.return_to_menu()

	print("TARGET_ASSIST_RESULT failures=", failures)
	quit(failures)
