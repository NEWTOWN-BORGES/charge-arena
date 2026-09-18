extends RefCounted
## Authoritative, renderer-independent simulation. World Vector2 maps to X/Z.
const MAP_SCALE = 1.24
const HALF_WIDTH = 6.0 * MAP_SCALE
const HALF_LENGTH = 6.93 * MAP_SCALE
const GOAL_RADIUS = 1.65
const TRACK_RADIUS = 2.6
const TRACK_LIMIT = 0.60
const SPEED = 5.0
const BALL_SPEED = 15.5
const FIRE_INTERVAL = 0.42
const PLAYER_LIVES = 5
const STUN_SECONDS = 0.5
const FACING_FACTOR = 1.35
## A generous default keeps the arena readable: obstacles create interesting
## ricochets without closing the player's firing lanes.
const OBSTACLE_RADIUS = 0.46
const OBSTACLE_TRAVEL = 2.15 * MAP_SCALE
const OBSTACLE_FREQUENCY = 0.62
const WIN_SCORE = 2
const BRICK_ROWS = [6, 5, 4, 3, 2]
const BRICK_COUNT = 40
const BRICK_LIVES = 3
const BRICK_EXTENT = Vector2(0.27, 0.14)
const BOOST_SPEED = 1.65
const BOOST_DAMAGE = 2
const BOOST_RADIUS = 1.10
const BOOST_CENTERS = [Vector2(-HALF_WIDTH - 0.75, 0), Vector2(HALF_WIDTH + 0.75, 0)]
const BALL_RADIUS = 0.14
const POWER_COSTS = [5, 10, 15]
const POWER_NAMES = ["EXPLOSÃO", "METRALHADORA", "RAJADA DE AR"]
const POWER_COLORS = [Color("ffb36b"), Color("ffe978"), Color("90e6ff")]
const EXPLOSION_RADIUS = 1.65
const EXPLOSION_DAMAGE = 2
const RAPID_SECONDS = 3.0
# Just under a sixth of a second: at 60 physics steps the burst lands exactly one round
# every 6 frames (0.1 s). A round 0.10 here would slip to a 7th frame and lose 4 rounds.
const RAPID_INTERVAL = 0.09
const AIR_PELLETS = 9
const AIR_SPREAD = 0.72
const MAX_BALLS = 128
const BALL_FIELDS = 11
# A shot ends on a target, not on a surface: walls, shields, boosters, barriers and bumpers
# all reflect it. This lifetime is only a safety net for a shot caught in a repeating path
# that would otherwise bounce for the rest of the match.
const BALL_LIFE = 12.0
# AI difficulty: extra pause after each shot, movement speed, whether it dodges and how
# long it waits between powers. The default (index 2, DIFÍCIL) is the full-strength
# planner used by the AI tests.
const AI_LEVELS = [
	{"fire_gap": 1.8, "move": 0.45, "dodge": false, "power_gap": 8.0},
	{"fire_gap": 0.95, "move": 0.65, "dodge": true, "power_gap": 5.0},
	{"fire_gap": 0.0, "move": 1.0, "dodge": true, "power_gap": 3.0},
]
const AI_POWER_GAP = 5.0
const WALLS = [Vector2(0, -HALF_LENGTH), Vector2(HALF_WIDTH, -HALF_LENGTH / 2), Vector2(HALF_WIDTH, HALF_LENGTH / 2), Vector2(0, HALF_LENGTH), Vector2(-HALF_WIDTH, HALF_LENGTH / 2), Vector2(-HALF_WIDTH, -HALF_LENGTH / 2)]
# Inner rounded walls: half thickness of the visible barrier.
const BARRIER_RADIUS = 0.16

var players: Array = []
var bricks: Array = []
var balls: Array = []
var obstacles: Array = []
var obstacle_time = 0.0
var scores: Array = [0, 0]
var phase = "countdown"
var timer = 2.5
var winner = -1
var next_id = 0
var events: Array = []
var elapsed = 0.0
var ai_target_angle = 0.0
var ai_next_scan = 0.0
var ai_scan_index = 0
var ai_best_score = -INF
var ai_next_fire_check = 0.0
var ai_next_power = 0.0
var ai_level = 2
# Campaign levels pass their own AI pace; empty uses AI_LEVELS[ai_level].
var ai_profile: Dictionary = {}
# Arena layout. Goals and pilot arcs never move, so rules, AI and network code stay
# shared; maps change the outline, boosters, obstacles, barriers and brick layout.
var map: Dictionary = {}
var walls: Array = WALLS.duplicate()
var boost_centers: Array = BOOST_CENTERS.duplicate()
var barriers: Array = []
var powers: Array = []
var power_rng = RandomNumberGenerator.new()

func _init() -> void:
	set_map(default_map())

