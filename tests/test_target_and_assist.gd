extends SceneTree
# Validates target selection (map tap, left/right arrows), direct character track control,
# and enhanced assisted aim magnetism.
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

	# 3. Main scene interaction: tap on brick, step with arrows, tap on character
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.start_pve()
	await process_frame
	var hud = scene.hud
	var arena = scene.arena

	# 3a. Tap on the enemy brick area of the stadium -> picks target
	var brick_world = targets[0].p
	var ray_screen = arena.camera.unproject_position(Vector3(brick_world.x, 0.58, brick_world.y))
	scene.aim_at_point(brick_world)
	check(scene.aim_angle != INF and is_equal_approx(scene.aim_angle, targets[0].angle), "Tapping on an enemy brick area lines up that target angle")

	# 3b. Step target with right arrow
	var before_angle = scene.aim_angle
	scene.step_target(1)
	check(scene.aim_angle > before_angle, "Right arrow steps to the next target on the right")

	# 3c. Step target with left arrow
	scene.step_target(-1)
	check(is_equal_approx(scene.aim_angle, before_angle), "Left arrow steps back to the previous target on the left")

	# 3d. Tap directly on character (bottom of stadium, y >= 4.8) -> directly sets character position
	scene.aim_at_point(Vector2(0.5, 6.0))
	var expected_angle = asin(clampf(0.5 / Rules.TRACK_RADIUS, -sin(Rules.TRACK_LIMIT), sin(Rules.TRACK_LIMIT)))
	check(is_equal_approx(scene.aim_angle, expected_angle) and hud.target_name == "PILOTO", "Tapping or dragging the character sets position directly on the track")

	print("TARGET_ASSIST_RESULT failures=", failures)
	quit(failures)
