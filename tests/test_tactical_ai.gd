extends SceneTree
const Rules = preload("res://scripts/arena_rules.gd")
const IDLE = {"move": Vector2.ZERO, "fire": false}
var failures = 0
var checks = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func active():
	var r = Rules.new()
	r.phase = "play"
	return r

func projectile(r, owner: int, position: Vector2, velocity: Vector2, damage: int = 1) -> Dictionary:
	var b = {"id": r.next_id, "owner": owner, "p": position, "v": velocity, "bounces": 1, "damage": damage, "boosted": damage == 2, "ttl": Rules.BALL_LIFE}
	r.next_id += 1
	r.balls.append(b)
	return b

func _init() -> void:
	for owner in [0, 1]:
		for damage in [1, 2]:
			var r = active()
			var brick: Dictionary = r.bricks[owner * 40]
			for other in r.bricks:
				other.alive = other.id == brick.id
			brick.hp = 1
			var heading = Vector2.DOWN.rotated(brick.rotation)
			if (brick.p - heading).length() > brick.p.length():
				# Start on the arena side of the brick, travelling towards its wall.
				heading = -heading
			var b = projectile(r, owner, brick.p - heading * 0.8, heading * Rules.BALL_SPEED, damage)
			# Stop just past the brick, before the wall behind it.
			r.advance_ball(b, 0.95 / Rules.BALL_SPEED)
			check(brick.hp == 1 and brick.alive and r.balls.has(b) and r.events.is_empty(), "Own brick lets a reflected shot pass through unharmed: team %d, damage %d" % [owner, damage])
	var r = active()
	var b = projectile(r, 0, Vector2(0, 2.4), Vector2.UP * Rules.BALL_SPEED)
	r.advance_ball(b, 0.05)
	check(r.balls.has(b) and b.bounces == 2, "A long-travelled ball still reflects on an obstacle")
	# Walls no longer consume anything: the same ball crosses the arena over and over.
	for crossing in range(12):
		b.p = Vector2(Rules.HALF_WIDTH - 0.2, 1.6)
		b.v = Vector2.RIGHT * Rules.BALL_SPEED
		r.advance_ball(b, 0.02)
		check(r.balls.has(b) and b.v.x < 0, "Wall %d reflects the shot instead of ending it" % crossing)
		b.p = Vector2(-(Rules.HALF_WIDTH - 0.2), 1.6)
		b.v = Vector2.LEFT * Rules.BALL_SPEED
		r.advance_ball(b, 0.02)
	check(r.balls.has(b) and b.bounces >= 24, "Twenty-four wall contacts later the shot is still alive (%d bounces)" % b.bounces)
	r = active()
	b = projectile(r, 0, Vector2(0, 2.4), Vector2.UP * Rules.BALL_SPEED, 2)
	r.advance_ball(b, 0.05)
	check(b.damage == 2 and b.boosted and r.balls.has(b), "An obstacle rebound keeps the boost damage")
	var replica = Rules.new()
	replica.apply_snapshot(r.snapshot())
	check(replica.balls[0].bounces == b.bounces and replica.balls[0].damage == 2, "PvP snapshot retains the bounce count and boost damage")
	b.ttl = 0.01
	r.step(0.02, [IDLE, IDLE])
	check(r.balls.is_empty(), "The safety lifetime still clears a shot that never reaches a target")
	r = active()
	var state: Dictionary = r.snapshot().duplicate(true)
	var original_events: Array = r.events.duplicate(true)
	for index in range(49):
		r.predict_shot(1, -0.6 + index * 0.025)
	check(r.snapshot() == state and r.events == original_events and r.next_id == 0, "Trajectory planning cannot change health, scores, stun, projectiles or events")
	# Fire control checks the actual current angle, not a remote target angle.
	r.obstacles.clear()
	check(not r.ai_command().fire, "AI with a blocked central goal does not shoot at the idle defender aimlessly")
	r = active()
	r.players[1].stun = 0.5
	check(r.ai_command() == IDLE, "AI waits while stunned")
	r = active()
	var shots = 0
	var hits = 0
	var invalid_fires = 0
	var start = Time.get_ticks_usec()
	for tick in range(60 * 90):
		var command: Dictionary = r.ai_command()
		if command.fire:
			if r.shot_value(r.predict_shot(1, r.players[1].angle)) <= 0 or command.move != Vector2.ZERO:
				invalid_fires += 1
		r.step(1.0 / 60.0, [IDLE, command])
		for event in r.events:
			if event.kind == "shot" and event.team == 1:
				shots += 1
			if event.kind in ["brick", "brick_hit"] and event.team == 0:
				hits += 1
	print("AI_METRICS shots=", shots, " productive_hits=", hits, " goals=", r.scores[1], " enemy_bricks=", r.brick_count(0), " simulation_ms=", (Time.get_ticks_usec() - start) / 1000)
	check(invalid_fires == 0 and shots > 10, "Every AI shot has a predicted enemy-brick or scoring objective and a held firing angle")
	check(hits >= 10 and hits >= shots * 0.65, "AI consistently converts planned shots into enemy-brick hits")
	check(r.bricks.all(func(brick): return brick.team == 0 or brick.hp == 3), "AI leaves all its own bricks intact during extended play")
	check(r.scores[1] > 0, "AI clears all 40 enemy bricks and scores during extended play")
	r = active()
	r.players[1].angle = Rules.TRACK_LIMIT
	r.players[1].p = Rules.track_position(1, Rules.TRACK_LIMIT)
	projectile(r, 0, r.players[1].p + Vector2(-0.05, 2), Vector2.UP * Rules.BALL_SPEED)
	var escape: Dictionary = r.ai_command()
	check(escape.move.x < 0 and not escape.fire, "Threatened AI at track end dodges inward and postpones shooting")
	# Once open, target the goal around the defending pilot instead of continuing to farm stuns.
	r = active()
	for brick in r.bricks:
		if brick.team == 0:
			brick.alive = false
			brick.hp = 0
	for tick in range(60 * 15):
		r.step(1.0 / 60.0, [IDLE, r.ai_command()])
		if r.scores[1] > 0:
			break
	check(r.scores[1] == 1, "AI finds a scoring lane past the defender when the goal opens")
	print("TACTICAL_AI_RESULT ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)