static func default_map() -> Dictionary:
	return {
		"id": "aurora", "outline": "hex", "boosters": true, "bricks": "banks", "barriers": [],
		"obstacles": [
			{"kind": "slide", "center": Vector2(0, -1.25), "axis": Vector2.RIGHT, "travel": OBSTACLE_TRAVEL, "frequency": OBSTACLE_FREQUENCY, "phase": 0.0},
			{"kind": "slide", "center": Vector2(0, 1.25), "axis": Vector2.RIGHT, "travel": OBSTACLE_TRAVEL, "frequency": OBSTACLE_FREQUENCY, "phase": PI},
		],
	}

func set_map(new_map: Dictionary) -> void:
	map = new_map
	walls = outline_points(map.get("outline", "hex"))
	boost_centers = booster_centers(map)
	barriers = map.get("barriers", [])
	reset_match()

static func outline_points(kind: String) -> Array:
	# Same winding as WALLS, so every edge normal points into the arena. The goal ends
	# and the vertices at (±HALF_WIDTH, ±HALF_LENGTH / 2) are shared by every outline.
	var w = HALF_WIDTH
	var l = HALF_LENGTH
	match kind:
		"pinch":
			return [Vector2(0, -l), Vector2(w, -l / 2), Vector2(w - 1.9, -1.3), Vector2(w - 1.9, 1.3), Vector2(w, l / 2), Vector2(0, l), Vector2(-w, l / 2), Vector2(-w + 1.9, 1.3), Vector2(-w + 1.9, -1.3), Vector2(-w, -l / 2)]
		"wide":
			return [Vector2(0, -l), Vector2(w, -l / 2), Vector2(w + 1.3, -1.5), Vector2(w + 1.3, 1.5), Vector2(w, l / 2), Vector2(0, l), Vector2(-w, l / 2), Vector2(-w - 1.3, 1.5), Vector2(-w - 1.3, -1.5), Vector2(-w, -l / 2)]
		"octagon":
			return [Vector2(-2.3, -l), Vector2(2.3, -l), Vector2(w, -l / 2), Vector2(w, l / 2), Vector2(2.3, l), Vector2(-2.3, l), Vector2(-w, l / 2), Vector2(-w, -l / 2)]
	return WALLS.duplicate()

static func side_x(kind: String) -> float:
	return {"pinch": HALF_WIDTH - 1.9, "wide": HALF_WIDTH + 1.3}.get(kind, HALF_WIDTH)

static func booster_centers(layout: Dictionary) -> Array:
	if not layout.get("boosters", true):
		return []
	var side = side_x(layout.get("outline", "hex"))
	return [Vector2(-side - 0.75, 0), Vector2(side + 0.75, 0)]

static func outline_x_at(points: Array, y: float) -> float:
	# Widest boundary crossing at a given depth, for placing decoration outside the walls.
	var widest = 0.0
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		if (a.y - y) * (b.y - y) <= 0 and absf(b.y - a.y) > 0.00001:
			widest = maxf(widest, absf(lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))))
	return widest

static func point_inside(points: Array, point: Vector2) -> bool:
	var inside = false
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		if (a.y > point.y) != (b.y > point.y) and point.x < lerpf(a.x, b.x, (point.y - a.y) / (b.y - a.y)):
			inside = not inside
	return inside

func reset_match() -> void:
	scores = [0, 0]
	winner = -1
	elapsed = 0.0
	powers = [new_power_state(), new_power_state()]
	reset_round()

static func new_power_state() -> Dictionary:
	return {"charge": [0, 0, 0], "destroyed": 0, "rapid_time": 0.0}

func reset_round() -> void:
	# Keep earned charges between goals, but cancel a running burst at the round end.
	for state in powers:
		state.rapid_time = 0.0
	ai_target_angle = 0.0
	ai_next_scan = 0.0
	ai_scan_index = 0
	ai_best_score = -INF
	ai_next_fire_check = 0.0
	ai_next_power = 0.0
	players = [
		{"p": track_position(0, 0), "angle": 0.0, "aim": Vector2.UP, "hp": PLAYER_LIVES, "stun": 0.0, "cooldown": 0.0},
		{"p": track_position(1, 0), "angle": 0.0, "aim": Vector2.DOWN, "hp": PLAYER_LIVES, "stun": 0.0, "cooldown": 0.0}
	]
	balls.clear()
	bricks = make_bricks(map.get("bricks", "banks"))
	obstacle_time = 0.0
	obstacles.clear()
	var specs: Array = map.get("obstacles", [])
	for i in range(specs.size()):
		var pos = obstacle_at(i, 0)
		obstacles.append({"id": i, "p": pos, "previous": pos, "v": Vector2.ZERO, "radius": specs[i].get("radius", OBSTACLE_RADIUS)})
	phase = "countdown"
	timer = 2.5
	events.clear()

static func goal_center(team: int) -> Vector2:
	return Vector2(0, HALF_LENGTH * (1 if team == 0 else -1))

static func track_position(team: int, angle: float) -> Vector2:
	return goal_center(team) + Vector2(sin(angle), -cos(angle) * (1 if team == 0 else -1)) * TRACK_RADIUS

