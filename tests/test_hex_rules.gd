extends SceneTree
const Rules = preload("res://scripts/arena_rules.gd")
const IDLE = [{"move": Vector2.ZERO, "fire": false}, {"move": Vector2.ZERO, "fire": false}]
var failures = 0
var checks = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func active():
	var r = Rules.new()
	r.phase = "play"
	return r

func ball(r, pos: Vector2, velocity: Vector2, bounces: int = 0, damage: int = 1) -> Dictionary:
	var b = {"id": r.next_id, "owner": 0, "p": pos, "v": velocity, "bounces": bounces, "ttl": 5.0, "damage": damage, "boosted": damage > 1}
	r.next_id += 1
	r.balls.append(b)
	return b

func clear_defense(r, team: int) -> void:
	for brick in r.bricks:
		if brick.team == team:
			brick.hp = 0
			brick.alive = false

func hit_brick(r, index: int, damage: int) -> void:
	var target: Dictionary = r.bricks[index]
	for b in r.bricks:
		if b.id != index:
			b.hp = 0
			b.alive = false
	var direction = Vector2(0, 1).rotated(target.rotation)
	var shot = ball(r, target.p - direction * 0.8, direction * Rules.BALL_SPEED, 0, damage)
	r.advance_ball(shot, 0.08)

