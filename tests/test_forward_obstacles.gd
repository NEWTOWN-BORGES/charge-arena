extends SceneTree
const Rules = preload("res://scripts/arena_rules.gd")
const IDLE = [{"move": Vector2.ZERO, "fire": false}, {"move": Vector2.ZERO, "fire": false}]
var failures = 0
var count = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	count += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func active():
	var r = Rules.new()
	r.phase = "play"
	return r

func shot(r, pos: Vector2, direction: Vector2, bounced: int = 0) -> Dictionary:
	var b = {"id": r.next_id, "owner": 0, "p": pos, "v": direction * Rules.BALL_SPEED, "bounces": bounced, "damage": 1, "boosted": false, "ttl": Rules.BALL_LIFE}
	r.next_id += 1
	r.balls.append(b)
	return b

func run() -> void:
	var r = active()
	r.step(0.01, [{"move": Vector2.ZERO, "aim": Vector2.LEFT, "fire": true}, IDLE[1]])
	check(r.players[0].aim == Vector2.UP and r.balls[0].v.normalized() == Vector2.UP, "Stationary forward fire ignores an arbitrary aim command")
	r.step(0.15, [{"move": Vector2.RIGHT, "aim": Vector2.LEFT}, IDLE[1]])
	check(r.players[0].aim.x > 0 and r.players[0].aim.is_equal_approx(Rules.forward_direction(0, r.players[0].angle)), "Moving right rotates facing and firing together")
	var heading: Vector2 = r.players[0].aim
	r.step(0.1, [{"move": Vector2.ZERO, "aim": Vector2.DOWN}, IDLE[1]])
	check(r.players[0].aim == heading, "Stopping preserves facing regardless of external aim")
	r.shoot(0)
	check(r.balls.back().v.normalized().is_equal_approx(heading), "Projectile follows the pilot's fixed facing exactly")
	check(Rules.forward_direction(0, 0).is_equal_approx(-Rules.forward_direction(1, 0)), "Opposite pilots face into the arena")
	check(r.obstacles.size() == 2, "Exactly two moving obstacles exist")
	var before = r.obstacles.duplicate(true)
	r.step(0.25, IDLE)
	check(r.obstacles[0].p.x != before[0].p.x and r.obstacles[1].p.x != before[1].p.x and r.obstacles[0].p.y == before[0].p.y and r.obstacles[1].p.y == before[1].p.y, "Both obstacles move horizontally without changing lanes")
	var bounded = true
	for i in range(1000):
		for n in range(2):
			bounded = bounded and absf(Rules.obstacle_position(n, i * 0.02).x) <= Rules.OBSTACLE_TRAVEL + 0.001
	check(bounded, "Horizontal travel reverses within the intended bounds")
	r = active()
	var b = shot(r, Vector2(0, 2.4), Vector2.UP)
	r.advance_ball(b, 0.05)
	check(b.bounces == 1 and b.v.y > 0 and not b.boosted, "Obstacle reflects the first hit without changing normal damage")
	check(is_equal_approx(b.v.length(), Rules.BALL_SPEED), "Obstacle reflection preserves projectile speed")
	# Own shots never hit their pilot: follow the rebound until it is past the shooter.
	for i in range(60):
		if not r.balls.has(b) or b.p.y > r.players[0].p.y + 0.3:
			break
		r.advance_ball(b, 0.01)
	check(r.balls.has(b) and b.p.y > r.players[0].p.y and r.players[0].stun == 0, "A real obstacle rebound passes through its own shooter without stun")
	r.step(0.1, [{"move": Vector2.RIGHT, "fire": true}, IDLE[1]])
	check(r.players[0].angle > 0 and r.balls.any(func(other): return other.id != b.id), "The shooter keeps moving and firing while its rebound passes")
	r = active()
	b = shot(r, Vector2(0, 2.4), Vector2.UP, 1)
	r.advance_ball(b, 0.05)
	check(r.balls.size() == 1 and b.bounces == 2, "An already bounced shot keeps going after the obstacle")
	r = active()
	r.shoot(0)
	r.advance_ball(r.balls[0], 0.01)
	check(r.players[0].stun == 0 and r.balls.size() == 1, "A freshly emitted shot does not stun its owner at the muzzle")
	# An obstacle crossing the ray between start/end positions must still be detected.
	r = active()
	r.obstacles[1].previous = Vector2(-1, 1.25)
	r.obstacles[1].p = Vector2(1, 1.25)
	r.obstacles[1].v = Vector2(20, 0)
	b = shot(r, Vector2(0, 2.1), Vector2.UP)
	r.advance_ball(b, 0.1, true)
	check(b.bounces == 1, "Relative swept collision detects a moving obstacle crossing a shot")
	var replica = Rules.new()
	replica.apply_snapshot(r.snapshot())
	check(replica.obstacles == r.obstacles and replica.obstacle_time == r.obstacle_time, "Network state contains authoritative obstacle positions and phase")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_pve()
	game.set_physics_process(false)
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(20, 20)
	game._unhandled_input(click)
	var first: Dictionary = game.local_command()
	var motion = InputEventMouseMotion.new()
	motion.position = Vector2(1100, 500)
	game._unhandled_input(motion)
	check(first == game.local_command() and first.fire and not first.has("aim"), "Mouse motion cannot steer and left click only requests firing")
	click.pressed = false
	game._input(click)
	check(not game.local_command().fire, "Mouse release clears held fire even over UI")
	game.arena.update_state(game.rules, 0, 0.016)
	check(game.arena.obstacle_nodes.size() == 2, "Both colliders have visible 3D obstacle models")
	print("FORWARD_OBSTACLES_RESULT ", count - failures, "/", count, " passed")
	quit(1 if failures else 0)