static func forward_direction(team: int, angle: float) -> Vector2:
	# Fixed facing for each arc position; the wider fan keeps the side boosters reachable.
	var facing = angle * FACING_FACTOR
	return Vector2(sin(facing), -cos(facing) * (1 if team == 0 else -1))

static func obstacle_position(index: int, time: float) -> Vector2:
	# Default arena's sliders; maps use obstacle_at.
	return Vector2(sin(time * OBSTACLE_FREQUENCY + index * PI) * OBSTACLE_TRAVEL, -1.25 if index == 0 else 1.25)

func obstacle_at(index: int, time: float) -> Vector2:
	return spec_position(map.obstacles[index], time)

static func spec_position(spec: Dictionary, time: float) -> Vector2:
	var center: Vector2 = spec.get("center", Vector2.ZERO)
	var wave: float = time * spec.get("frequency", 0.0) + spec.get("phase", 0.0)
	match spec.get("kind", "fixed"):
		"slide":
			return center + spec.get("axis", Vector2.RIGHT) * sin(wave) * spec.get("travel", 0.0)
		"orbit":
			return center + Vector2(cos(wave), sin(wave)) * spec.get("travel", 0.0)
	return center

static func brick_scale(hp: int) -> float:
	return [0.0, 0.52, 0.76, 1.0][clampi(hp, 0, BRICK_LIVES)]

static func make_bricks(layout: String = "banks") -> Array:
	# Forty bricks per team in every layout; team 0 first, mirrored for team 1.
	var result: Array = []
	for team in range(2):
		var sign_y = 1 if team == 0 else -1
		var goal = goal_center(team)
		match layout:
			"wall":
				# Two unbroken rows in front of the goal: a lane has to be carved first.
				for row in range(2):
					for column in range(20):
						add_brick(result, team, -1 if column < 10 else 1, Vector2((column - 9.5) * 0.56, goal.y - sign_y * (3.75 + row * 0.36)), 0.0)
			"arc":
				# Three concentric arcs hugging the goal.
				for ring in [[3.6, 13, 0.9], [4.2, 13, 0.88], [4.8, 14, 0.85]]:
					for column in range(ring[1]):
						var angle = lerpf(-ring[2], ring[2], column / float(ring[1] - 1))
						var tangent = Vector2(cos(angle), sin(angle) * sign_y)
						add_brick(result, team, -1 if angle < 0 else 1, goal + Vector2(sin(angle), -cos(angle) * sign_y) * ring[0], tangent.angle())
			"islands":
				# Four separate clusters with open lanes between them.
				for cluster in [Vector2(-4.0, 3.9), Vector2(-1.6, 4.6), Vector2(1.6, 4.6), Vector2(4.0, 3.9)]:
					for row in range(2):
						for column in range(5):
							add_brick(result, team, -1 if cluster.x < 0 else 1, Vector2(cluster.x + (column - 2) * 0.56, goal.y - sign_y * (cluster.y + row * 0.36)), 0.0)
			"chevron":
				# Two diagonal lines opening towards the middle of the arena.
				for side in [-1, 1]:
					var direction = Vector2(side * 0.94, -sign_y * 0.34)
					for row in range(2):
						for column in range(10):
							var pos = Vector2(side * (0.55 + column * 0.545), goal.y - sign_y * (3.6 + column * 0.197 + row * 0.36))
							add_brick(result, team, side, pos, direction.angle())
			_:
				for side in [-1, 1]:
					var along = Vector2(side * 0.8660254, -sign_y * 0.5)
					var inward = Vector2(-side * 0.5, -sign_y * 0.8660254)
					for row in range(BRICK_ROWS.size()):
						for column in range(BRICK_ROWS[row]):
							var pos = goal + (along * (2.6 + (row + column) * 0.6) + inward * (0.3 + row * 0.34)) * MAP_SCALE
							add_brick(result, team, side, pos, along.angle())
	return result

static func add_brick(result: Array, team: int, group: int, pos: Vector2, rotation: float) -> void:
	result.append({"id": result.size(), "team": team, "group": group, "p": pos, "rotation": rotation, "hp": BRICK_LIVES, "alive": true})