func _init() -> void:
	var r = active()
	check(Rules.WALLS.size() == 6, "Map has six polygon walls")
	check(r.bricks.size() == 80 and r.brick_count(0) == 40 and r.brick_count(1) == 40, "Four triangular banks, 20 bricks each")
	check(r.bricks.all(func(b): return b.hp == 3), "Every brick starts with 3 lives")
	check(Rules.PLAYER_LIVES == 5 and Rules.STUN_SECONDS == 0.5 and r.players.all(func(p): return p.hp == 5), "Pilots start with five lives and use a half-second stun")
	var valid_layout = true
	for brick in r.bricks:
		for i in range(Rules.WALLS.size()):
			var a: Vector2 = Rules.WALLS[i]
			var edge: Vector2 = Rules.WALLS[(i + 1) % 6] - a
			valid_layout = valid_layout and edge.cross(brick.p - a) >= 0
	check(valid_layout, "All bricks lie inside the hexagon")
	var start: Vector2 = r.players[0].p
	r.step(0.2, [{"move": Vector2.RIGHT}, {"move": Vector2.LEFT}])
	check(r.players[0].p.x > 0 and r.players[0].p.y > start.y, "Horizontal movement follows a curve rather than a straight line")
	check(is_equal_approx(r.players[0].p.distance_to(Rules.goal_center(0)), Rules.TRACK_RADIUS) and is_equal_approx(r.players[1].p.distance_to(Rules.goal_center(1)), Rules.TRACK_RADIUS), "Both players stay on their own circular track")
	var before: Vector2 = r.players[0].p
	r.step(0.2, [{"move": Vector2.UP}, IDLE[1]])
	check(r.players[0].p == before, "Vertical input cannot leave the track")
	for i in range(120):
		r.step(1.0 / 60, [{"move": Vector2(100, 100)}, IDLE[1]])
	check(is_equal_approx(r.players[0].angle, Rules.TRACK_LIMIT), "Movement stops at the end of the arc")
	r = active()
	var b = ball(r, Vector2(Rules.HALF_WIDTH - 0.5, 1.6), Vector2(Rules.BALL_SPEED, 0))
	r.advance_ball(b, 0.07)
	check(r.balls.size() == 1 and b.bounces == 1 and b.v.x < 0 and not b.boosted, "Ordinary wall reflects once without boosting")
	check(is_equal_approx(b.v.length(), Rules.BALL_SPEED) and b.damage == 1, "Ordinary ricochet keeps normal speed and damage")
	b.p = Vector2(-(Rules.HALF_WIDTH - 0.2), 1.6)
	r.advance_ball(b, 0.05)
	check(r.balls.is_empty(), "Second ordinary wall collision consumes the ball")
	for side in [-1, 1]:
		r = active()
		b = ball(r, Vector2(side * (Rules.HALF_WIDTH - 1.0), 0), Vector2(side * Rules.BALL_SPEED, 0))
		r.advance_ball(b, 0.07)
		check(r.balls.size() == 1 and b.boosted and b.bounces == 1 and b.v.x * side < 0, "Booster reflects inward and consumes bounce: side " + str(side))
		check(is_equal_approx(b.v.length(), Rules.BALL_SPEED * Rules.BOOST_SPEED) and b.damage == 2, "Booster applies 1.65x speed and damage 2: side " + str(side))
	r = active()
	b = ball(r, Vector2(Rules.HALF_WIDTH - 1.0, 0), Vector2(Rules.BALL_SPEED, 0), 1)
	r.advance_ball(b, 0.07)
	check(r.balls.is_empty(), "A previously bounced ball cannot gain a second bounce from a booster")
	r = active()
	b = ball(r, Vector2(Rules.HALF_WIDTH - 1.0, 0), Vector2(Rules.BALL_SPEED, 0))
	r.advance_ball(b, 0.50)
	# At normal speed the ball would only just cross the centre line in this frame.
	check(b.bounces == 1 and b.p.x < -(Rules.HALF_WIDTH - 3.0) and b.v.length() > Rules.BALL_SPEED, "Boosted speed is used for the remainder of the same frame")
	r.advance_ball(b, 0.1)
	check(r.balls.is_empty(), "Second booster consumes a boosted shot instead of stacking boosts")
	r = active()
	b = ball(r, Vector2(Rules.HALF_WIDTH - 1.0, 0.4), Vector2(Rules.BALL_SPEED, 0))
	r.advance_ball(b, 0.07)
	check(b.boosted and b.v.y > 1, "Curved booster surface changes the reflection angle")
	r = active()
	hit_brick(r, 40, 1)
	check(r.bricks[40].hp == 2 and r.bricks[40].alive and r.balls.is_empty(), "Normal hit removes one life without destroying a healthy brick")
	check(Rules.brick_scale(2) < Rules.brick_scale(3), "First lost life shrinks the brick")
	hit_brick(r, 40, 1)
	check(r.bricks[40].hp == 1 and Rules.brick_scale(1) < Rules.brick_scale(2), "Second hit leaves a smaller brick with one life")
	hit_brick(r, 40, 1)
	check(r.bricks[40].hp == 0 and not r.bricks[40].alive, "Third normal hit destroys the brick")
	r = active()
	hit_brick(r, 40, 2)
	check(r.bricks[40].hp == 1 and r.bricks[40].alive, "Boosted hit removes two of three lives")
	hit_brick(r, 40, 1)
	check(not r.bricks[40].alive and r.scores == [0, 0], "One normal hit finishes a damaged brick without awarding a goal")
	r = active()
	for brick in r.bricks:
		if brick.id != 40:
			brick.hp = 0
			brick.alive = false
	var target: Dictionary = r.bricks[40]
	var direction = Vector2(0, 1).rotated(target.rotation)
	b = ball(r, target.p - direction * 1.0, direction * 100, 1, 2)
	r.advance_ball(b, 0.03)
	check(target.hp == 1 and r.balls.is_empty(), "Swept collision catches a fast boosted shot on a rotated brick")
	var local_graze = Rules.BRICK_EXTENT.x * 0.76 + Rules.BALL_RADIUS + 0.015
	for hp in [3, 1]:
		r = active()
		clear_defense(r, 0)
		clear_defense(r, 1)
		target = r.bricks[40]
		target.hp = hp
		target.alive = true
		b = ball(r, target.p + Vector2(local_graze, -0.5).rotated(target.rotation), Vector2(0, 10).rotated(target.rotation))
		r.advance_ball(b, 0.1)
		check(target.hp == 2 if hp == 3 else target.hp == 1, "Collision shape follows the shrinking width at HP=" + str(hp))
	r = active()
	for hit in range(4):
		b = ball(r, r.players[1].p + Vector2(0, 1), Vector2(0, -Rules.BALL_SPEED), 1, 2)
		r.advance_ball(b, 0.08)
	check(r.players[1].hp == 1 and r.players[1].stun == 0, "Four enemy hits leave one life without stunning")
	b = ball(r, r.players[1].p + Vector2(0, 1), Vector2(0, -Rules.BALL_SPEED), 1, 2)
	r.advance_ball(b, 0.08)
	check(r.players[1].hp == 0 and is_equal_approx(r.players[1].stun, Rules.STUN_SECONDS) and r.balls.is_empty(), "The fifth enemy hit triggers a half-second stun")
	before = r.players[1].p
	r.step(0.2, [IDLE[0], {"move": Vector2.RIGHT, "fire": true}])
	check(r.players[1].p == before and r.balls.is_empty(), "Stunned character cannot move on its arc or shoot")
	b = ball(r, before + Vector2(0, 1), Vector2(0, -Rules.BALL_SPEED))
	r.advance_ball(b, 0.08)
	check(is_equal_approx(r.players[1].stun, 0.3) and r.players[1].hp == 0 and r.balls.is_empty(), "Hits during stun do not extend it or remove more lives")
	for i in range(30):
		r.step(1.0 / 60, IDLE)
	r.step(0.1, [IDLE[0], {"move": Vector2.RIGHT, "fire": true}])
	check(r.players[1].stun == 0 and r.players[1].hp == 5 and r.players[1].p.x > before.x and r.balls.size() == 1, "Character restores five lives and resumes play after the stun")
	r = active()
	# Start just in front of the top shield, with the defender stepped aside, so only the shield is tested.
	var goal_shot = Rules.goal_center(1) + Vector2(0, Rules.GOAL_RADIUS + Rules.BALL_RADIUS + 0.3)
	r.players[1].p = Rules.track_position(1, Rules.TRACK_LIMIT)
	b = ball(r, goal_shot, Vector2(0, -Rules.BALL_SPEED))
	r.advance_ball(b, 0.04)
	check(r.scores == [0, 0] and b.bounces == 1 and b.v.y > 0, "Goal remains protected while its banks contain bricks")
	clear_defense(r, 1)
	b = ball(r, goal_shot, Vector2(0, -Rules.BALL_SPEED))
	r.advance_ball(b, 0.04)
	check(r.scores == [1, 0] and r.phase == "goal" and r.balls.is_empty(), "Clearing both banks unlocks the curved scoring zone")
	r.step(3.0, IDLE)
	check(r.phase == "countdown" and r.brick_count(1) == 40 and r.bricks.all(func(brick): return brick.hp == 3) and r.scores == [1, 0], "New round restores every brick's size/health and preserves the score")
	r.phase = "play"
	r.scores[0] = 2
	clear_defense(r, 1)
	r.players[1].p = Rules.track_position(1, Rules.TRACK_LIMIT)
	b = ball(r, goal_shot, Vector2(0, -Rules.BALL_SPEED))
	r.advance_ball(b, 0.04)
	check(r.phase == "finished" and r.winner == 0, "First player to 3 goals wins")
	r = active()
	hit_brick(r, 40, 2)
	ball(r, Vector2(0, 0), Vector2(0, -20), 1, 2)
	var replica = Rules.new()
	replica.apply_snapshot(r.snapshot())
	check(replica.bricks == r.bricks and replica.players == r.players and replica.balls == r.balls, "Network snapshot preserves arc positions, brick HP and boosted shots")
	check(var_to_bytes(r.snapshot()).compress(FileAccess.COMPRESSION_DEFLATE).size() < 1200, "Compact HP snapshot fits within a normal network packet")
	var network_state = r.network_snapshot()
	var network_replica = Rules.new()
	check(var_to_bytes(network_state).size() < 1200, "Uncompressed PvP packet fits within a normal network packet")
	check(network_replica.apply_network_snapshot(network_state), "Packed PvP state is accepted")
	check(network_replica.players[0].p.is_equal_approx(r.players[0].p) and network_replica.bricks[0].hp == r.bricks[0].hp and network_replica.balls.size() == r.balls.size(), "Packed PvP state reconstructs deterministic positions and gameplay")
	r = active()
	for i in range(60 * 45):
		r.step(1.0 / 60, [IDLE[0], r.ai_command()])
	var damage = 0
	for brick in r.bricks:
		if brick.team == 0:
			damage += 3 - brick.hp
	check(damage > 0 and r.players[1].p.is_finite() and r.balls.size() < 20, "AI follows its arc and damages enemy banks during a 45s simulation")
	print("RULES_RESULT ", checks - failures, "/", checks, " passed")
	quit(1 if failures > 0 else 0)