func step(dt: float, commands: Array) -> void:
	events.clear()
	elapsed += dt
	if phase != "play":
		if phase == "finished":
			return
		timer -= dt
		if timer <= 0:
			if phase == "goal":
				reset_round()
			else:
				phase = "play"
		return
	obstacle_time += dt
	for obstacle in obstacles:
		obstacle.previous = obstacle.p
		obstacle.p = obstacle_at(obstacle.id, obstacle_time)
		obstacle.v = (obstacle.p - obstacle.previous) / maxf(dt, 0.000001)
	for team in range(2):
		var p: Dictionary = players[team]
		# Snapping the last sliver keeps the burst a whole number of frames long: the
		# accumulated float residue would otherwise buy it one extra round.
		var burst_left: float = powers[team].rapid_time - dt
		powers[team].rapid_time = 0.0 if burst_left < dt * 0.5 else burst_left
		p.cooldown = maxf(0, p.cooldown - dt)
		var was_stunned: bool = p.stun > 0
		p.stun = maxf(0, p.stun - dt)
		if was_stunned and p.stun <= 0 and p.hp <= 0:
			p.hp = PLAYER_LIVES
		if p.stun > 0:
			continue
		var cmd: Dictionary = commands[team]
		var move: Vector2 = cmd.get("move", Vector2.ZERO)
		# Horizontal input moves along a fixed arc; vertical input never leaves it.
		p.angle = clampf(p.angle + clampf(move.x, -1, 1) * SPEED / TRACK_RADIUS * dt, -TRACK_LIMIT, TRACK_LIMIT)
		p.p = track_position(team, p.angle)
		p.aim = forward_direction(team, p.angle)
		activate_power(team, int(cmd.get("power", -1)))
		if powers[team].rapid_time > 0 and p.cooldown <= 0:
			shoot(team, 2)
		elif cmd.get("fire", false) and p.cooldown <= 0:
			shoot(team)
	for ball in balls.duplicate():
		if phase != "play":
			break
		if balls.has(ball):
			ball.ttl -= dt
			if ball.ttl <= 0:
				if ball.get("power", 0) == 1:
					explode(ball)
				balls.erase(ball)
			else:
				advance_ball(ball, dt, true)

func can_activate_power(team: int, index: int) -> bool:
	if team < 0 or team >= powers.size() or index < 0 or index >= POWER_COSTS.size():
		return false
	if phase != "play" or players[team].stun > 0 or powers[team].rapid_time > 0:
		return false
	return powers[team].charge[index] >= POWER_COSTS[index]

func activate_power(team: int, index: int) -> bool:
	if not can_activate_power(team, index):
		return false
	powers[team].charge[index] = 0
	var p: Dictionary = players[team]
	var heading = forward_direction(team, p.angle)
	events.append({"kind": "power", "power": index, "team": team, "p": p.p})
	match index:
		0:
			shoot(team, 1)
		1:
			powers[team].rapid_time = RAPID_SECONDS
			p.cooldown = 0.0
		2:
			# Stratified random spread leaves a useful fan, even on unlucky rolls.
			for pellet in range(AIR_PELLETS):
				var angle = lerpf(-AIR_SPREAD, AIR_SPREAD, pellet / float(AIR_PELLETS - 1))
				angle += power_rng.randf_range(-0.055, 0.055)
				spawn_ball(team, heading.rotated(angle), 3)
			p.cooldown = FIRE_INTERVAL
	return true

func credit_destroyed_brick(team: int) -> void:
	powers[team].destroyed += 1
	for index in range(POWER_COSTS.size()):
		var previous: int = powers[team].charge[index]
		powers[team].charge[index] = mini(previous + 1, POWER_COSTS[index])
		if previous < POWER_COSTS[index] and powers[team].charge[index] == POWER_COSTS[index]:
			events.append({"kind": "power_ready", "power": index, "team": team, "p": players[team].p})

func damage_brick(index: int, damage: int, owner: int, at: Vector2) -> void:
	var brick: Dictionary = bricks[index]
	if not brick.alive or brick.team == owner:
		return
	brick.hp = maxi(0, brick.hp - damage)
	brick.alive = brick.hp > 0
	events.append({"kind": "brick" if not brick.alive else "brick_hit", "p": at, "team": brick.team})
	if not brick.alive:
		credit_destroyed_brick(owner)

func damage_player(team: int, damage: int, at: Vector2) -> void:
	if players[team].stun > 0:
		return
	players[team].hp = maxi(0, players[team].hp - damage)
	events.append({"kind": "player_hit", "p": at, "team": team})
	if players[team].hp <= 0:
		players[team].stun = STUN_SECONDS
		events.append({"kind": "stun", "p": at, "team": team})

func explode(ball: Dictionary) -> void:
	for index in range(bricks.size()):
		var brick: Dictionary = bricks[index]
		if brick.alive and brick.team != ball.owner and brick.p.distance_to(ball.p) <= EXPLOSION_RADIUS:
			damage_brick(index, EXPLOSION_DAMAGE, ball.owner, brick.p)
	var enemy: int = 1 - int(ball.owner)
	if players[enemy].p.distance_to(ball.p) <= EXPLOSION_RADIUS:
		damage_player(enemy, EXPLOSION_DAMAGE, ball.p)
	events.append({"kind": "explosion", "p": ball.p, "team": ball.owner, "radius": EXPLOSION_RADIUS})

func shoot(team: int, power: int = 0) -> void:
	var p: Dictionary = players[team]
	p.aim = forward_direction(team, p.angle)
	p.cooldown = RAPID_INTERVAL if power == 2 else FIRE_INTERVAL
	spawn_ball(team, p.aim, power)
	events.append({"kind": "shot", "p": p.p, "team": team, "power": power})

func spawn_ball(team: int, heading: Vector2, power: int) -> void:
	# Shots no longer expire against a wall, so a full arena drops the oldest one instead
	# of silently refusing to fire.
	while balls.size() >= MAX_BALLS:
		balls.remove_at(0)
	balls.append({"id": next_id, "owner": team, "p": players[team].p + heading * 0.64, "v": heading * BALL_SPEED, "bounces": 0, "boosted": false, "damage": 1, "ttl": BALL_LIFE, "power": power})
	next_id += 1

func advance_ball(ball: Dictionary, dt: float, sweep_obstacles: bool = false, preview: bool = false, future_time: float = 0.0, shooter_position: Vector2 = Vector2.ZERO) -> Dictionary:
	# Prediction uses the same collisions, but only mutates its private projectile.
	var remaining = dt
	for _iteration in range(8):
		if remaining <= 0.00001:
			return {}
		var start: Vector2 = ball.p
		var travel: Vector2 = ball.v * remaining
		var best = 1.01
		var kind = ""
		var target = -1
		var normal = Vector2.ZERO
		var surface_velocity = Vector2.ZERO
		var bounds_min = start.min(start + travel) - Vector2.ONE * 0.50
		var bounds_max = start.max(start + travel) + Vector2.ONE * 0.50
		for i in range(bricks.size()):
			if not bricks[i].alive or bricks[i].team == ball.owner:
				continue
			var brick: Dictionary = bricks[i]
			if brick.p.x < bounds_min.x or brick.p.x > bounds_max.x or brick.p.y < bounds_min.y or brick.p.y > bounds_max.y:
				continue
			var t = segment_box((start - brick.p).rotated(-brick.rotation), travel.rotated(-brick.rotation), Vector2.ZERO, BRICK_EXTENT * brick_scale(brick.hp) + Vector2.ONE * BALL_RADIUS)
			if t >= 0 and t < best:
				best = t
				kind = "brick"
				target = i
		for team in range(2):
			if team == ball.owner:
				continue
			var player_position: Vector2 = shooter_position if preview and team == ball.owner else players[team].p
			var t = segment_circle(start, travel, player_position, 0.43 + BALL_RADIUS)
			if t >= 0 and t < best:
				best = t
				kind = "player"
				target = team
		# Sweep against moving bumpers in their relative frame, including post-bounce time.
		for obstacle in obstacles:
			var obstacle_start: Vector2 = obstacle.previous + obstacle.v * (dt - remaining) if sweep_obstacles else obstacle.p
			var movement: Vector2 = obstacle.v * remaining if sweep_obstacles else Vector2.ZERO
			if preview:
				obstacle_start = obstacle_at(obstacle.id, future_time + dt - remaining)
				movement = obstacle_at(obstacle.id, future_time + dt) - obstacle_start
			var t = segment_circle(start, travel - movement, obstacle_start, obstacle.get("radius", OBSTACLE_RADIUS) + BALL_RADIUS)
			if t >= 0 and t < best:
				best = t
				kind = "obstacle"
				normal = (start + travel * t - (obstacle_start + movement * t)).normalized()
				surface_velocity = movement / remaining if preview else (obstacle.v if sweep_obstacles else Vector2.ZERO)
		# Curved lateral accelerators reflect on their surface normal, not on a flat wall.
		for center in boost_centers:
			var t = segment_circle(start, travel, center, BOOST_RADIUS + BALL_RADIUS)
			if t >= 0 and t < best:
				best = t
				kind = "boost"
				normal = (start + travel * t - center).normalized()
		# The goal shield becomes a scoring zone after BOTH enemy banks are cleared.
		for team in range(2):
			var t = segment_circle(start, travel, goal_center(team), GOAL_RADIUS + BALL_RADIUS)
			if t >= 0 and t < best:
				best = t
				kind = "goal" if brick_count(team) == 0 else "wall"
				target = 1 - team
				normal = (start + travel * t - goal_center(team)).normalized()
		for barrier in barriers:
			var contact = sweep_capsule(start, travel, barrier.a, barrier.b, BARRIER_RADIUS + BALL_RADIUS)
			if contact.t < best:
				best = contact.t
				kind = "wall"
				normal = contact.normal
		for i in range(walls.size()):
			var a: Vector2 = walls[i]
			var edge: Vector2 = walls[(i + 1) % walls.size()] - a
			var denominator = travel.cross(edge)
			if absf(denominator) < 0.00001:
				continue
			var t = (a - start).cross(edge) / denominator
			var u = (a - start).cross(travel) / denominator
			if t >= 0 and t <= 1 and u >= 0 and u <= 1 and t < best:
				best = t
				kind = "wall"
				normal = Vector2(-edge.y, edge.x).normalized()
		if kind == "":
			ball.p += travel
			return {}
		ball.p = start + travel * best
		if preview and kind in ["brick", "player", "goal"]:
			return {"kind": kind, "target": target, "damage": ball.get("damage", 1)}
		match kind:
			"brick":
				damage_brick(target, int(ball.get("damage", 1)), ball.owner, ball.p)
				if ball.get("power", 0) == 1:
					explode(ball)
				balls.erase(ball)
				return {"kind": kind, "target": target}
			"player":
				# Enemy hits remove one life. At zero, the pilot is disabled briefly;
				# own shots are excluded from collision detection above.
				if ball.get("power", 0) == 1:
					explode(ball)
				else:
					damage_player(target, 1, ball.p)
				balls.erase(ball)
				return {"kind": kind, "target": target}
			"goal":
				scores[target] += 1
				winner = target
				phase = "finished" if scores[target] >= WIN_SCORE else "goal"
				timer = 2.2
				events.append({"kind": "goal", "p": ball.p, "team": target})
				balls.clear()
				return {"kind": kind, "target": target}
			"wall", "boost", "obstacle":
				# Every surface reflects, without limit: the shot keeps going until it
				# reaches a brick, a pilot or an open goal.
				ball.bounces += 1
				if kind == "obstacle":
					# Reflect relative to the moving surface, preserving the arcade shot speed.
					var shot_speed: float = ball.v.length()
					ball.v = ((ball.v - surface_velocity).bounce(normal) + surface_velocity).normalized() * shot_speed
				else:
					ball.v = ball.v.bounce(normal)
				if kind == "boost":
					ball.v = ball.v.normalized() * BALL_SPEED * BOOST_SPEED
					ball.boosted = true
					ball.damage = BOOST_DAMAGE
				ball.p += normal * 0.005
				if not preview:
					events.append({"kind": "boost" if kind == "boost" else "bounce", "p": ball.p, "team": ball.owner})
				remaining *= 1.0 - best
	return {}

func brick_count(team: int) -> int:
	var count = 0
	for brick in bricks:
		if brick.team == team and brick.alive:
			count += 1
	return count

func ai_command() -> Dictionary:
	if phase != "play" or players[1].stun > 0:
		return {"move": Vector2.ZERO, "fire": false}
	# Spread a fine search across frames instead of running a full planner every tick.
	if elapsed >= ai_next_scan:
		ai_next_scan = elapsed + 0.05
		if ai_scan_index == 0:
			ai_best_score = ai_angle_score(ai_target_angle)
		for _candidate in range(4):
			var angle = 0.0 if ai_scan_index == 0 else ceilf(ai_scan_index / 2.0) * 0.025 * (1 if ai_scan_index % 2 else -1)
			var score = ai_angle_score(angle)
			if score > ai_best_score + 0.05:
				ai_best_score = score
				ai_target_angle = angle
			ai_scan_index = (ai_scan_index + 1) % 49
			if ai_scan_index == 0:
				break
	var level: Dictionary = ai_profile if not ai_profile.is_empty() else AI_LEVELS[clampi(ai_level, 0, AI_LEVELS.size() - 1)]
	var p: Vector2 = players[1].p
	var dodge = 0.0
	for ball in balls:
		if ball.owner == 0 and ball.v.y < -1:
			var arrival: float = (p.y - ball.p.y) / ball.v.y
			if arrival > 0 and arrival < 0.5:
				var x: float = ball.p.x + ball.v.x * arrival
				if absf(x - p.x) < 0.85:
					dodge += 1.0 if p.x > x else -1.0
	if not level.dodge:
		dodge = 0.0
	var move = Vector2(clampf((ai_target_angle - players[1].angle) * 8, -1, 1) * level.move, 0)
	if dodge != 0:
		# At the track boundary, evade inward instead of getting stuck against the end.
		if absf(players[1].angle + dodge * 0.12) > TRACK_LIMIT:
			dodge = -signf(players[1].angle)
		move.x = clampf(dodge, -1, 1) * level.move
		return {"move": move, "fire": false}
	var fire = false
	var power = -1
	if players[1].cooldown <= 0 and elapsed >= ai_next_fire_check:
		ai_next_fire_check = elapsed + 0.10
		var outcome = predict_shot(1, players[1].angle)
		fire = shot_value(outcome) > 0
		if fire:
			# Hold this validated angle on the firing frame; movement is the only aiming.
			move = Vector2.ZERO
			ai_next_fire_check = elapsed + 0.10 + level.fire_gap
			power = ai_power(outcome, level)
		elif elapsed >= ai_next_power and can_activate_power(1, 2):
			# A wide fan needs no lined-up shot, so it covers the banks the boss cannot reach.
			power = 2
			ai_next_power = elapsed + float(level.get("power_gap", AI_POWER_GAP))
	return {"move": move, "fire": fire, "power": power}

func ai_power(outcome: Dictionary, level: Dictionary) -> int:
	# The boss only spends a power on a shot already worth taking, and the heavier
	# burst goes first so it does not sit unused behind the cheaper blast.
	if elapsed < ai_next_power or outcome.get("kind", "") != "brick":
		return -1
	for index in [1, 0]:
		if can_activate_power(1, index):
			ai_next_power = elapsed + float(level.get("power_gap", AI_POWER_GAP))
			return index
	return -1

func ai_angle_score(angle: float) -> float:
	var distance = absf(angle - players[1].angle)
	var delay = distance * TRACK_RADIUS / SPEED
	return shot_value(predict_shot(1, angle, delay)) - distance * 2.0

func shot_value(outcome: Dictionary) -> float:
	match outcome.get("kind", ""):
		"goal":
			return 100.0 if outcome.target == 1 else -100.0
		"brick":
			var brick: Dictionary = bricks[outcome.target]
			if brick.team == 0:
				return 10.0 + mini(brick.hp, outcome.damage) * 3.0 + (4.0 if brick.hp <= outcome.damage else 0.0)
		"player":
			if outcome.target == 1:
				return -100.0
	return 0.0

func predict_shot(team: int, angle: float, delay: float = 0.0) -> Dictionary:
	var origin = track_position(team, angle)
	var heading = forward_direction(team, angle)
	var probe = {"owner": team, "p": origin + heading * 0.64, "v": heading * BALL_SPEED, "bounces": 0, "damage": 1, "boosted": false}
	# Forecast obstacle motion; the opponent's future decisions remain unknown.
	for tick in range(80):
		var outcome = advance_ball(probe, 0.05, false, true, obstacle_time + delay + tick * 0.05, origin)
		if not outcome.is_empty():
			return outcome
	return {"kind": "expired"}

func predict_path(team: int, angle: float) -> Dictionary:
	# The shot this pilot would fire now, sampled finely enough to draw an aiming guide.
	var origin = track_position(team, angle)
	var heading = forward_direction(team, angle)
	var probe = {"owner": team, "p": origin + heading * 0.64, "v": heading * BALL_SPEED, "bounces": 0, "damage": 1, "boosted": false}
	var points = PackedVector2Array([probe.p])
	var step = 0.05
	for tick in range(80):
		var outcome = advance_ball(probe, step, false, true, obstacle_time + tick * step, origin)
		points.append(probe.p)
		if not outcome.is_empty():
			return {"points": points, "outcome": outcome}
	return {"points": points, "outcome": {"kind": "expired"}}

func snapshot() -> Dictionary:
	# Positions/rotations are deterministic; send only each brick's changing health.
	var hp = PackedByteArray()
	for brick in bricks:
		hp.append(brick.hp)
	return {"players": players.duplicate(true), "powers": powers.duplicate(true), "brick_hp": hp, "balls": balls.duplicate(true), "obstacles": obstacles.duplicate(true), "obstacle_time": obstacle_time, "scores": scores.duplicate(), "phase": phase, "timer": timer, "winner": winner, "elapsed": elapsed}

func apply_snapshot(data: Dictionary) -> void:
	players = data.players
	powers = data.powers.duplicate(true)
	for i in range(bricks.size()):
		bricks[i].hp = data.brick_hp[i]
		bricks[i].alive = bricks[i].hp > 0
	balls = data.balls
	obstacles = data.obstacles
	obstacle_time = data.obstacle_time
	scores = data.scores
	phase = data.phase
	timer = data.timer
	winner = data.winner
	elapsed = data.elapsed

func network_snapshot() -> Dictionary:
	# Flat packed arrays avoid DEFLATE and nested Variant allocation on every
	# network tick. Obstacles and player vectors are reconstructed deterministically.
	var player_data = PackedFloat32Array()
	for player in players:
		player_data.append_array([player.angle, player.hp, player.stun, player.cooldown])
	var hp = PackedByteArray()
	for brick in bricks:
		hp.append(brick.hp)
	var ball_data = PackedFloat32Array()
	for ball in balls:
		ball_data.append_array([ball.id, ball.owner, ball.p.x, ball.p.y, ball.v.x, ball.v.y, ball.bounces, 1.0 if ball.get("boosted", false) else 0.0, ball.get("damage", 1), ball.ttl, ball.get("power", 0)])
	var power_data = PackedFloat32Array()
	for state in powers:
		power_data.append_array([state.charge[0], state.charge[1], state.charge[2], state.destroyed, state.rapid_time])
	var phase_id = ["countdown", "play", "goal", "finished"].find(phase)
	var match_data = PackedFloat32Array([obstacle_time, scores[0], scores[1], phase_id, timer, winner, elapsed])
	return {"p": player_data, "h": hp, "b": ball_data, "m": match_data, "w": power_data}

func apply_network_snapshot(data: Dictionary) -> bool:
	if not data.has_all(["p", "h", "b", "m", "w"]):
		return false
	var player_data: PackedFloat32Array = data.p
	var hp: PackedByteArray = data.h
	var ball_data: PackedFloat32Array = data.b
	var match_data: PackedFloat32Array = data.m
	var power_data: PackedFloat32Array = data.w
	if player_data.size() != 8 or hp.size() != bricks.size() or match_data.size() != 7 or power_data.size() != 10 or ball_data.size() % BALL_FIELDS != 0 or ball_data.size() > MAX_BALLS * BALL_FIELDS:
		return false
	for packed in [player_data, ball_data, match_data, power_data]:
		for value in packed:
			if not is_finite(value):
				return false
	for offset in range(0, ball_data.size(), BALL_FIELDS):
		if ball_data[offset + 1] not in [0.0, 1.0] or ball_data[offset + 10] not in [0.0, 1.0, 2.0, 3.0]:
			return false
	for team in range(2):
		for index in range(3):
			powers[team].charge[index] = clampi(int(power_data[team * 5 + index]), 0, POWER_COSTS[index])
		powers[team].destroyed = maxi(0, int(power_data[team * 5 + 3]))
		powers[team].rapid_time = clampf(power_data[team * 5 + 4], 0, RAPID_SECONDS)
		var angle = clampf(player_data[team * 4], -TRACK_LIMIT, TRACK_LIMIT)
		players[team].angle = angle
		players[team].p = track_position(team, angle)
		players[team].aim = forward_direction(team, angle)
		players[team].hp = clampi(int(player_data[team * 4 + 1]), 0, PLAYER_LIVES)
		players[team].stun = maxf(0.0, player_data[team * 4 + 2])
		players[team].cooldown = maxf(0.0, player_data[team * 4 + 3])
	for i in range(bricks.size()):
		bricks[i].hp = mini(int(hp[i]), BRICK_LIVES)
		bricks[i].alive = bricks[i].hp > 0
	balls.clear()
	for offset in range(0, ball_data.size(), BALL_FIELDS):
		balls.append({"id": int(ball_data[offset]), "owner": int(ball_data[offset + 1]), "p": Vector2(ball_data[offset + 2], ball_data[offset + 3]), "v": Vector2(ball_data[offset + 4], ball_data[offset + 5]), "bounces": int(ball_data[offset + 6]), "boosted": ball_data[offset + 7] > 0.5, "damage": int(ball_data[offset + 8]), "ttl": ball_data[offset + 9], "power": int(ball_data[offset + 10])})
	obstacle_time = maxf(0.0, match_data[0])
	for i in range(obstacles.size()):
		obstacles[i].previous = obstacles[i].p
		obstacles[i].p = obstacle_at(i, obstacle_time)
		obstacles[i].v = Vector2.ZERO
	scores = [int(match_data[1]), int(match_data[2])]
	var phases = ["countdown", "play", "goal", "finished"]
	phase = phases[clampi(int(match_data[3]), 0, phases.size() - 1)]
	timer = match_data[4]
	winner = int(match_data[5])
	elapsed = match_data[6]
	return true

static func segment_circle(start: Vector2, delta: Vector2, center: Vector2, radius: float) -> float:
	var offset = start - center
	var c = offset.length_squared() - radius * radius
	if c <= 0:
		return 0
	var a = delta.length_squared()
	if a < 0.0000001:
		return -1
	var b = 2.0 * offset.dot(delta)
	var discriminant = b * b - 4 * a * c
	if discriminant < 0:
		return -1
	var t = (-b - sqrt(discriminant)) / (2 * a)
	return t if t >= 0 and t <= 1 else -1.0

static func sweep_capsule(start: Vector2, delta: Vector2, a: Vector2, b: Vector2, radius: float) -> Dictionary:
	# Earliest contact of a moving point with a rounded wall: two faces and two end caps.
	# Only surfaces the point is moving towards count, so a ball never sticks inside.
	var best = {"t": 2.0, "normal": Vector2.ZERO}
	var edge = b - a
	var length = edge.length()
	if length > 0.00001:
		var direction = edge / length
		var denominator = delta.cross(direction)
		if absf(denominator) > 0.000001:
			for side in [1.0, -1.0]:
				var normal = Vector2(-direction.y, direction.x) * side
				if delta.dot(normal) >= 0:
					continue
				var origin = a + normal * radius
				var t = (origin - start).cross(direction) / denominator
				var u = (origin - start).cross(delta) / denominator
				if t >= 0 and t <= 1 and u >= 0 and u <= length and t < best.t:
					best = {"t": t, "normal": normal}
	for cap in [a, b]:
		if (start - cap).dot(delta) >= 0:
			continue
		var t = segment_circle(start, delta, cap, radius)
		if t >= 0 and t < best.t:
			best = {"t": t, "normal": (start + delta * t - cap).normalized()}
	return best

static func segment_box(start: Vector2, delta: Vector2, center: Vector2, extent: Vector2) -> float:
	var lo = 0.0
	var hi = 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.000001:
			if absf(start[axis] - center[axis]) > extent[axis]:
				return -1
		else:
			var t1 = (center[axis] - extent[axis] - start[axis]) / delta[axis]
			var t2 = (center[axis] + extent[axis] - start[axis]) / delta[axis]
			lo = maxf(lo, minf(t1, t2))
			hi = minf(hi, maxf(t1, t2))
			if lo > hi:
				return -1
	return lo
