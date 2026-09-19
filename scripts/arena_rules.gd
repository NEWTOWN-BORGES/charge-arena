extends RefCounted
## Authoritative, renderer-independent simulation. World Vector2 maps to X/Z.
const MAP_SCALE = 1.24
const HALF_WIDTH = 6.0 * MAP_SCALE
const HALF_LENGTH = 6.93 * MAP_SCALE
const GOAL_RADIUS = 1.65
const TRACK_RADIUS = 2.6
const TRACK_LIMIT = 0.60
# Aim assist: how far the shot may be nudged to line up with a brick, and how finely the
# nearby angles are sampled looking for one.
const ASSIST_ANGLE = 0.10
const ASSIST_STEPS = 12
const SPEED = 5.0
const BALL_SPEED = 15.5
const FIRE_INTERVAL = 0.42
const PLAYER_LIVES = 5
const STUN_SECONDS = 0.5
const FACING_FACTOR = 1.35
# The turn saturates instead of running on: the pilot never faces more than this far off
# the arena's axis, so cornered against a wall it still fires down the field rather than
# 46 degrees into the side. The curve has to stay strictly increasing — a facing that
# turned back on itself would leave two arc positions aiming the same way, and every
# solver in here, the aiming and the AI included, would have nothing to converge on.
const FACING_LIMIT = 0.50
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
const BOOST_RAIL_SPACING = 3.4
const BOOST_CENTERS = [Vector2(-HALF_WIDTH - 0.75, 0), Vector2(HALF_WIDTH + 0.75, 0)]
const BALL_RADIUS = 0.14
const Powers = preload("res://scripts/powers.gd")
# Each pilot carries three powers (see Powers.CATALOG): two from the kit and, later, the
# skin's ultimate. The empty third slot is simply never ready.
const POWER_SLOTS = 3
const GHOST_SECONDS = 8.0
const LASER_SECONDS = 3.0
# The beam bites twice a second, so a full brick falls after two touches.
const LASER_TICK = 0.5
const LASER_DAMAGE = 2
const LASER_WIDTH = 0.22
const REBUILD_BRICKS = 7
const MIRROR_SECONDS = 4.5
# Walls rise in front of the bricks they defend: one per bank of the current layout,
# a step towards the middle of the arena, split in two when a bank is wide enough that a
# single slab would seal it off completely.
const WALLS_SECONDS = 6.5
const WALL_CLEARANCE = 0.85
const WALL_OVERHANG = 0.12
const WALL_GROUP_GAP = 1.15
const WALL_MAX_SPAN = 3.2
const WALL_SPLIT_GAP = 0.9
# The shock pulse: every ball is swept off the field, the rival is left stunned and the
# moving bumpers seize up for as long as the pilot does.
const STUN_POWER_SECONDS = 4.5
# Ultimates. Every one of them glows for two seconds before it goes off, so both sides
# can see it coming.
const ULTIMATE_WINDUP = 2.0
# Sun ray: a thick beam, wide enough for four bricks of a row, that carries on past the
# arena. It bites three times.
const SUN_RAY_SECONDS = 1.5
const SUN_RAY_TICK = 0.5
const SUN_RAY_DAMAGE = 2
const SUN_RAY_HALF_WIDTH = 1.35
# Meteors and lightning fall on the far half, never on the caster's own bricks.
const METEOR_SECONDS = 1.0
const METEOR_COUNT = 14
const METEOR_DAMAGE = 1
const METEOR_RADIUS = 0.62
const THUNDER_SECONDS = 2.0
const THUNDER_COUNT = 8
const THUNDER_DAMAGE = 2
const THUNDER_RADIUS = 0.8
# Singularity: the pilot becomes the epicentre. Every shot in flight loses its course and
# crawls into the core; what is swallowed leaves again in one fan of boosted rounds.
const SINGULARITY_PULL = 2.1
const SINGULARITY_SWALLOW = 0.55
const SINGULARITY_SLOW = 0.22
const SINGULARITY_MIN_SHOTS = 26
const SINGULARITY_MAX_SHOTS = 44
const SINGULARITY_FAN = 2.7
# Three waves come in out of the sky and sweep the arena, each one reaching further in;
# a shot is only caught once its wave has washed over it.
const SINGULARITY_WAVES = 3
const SINGULARITY_REACH = 18.0
# Bloom heals two lives, and a brick already whole grows past the usual three.
const BLOOM_HEAL = 2
const BRICK_MAX_LIVES = 5
const EXPLOSION_RADIUS = 1.65
const EXPLOSION_DAMAGE = 2
# A single stream: ten rounds, one behind the other, at one round every six physics
# frames (0.1 s). RAPID_SECONDS is exactly ten of those.
const RAPID_INTERVAL = 0.09
const RAPID_ROUNDS = 10
const RAPID_SECONDS = 1.0
const AIR_PELLETS = 5
const AIR_DAMAGE = 2
const AIR_SPREAD = 0.72
const MAX_BALLS = 128
const BALL_FIELDS = 13
# A shot ends on a target or after MAX_BOUNCES ricochets: walls, shields, boosters,
# barriers and bumpers all reflect it. This lifetime is only a safety net for a shot caught in a repeating path
# that would otherwise bounce for the rest of the match.
const BALL_LIFE = 12.0
# A shot survives three ricochets; the fourth surface swallows it, so the arena never
# fills up with balls looping forever.
const MAX_BOUNCES = 3
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
# While this runs, the moving bumpers are frozen where they stand (shock pulse).
var obstacle_stun = 0.0
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
# Aim assist for the human pilot: team 0 in PvE, both sides never in PvP.
var assist_team = -1
# Arena layout. Goals and pilot arcs never move, so rules, AI and network code stay
# shared; maps change the outline, boosters, obstacles, barriers and brick layout.
var map: Dictionary = {}
var walls: Array = WALLS.duplicate()
var boost_centers: Array = BOOST_CENTERS.duplicate()
var barriers: Array = []
# Where each team's defensive walls stand on this map (see team_walls).
var wall_slabs: Array = [[], []]
var powers: Array = []
# The three power ids each team took into the match, in button order.
var loadouts: Array = [Powers.STARTER_KIT.duplicate(), Powers.STARTER_KIT.duplicate()]
var power_rng = RandomNumberGenerator.new()
var cached_firing_angles: Dictionary = {}

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

static func pvp_map() -> Dictionary:
	return {
		"id": "colosseum", "name": "Coliseu Retangular", "outline": "colosseum", "boosters": true, "bricks": "colosseum", "barriers": [],
		"obstacles": [
			{"kind": "slide", "center": Vector2(-2.2, -1.1), "axis": Vector2.RIGHT, "travel": 1.8, "frequency": 0.55, "phase": 0.0},
			{"kind": "slide", "center": Vector2(2.2, 1.1), "axis": Vector2.RIGHT, "travel": 1.8, "frequency": 0.55, "phase": PI},
			{"kind": "orbit", "center": Vector2(0, 0), "travel": 1.2, "frequency": 0.45, "phase": 0.0, "radius": 0.42},
		],
	}

func set_map(new_map: Dictionary) -> void:
	map = new_map
	walls = outline_points(map.get("outline", "hex"))
	boost_centers = booster_centers(map)
	barriers = map.get("barriers", [])
	wall_slabs = [team_walls(0, map.get("bricks", "banks")), team_walls(1, map.get("bricks", "banks"))]
	cached_firing_angles.clear()
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
		"colosseum":
			# Wide rectangular stadium with 45-degree chamfered corners, matching the drawn sketch.
			var cx = 4.4
			var cy = 2.4
			return [
				Vector2(-cx, -l), Vector2(cx, -l),
				Vector2(w, -l + cy), Vector2(w, l - cy),
				Vector2(cx, l), Vector2(-cx, l),
				Vector2(-w, l - cy), Vector2(-w, -l + cy)
			]
	return WALLS.duplicate()

static func side_x(kind: String) -> float:
	return {"pinch": HALF_WIDTH - 1.9, "wide": HALF_WIDTH + 1.3}.get(kind, HALF_WIDTH)

static func booster_centers(layout: Dictionary) -> Array:
	# A rail of bumpers down each side wall instead of a single one at mid-field. With the
	# turn eased off at the ends of the arc, a shot from the corner no longer crosses the
	# middle of the side wall, and one lonely bumper there was simply never reached.
	if not layout.get("boosters", true):
		return []
	var outline: Array = outline_points(layout.get("outline", "hex"))
	var centers: Array = []
	for depth in [-BOOST_RAIL_SPACING, 0.0, BOOST_RAIL_SPACING]:
		var side = outline_x_at(outline, depth)
		centers.append(Vector2(-side - 0.75, depth))
		centers.append(Vector2(side + 0.75, depth))
	return centers

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
	return {"charge": [0, 0, 0], "destroyed": 0, "rapid_time": 0.0, "ghost_time": 0.0,
		"laser_time": 0.0, "laser_tick": 0.0, "mirror_time": 0.0, "walls_time": 0.0,
		"ultimate_windup": 0.0, "ultimate_time": 0.0, "ultimate_tick": 0.0, "ultimate_shots": 0, "ultimate_id": ""}

static func power_color(id: String) -> Color:
	var entry: Dictionary = Powers.entry(id)
	return Color(entry.color) if not entry.is_empty() else Color("3d5a61")

static func power_label(id: String) -> String:
	var entry: Dictionary = Powers.entry(id)
	return String(entry.short) if not entry.is_empty() else "ULTIMATE"

func power_id(team: int, index: int) -> String:
	# The power on that button, or "" for a slot the pilot has not filled.
	var kit: Array = loadouts[team] if team >= 0 and team < loadouts.size() else []
	return String(kit[index]) if index >= 0 and index < kit.size() else ""

func power_charge_cost(team: int, index: int) -> int:
	var entry: Dictionary = Powers.entry(power_id(team, index))
	return int(entry.charge) if not entry.is_empty() else 0

func running_power(team: int) -> bool:
	var state: Dictionary = powers[team]
	return state.rapid_time > 0 or state.laser_time > 0 or state.ultimate_windup > 0 or state.ultimate_time > 0

func reset_round() -> void:
	# Keep earned charges between goals, but no effect survives the round end.
	cached_firing_angles.clear()
	obstacle_stun = 0.0
	for state in powers:
		state.rapid_time = 0.0
		state.ghost_time = 0.0
		state.laser_time = 0.0
		state.laser_tick = 0.0
		state.mirror_time = 0.0
		state.walls_time = 0.0
		state.ultimate_windup = 0.0
		state.ultimate_time = 0.0
		state.ultimate_tick = 0.0
		state.ultimate_shots = 0
		state.ultimate_id = ""
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
	# Fixed facing for each arc position: the full turn near the middle, easing smoothly
	# into FACING_LIMIT at the ends and never past it.
	var facing = FACING_LIMIT * tanh(angle * FACING_FACTOR / FACING_LIMIT)
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
	# Past the usual three lives a brick stands taller and wider, from the bloom ultimate.
	return [0.0, 0.52, 0.76, 1.0, 1.1, 1.18][clampi(hp, 0, BRICK_MAX_LIVES)]

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
			"colosseum":
				# Dense 4-row fortress of 48 bricks per team (96 total) for massive destruction with powers.
				for row in range(4):
					var count = 14 if row == 0 else (12 if row < 3 else 10)
					var span = 3.9 if row == 0 else (3.3 if row < 3 else 2.7)
					var y_dist = 5.2 - row * 0.70
					for column in range(count):
						var x = lerpf(-span, span, float(column) / float(count - 1)) if count > 1 else 0.0
						var pos = Vector2(x, goal.y - sign_y * y_dist)
						add_brick(result, team, -1 if x < 0 else 1, pos, 0.0)
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
	obstacle_stun = maxf(0.0, obstacle_stun - dt)
	if obstacle_stun <= 0:
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
		for timer_name in ["ghost_time", "mirror_time", "walls_time"]:
			powers[team][timer_name] = maxf(0.0, powers[team][timer_name] - dt)
		step_laser(team, dt)
		step_ultimate(team, dt)
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
			if ball.get("held", false):
				# Caught in a singularity: the pull moves it, and it touches nothing.
				continue
			ball.ttl -= dt
			if ball.ttl <= 0:
				if ball.get("power", 0) == 1:
					explode(ball)
				balls.erase(ball)
			else:
				advance_ball(ball, dt, true)

func can_activate_power(team: int, index: int) -> bool:
	if team < 0 or team >= powers.size() or index < 0 or index >= POWER_SLOTS:
		return false
	if power_id(team, index) == "":
		return false
	if phase != "play" or players[team].stun > 0 or running_power(team):
		return false
	return powers[team].charge[index] >= power_charge_cost(team, index)

func activate_power(team: int, index: int) -> bool:
	if not can_activate_power(team, index):
		return false
	var id = power_id(team, index)
	powers[team].charge[index] = 0
	var p: Dictionary = players[team]
	var heading = forward_direction(team, p.angle)
	events.append({"kind": "power", "power": index, "id": id, "team": team, "p": p.p})
	match id:
		"blast":
			shoot(team, 1)
		"rapid":
			powers[team].rapid_time = RAPID_SECONDS
			p.cooldown = 0.0
		"air":
			# Stratified random spread leaves a useful fan, even on unlucky rolls.
			for pellet in range(AIR_PELLETS):
				var angle = lerpf(-AIR_SPREAD, AIR_SPREAD, pellet / float(AIR_PELLETS - 1))
				angle += power_rng.randf_range(-0.055, 0.055)
				spawn_ball(team, heading.rotated(angle), 3, AIR_DAMAGE)
			p.cooldown = FIRE_INTERVAL
		"ghost":
			powers[team].ghost_time = GHOST_SECONDS
		"laser":
			powers[team].laser_time = LASER_SECONDS
			powers[team].laser_tick = LASER_TICK
			# The first bite lands at once; the rest follow on the beam's own clock.
			fire_laser(team)
		"rebuild":
			rebuild_bricks(team)
		"mirror":
			powers[team].mirror_time = MIRROR_SECONDS
		"walls":
			powers[team].walls_time = WALLS_SECONDS
			events.append({"kind": "walls", "team": team, "p": p.p})
		"stun":
			shock_pulse(team)
		_:
			if Powers.is_ultimate(id):
				# Ultimates take two seconds of glow before they land.
				powers[team].ultimate_id = id
				powers[team].ultimate_windup = ULTIMATE_WINDUP
				events.append({"kind": "ultimate_charge", "id": id, "team": team, "p": p.p})
	return true

func step_ultimate(team: int, dt: float) -> void:
	var state: Dictionary = powers[team]
	if state.ultimate_windup > 0:
		state.ultimate_windup = maxf(0.0, state.ultimate_windup - dt)
		if state.ultimate_windup > 0:
			return
		fire_ultimate(team)
		return
	if String(state.ultimate_id) == "singularity" and state.ultimate_time > 0:
		# The collapse is one long draw, not a string of strikes: it ends in the release.
		var before = 1.0 - state.ultimate_time / SINGULARITY_PULL
		state.ultimate_time = maxf(0.0, state.ultimate_time - dt)
		var after = 1.0 - state.ultimate_time / SINGULARITY_PULL
		for wave in range(SINGULARITY_WAVES):
			# Each wave is announced as it breaks, so both sides see the same three sweeps.
			var mark = float(wave) / float(SINGULARITY_WAVES)
			if before <= mark and after > mark:
				events.append({"kind": "singularity_wave", "team": team, "p": players[team].p,
					"index": wave, "seconds": SINGULARITY_PULL / float(SINGULARITY_WAVES)})
		singularity_pull(team, dt)
		if state.ultimate_time <= 0:
			singularity_burst(team)
		return
	if state.ultimate_time <= 0 and state.ultimate_shots <= 0:
		return
	# The count of strikes rules, not the clock: the last one always lands.
	state.ultimate_time = maxf(0.0, state.ultimate_time - dt)
	state.ultimate_tick -= dt
	if state.ultimate_tick > 0 or state.ultimate_shots <= 0:
		return
	state.ultimate_shots -= 1
	match String(state.ultimate_id):
		"sun_ray":
			state.ultimate_tick = SUN_RAY_TICK
			sun_ray_bite(team)
		"meteors":
			state.ultimate_tick = METEOR_SECONDS / METEOR_COUNT
			sky_strike(team, "meteor", METEOR_DAMAGE, METEOR_RADIUS)
		"thunder":
			state.ultimate_tick = THUNDER_SECONDS / THUNDER_COUNT
			sky_strike(team, "thunder", THUNDER_DAMAGE, THUNDER_RADIUS)

func fire_ultimate(team: int) -> void:
	var state: Dictionary = powers[team]
	var id = String(state.ultimate_id)
	events.append({"kind": "ultimate", "id": id, "team": team, "p": players[team].p})
	match id:
		"sun_ray":
			# The first bite lands with the flash; the rest are counted out after it.
			state.ultimate_time = SUN_RAY_SECONDS
			state.ultimate_tick = SUN_RAY_TICK
			state.ultimate_shots = roundi(SUN_RAY_SECONDS / SUN_RAY_TICK) - 1
			sun_ray_bite(team)
		"meteors":
			state.ultimate_time = METEOR_SECONDS
			state.ultimate_tick = METEOR_SECONDS / METEOR_COUNT
			state.ultimate_shots = METEOR_COUNT - 1
			sky_strike(team, "meteor", METEOR_DAMAGE, METEOR_RADIUS)
		"thunder":
			state.ultimate_time = THUNDER_SECONDS
			state.ultimate_tick = THUNDER_SECONDS / THUNDER_COUNT
			state.ultimate_shots = THUNDER_COUNT - 1
			sky_strike(team, "thunder", THUNDER_DAMAGE, THUNDER_RADIUS)
		"singularity":
			state.ultimate_time = SINGULARITY_PULL
			state.ultimate_shots = 0
			events.append({"kind": "singularity", "team": team, "p": players[team].p, "seconds": SINGULARITY_PULL})
		"bloom":
			bloom_bricks(team)
		"plunder":
			plunder_bricks(team)

func sun_ray_bite(team: int) -> void:
	# A band as wide as four bricks, straight out of the pilot and past the wall.
	var origin: Vector2 = players[team].p
	var heading: Vector2 = forward_direction(team, players[team].angle)
	var reach = 3.0 * (HALF_LENGTH + HALF_WIDTH)
	var side = Vector2(-heading.y, heading.x)
	for index in range(bricks.size()):
		var brick: Dictionary = bricks[index]
		if not brick.alive or brick.team == team:
			continue
		var offset: Vector2 = brick.p - origin
		var along = offset.dot(heading)
		if along < 0 or along > reach:
			continue
		if absf(offset.dot(side)) > SUN_RAY_HALF_WIDTH + BRICK_EXTENT.x:
			continue
		damage_brick(index, SUN_RAY_DAMAGE, team, brick.p)
	var enemy = 1 - team
	var to_enemy: Vector2 = players[enemy].p - origin
	if to_enemy.dot(heading) > 0 and absf(to_enemy.dot(side)) <= SUN_RAY_HALF_WIDTH:
		damage_player(enemy, SUN_RAY_DAMAGE, players[enemy].p)
	events.append({"kind": "sun_ray", "team": team, "p": origin, "heading": heading, "width": SUN_RAY_HALF_WIDTH})

func sky_strike(team: int, kind: String, damage: int, radius: float) -> void:
	# One strike somewhere over the rival's half, inside the arena outline.
	var enemy = 1 - team
	var sign_y = 1.0 if enemy == 0 else -1.0
	var at = Vector2.ZERO
	for attempt in range(12):
		at = Vector2(power_rng.randf_range(-HALF_WIDTH, HALF_WIDTH), sign_y * power_rng.randf_range(0.4, HALF_LENGTH - 0.9))
		if point_inside(walls, at):
			break
	for index in range(bricks.size()):
		var brick: Dictionary = bricks[index]
		if brick.alive and brick.team != team and brick.p.distance_to(at) <= radius + BRICK_EXTENT.x:
			damage_brick(index, damage, team, brick.p)
	if players[enemy].p.distance_to(at) <= radius:
		damage_player(enemy, damage, players[enemy].p)
	events.append({"kind": kind, "team": team, "p": at, "radius": radius})

func singularity_front(team: int) -> float:
	# Three waves come in out of the sky, and each one sweeps the whole arena: this is how
	# far in the current one has washed. Everything beyond the front has been passed over
	# and is being dragged to the core, and whatever is fired in between is caught by the
	# next sweep.
	var progress = clampf(1.0 - powers[team].ultimate_time / SINGULARITY_PULL, 0.0, 1.0)
	return SINGULARITY_REACH * (1.0 - fmod(progress * float(SINGULARITY_WAVES), 1.0))

func singularity_pull(team: int, dt: float) -> void:
	# A wave sweeps the arena and everything it washes over is dragged towards the pilot,
	# crawling and harmless on the way; what reaches the core is swallowed and counted.
	var core: Vector2 = players[team].p
	var left: float = maxf(powers[team].ultimate_time, 0.12)
	var front: float = singularity_front(team)
	var index = balls.size() - 1
	while index >= 0:
		var ball: Dictionary = balls[index]
		var offset: Vector2 = core - ball.p
		var distance = offset.length()
		if not ball.get("held", false) and distance < front:
			# Still inside the front: the wave has not washed over it yet, so it flies its
			# own course a moment longer.
			index -= 1
			continue
		if distance <= SINGULARITY_SWALLOW:
			balls.remove_at(index)
			powers[team].ultimate_shots = mini(powers[team].ultimate_shots + 1, SINGULARITY_MAX_SHOTS)
			events.append({"kind": "swallow", "team": team, "p": core})
			index -= 1
			continue
		ball["held"] = true
		# Slow enough to watch, never so slow that a shot is left outside the collapse.
		var speed = maxf(distance / left, BALL_SPEED * SINGULARITY_SLOW)
		ball.v = offset / distance * speed
		ball.p += ball.v * dt
		ball.ttl = maxf(ball.ttl, left + 0.3)
		index -= 1

func singularity_burst(team: int) -> void:
	# The core opens. Whatever it holds leaves at once in a fan, turbocharged and out of
	# ricochets: the same round a booster hands back, in a dozen copies.
	var core: Vector2 = players[team].p
	var heading: Vector2 = forward_direction(team, players[team].angle)
	var eaten: int = powers[team].ultimate_shots
	var index = balls.size() - 1
	while index >= 0:
		# Anything still on its way in is compacted with the rest.
		if balls[index].get("held", false):
			balls.remove_at(index)
			eaten += 1
		index -= 1
	# Every round it ate is fired back, doubled, and the blast is never thin: it opens with
	# a full spread whatever it caught. They pass straight through the moving obstacles.
	var count = clampi(eaten * 3, SINGULARITY_MIN_SHOTS, SINGULARITY_MAX_SHOTS)
	powers[team].ultimate_shots = 0
	for shot in range(count):
		while balls.size() >= MAX_BALLS:
			balls.remove_at(0)
		var spread = 0.0 if count == 1 else lerpf(-SINGULARITY_FAN * 0.5, SINGULARITY_FAN * 0.5, float(shot) / float(count - 1))
		var course: Vector2 = heading.rotated(spread)
		balls.append({"id": next_id, "owner": team, "p": core + course * 0.7, "v": course * BALL_SPEED * BOOST_SPEED,
			"bounces": MAX_BOUNCES, "boosted": true, "damage": BOOST_DAMAGE, "ttl": BALL_LIFE, "power": 0, "ghost": true, "held": false})
		next_id += 1
	events.append({"kind": "singularity_burst", "team": team, "p": core, "heading": heading, "count": count})

func bloom_bricks(team: int) -> void:
	# Two lives back on every brick; the ones already whole grow instead.
	var healed: Array = []
	for index in range(bricks.size()):
		var brick: Dictionary = bricks[index]
		if brick.team != team or not brick.alive:
			continue
		brick.hp = mini(brick.hp + BLOOM_HEAL, BRICK_MAX_LIVES)
		healed.append(index)
	events.append({"kind": "bloom", "team": team, "bricks": healed, "heal": BLOOM_HEAL, "p": players[team].p})

func plunder_bricks(team: int) -> void:
	# Swap the two walls, brick for brick: the layout is already mirrored, so the same
	# index on the other side is the same place on the other half.
	var per_team: int = bricks.size() / 2
	for index in range(per_team):
		var mine: Dictionary = bricks[index if team == 0 else index + per_team]
		var theirs: Dictionary = bricks[index + per_team if team == 0 else index]
		var keep: int = mine.hp
		mine.hp = theirs.hp
		theirs.hp = keep
		mine.alive = mine.hp > 0
		theirs.alive = theirs.hp > 0
	events.append({"kind": "plunder", "team": team, "p": players[team].p})

func shock_pulse(team: int) -> void:
	# Sweeps the field clean and leaves the rival on the floor for a few seconds.
	var enemy = 1 - team
	balls.clear()
	players[enemy].stun = maxf(players[enemy].stun, STUN_POWER_SECONDS)
	obstacle_stun = maxf(obstacle_stun, STUN_POWER_SECONDS)
	events.append({"kind": "shock", "team": team, "p": players[team].p})
	events.append({"kind": "stun", "team": enemy, "p": players[enemy].p})

static func team_walls(team: int, layout: String = "banks") -> Array:
	# One slab per bank of bricks, as wide as the bank and a step in front of it.
	var own: Array = []
	for data in make_bricks(layout):
		if data.team == team:
			own.append(data)
	own.sort_custom(func(a, b): return a.p.x < b.p.x)
	var banks: Array = []
	for data in own:
		if banks.is_empty() or data.p.x - banks.back().back().p.x > WALL_GROUP_GAP:
			banks.append([data])
		else:
			banks.back().append(data)
	var sign_y = 1.0 if team == 0 else -1.0
	var slabs: Array = []
	for bank in banks:
		var min_x: float = bank.front().p.x
		var max_x: float = bank.back().p.x
		# The front of the bank is the row closest to the middle of the arena.
		var front: float = INF
		for data in bank:
			front = minf(front, absf(data.p.y))
		var y = sign_y * (front - WALL_CLEARANCE)
		var left = min_x - BRICK_EXTENT.x - WALL_OVERHANG
		var right = max_x + BRICK_EXTENT.x + WALL_OVERHANG
		if right - left <= WALL_MAX_SPAN:
			slabs.append({"a": Vector2(left, y), "b": Vector2(right, y)})
			continue
		# A wide bank keeps a hole in the middle: the rival still has a line, with work.
		var middle = (left + right) * 0.5
		slabs.append({"a": Vector2(left, y), "b": Vector2(middle - WALL_SPLIT_GAP * 0.5, y)})
		slabs.append({"a": Vector2(middle + WALL_SPLIT_GAP * 0.5, y), "b": Vector2(right, y)})
	return slabs

func rebuild_bricks(team: int) -> void:
	# Bring fallen bricks back whole, starting with the ones closest to the goal.
	var fallen: Array = []
	for index in range(bricks.size()):
		if bricks[index].team == team and not bricks[index].alive:
			fallen.append(index)
	fallen.sort_custom(func(a, b): return absf(bricks[a].p.y) > absf(bricks[b].p.y))
	var restored: Array = []
	for index in fallen.slice(0, REBUILD_BRICKS):
		bricks[index].hp = BRICK_LIVES
		bricks[index].alive = true
		restored.append(index)
	events.append({"kind": "rebuild", "team": team, "bricks": restored, "p": players[team].p})

func step_laser(team: int, dt: float) -> void:
	var state: Dictionary = powers[team]
	if state.laser_time <= 0:
		return
	state.laser_time = maxf(0.0, state.laser_time - dt)
	state.laser_tick -= dt
	if state.laser_tick > 0 or state.laser_time <= 0:
		return
	state.laser_tick = LASER_TICK
	fire_laser(team)

func laser_length(origin: Vector2, heading: Vector2) -> float:
	# The beam crosses bumpers and barriers and stops where it leaves the arena.
	var limit = 2.0 * (HALF_LENGTH + HALF_WIDTH)
	var step = 0.25
	var travelled = step
	while travelled < limit:
		if not point_inside(walls, origin + heading * travelled):
			return travelled
		travelled += step
	return limit

func fire_laser(team: int) -> void:
	var origin: Vector2 = players[team].p
	var heading: Vector2 = forward_direction(team, players[team].angle)
	var reach = laser_length(origin, heading)
	var hit: Array = []
	for index in range(bricks.size()):
		var brick: Dictionary = bricks[index]
		if not brick.alive or brick.team == team:
			continue
		var extent = BRICK_EXTENT * brick_scale(brick.hp) + Vector2.ONE * LASER_WIDTH
		var t = segment_box((origin - brick.p).rotated(-brick.rotation), (heading * reach).rotated(-brick.rotation), Vector2.ZERO, extent)
		if t >= 0:
			hit.append(index)
	for index in hit:
		damage_brick(index, LASER_DAMAGE, team, bricks[index].p)
	var enemy = 1 - team
	if segment_circle(origin, heading * reach, players[enemy].p, 0.43 + LASER_WIDTH) >= 0:
		damage_player(enemy, 1, players[enemy].p)
	events.append({"kind": "laser", "team": team, "p": origin, "heading": heading, "length": reach})

func credit_destroyed_brick(team: int) -> void:
	powers[team].destroyed += 1
	for index in range(POWER_SLOTS):
		var cost = power_charge_cost(team, index)
		if cost <= 0:
			continue
		var previous: int = powers[team].charge[index]
		powers[team].charge[index] = mini(previous + 1, cost)
		if previous < cost and powers[team].charge[index] == cost:
			events.append({"kind": "power_ready", "power": index, "team": team, "p": players[team].p})

func damage_brick(index: int, damage: int, owner: int, at: Vector2) -> void:
	var brick: Dictionary = bricks[index]
	if not brick.alive or brick.team == owner:
		return
	brick.hp = maxi(0, brick.hp - damage)
	brick.alive = brick.hp > 0
	events.append({"kind": "brick" if not brick.alive else "brick_hit", "p": at, "team": brick.team})
	if not brick.alive:
		cached_firing_angles.clear()
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

static func facing_slope(angle: float) -> float:
	# How fast the facing turns at this point of the arc; it flattens towards the ends, and
	# the solvers step by it instead of assuming the old straight ratio.
	var shaped = tanh(angle * FACING_FACTOR / FACING_LIMIT)
	return maxf(FACING_FACTOR * (1.0 - shaped * shaped), 0.22)

func direct_angle(team: int, target: Vector2) -> float:
	# The place on the arc from which the pilot points straight at a spot. Solved by a
	# couple of refinements instead of by simulating shots: it costs microseconds, and the
	# whole aiming system leans on it every frame.
	var goal = goal_center(team)
	var sign_y = 1.0 if team == 0 else -1.0
	var depth = maxf((goal.y - target.y) * sign_y, 0.25)
	var wanted = clampf(atan2(target.x, depth), -FACING_LIMIT * 0.999, FACING_LIMIT * 0.999)
	var angle = clampf(atanh(wanted / FACING_LIMIT) * FACING_LIMIT / FACING_FACTOR, -TRACK_LIMIT, TRACK_LIMIT)
	for pass_index in range(4):
		var from = track_position(team, angle)
		# angle_difference(a, b) is b - a, so the heading goes first: this is how far the
		# pilot still has to turn to look at the target. With the arguments the other way
		# round every refinement walked away from the answer.
		var error = angle_difference(forward_direction(team, angle).angle(), (target - from).angle())
		angle = clampf(angle + error / facing_slope(angle), -TRACK_LIMIT, TRACK_LIMIT)
	return angle

func firing_angles(team: int, _samples: int = 0) -> Array:
	# One entry per enemy brick still standing, sorted along the arc. No ball is simulated
	# here: sweeping 31 predicted shots used to cost 58 ms and froze the frame.
	if cached_firing_angles.has(team):
		return cached_firing_angles[team]
	var found: Array = []
	for index in range(bricks.size()):
		var brick: Dictionary = bricks[index]
		if not brick.alive or brick.team == team:
			continue
		var angle = direct_angle(team, brick.p)
		# Bricks stacked exactly behind one another share an angle; keep one of them. The
		# whole wall only spans about a third of a radian, and the turn is eased off at the
		# ends of the arc, so this window has to be very tight or most targets disappear.
		var duplicate = false
		for option in found:
			if absf(option.angle - angle) < 0.001:
				duplicate = true
				break
		if duplicate:
			continue
		found.append({"angle": angle, "brick": index, "p": brick.p})
	found.sort_custom(func(a, b): return a.angle < b.angle)
	cached_firing_angles[team] = found
	return found

func angle_for_target(team: int, at: Vector2) -> float:
	# The angle that points at whatever brick is nearest the chosen spot.
	var best = INF
	var best_distance = INF
	for option in firing_angles(team):
		var distance: float = option.p.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = option.angle
	return best if best_distance < 4.5 else INF

func assist_heading(team: int) -> Vector2:
	# Small magnetism: if a brick sits within a few hundredths of a radian of where the
	# pilot points, the round leaves on that angle instead. Pure geometry, no prediction.
	var player: Dictionary = players[team]
	if team != assist_team:
		return player.aim
	var best = INF
	var best_gap = ASSIST_ANGLE
	for option in firing_angles(team):
		var gap: float = absf(option.angle - player.angle)
		if gap < best_gap:
			best_gap = gap
			best = option.angle
	return forward_direction(team, best) if best != INF else player.aim

func shoot(team: int, power: int = 0) -> void:
	# The machine gun keeps the cadence of its own stream; every other shot is single.
	if power == 2:
		var pilot: Dictionary = players[team]
		pilot.cooldown = RAPID_INTERVAL
		spawn_ball(team, assist_heading(team), power)
		events.append({"kind": "shot", "p": pilot.p, "team": team, "power": power})
		return
	var p: Dictionary = players[team]
	p.aim = forward_direction(team, p.angle)
	p.cooldown = FIRE_INTERVAL
	spawn_ball(team, assist_heading(team), power)
	events.append({"kind": "shot", "p": p.p, "team": team, "power": power})

func spawn_ball(team: int, heading: Vector2, power: int, damage: int = 1) -> void:
	# Shots no longer expire against a wall, so a full arena drops the oldest one instead
	# of silently refusing to fire.
	while balls.size() >= MAX_BALLS:
		balls.remove_at(0)
	balls.append({"id": next_id, "owner": team, "p": players[team].p + heading * 0.64, "v": heading * BALL_SPEED, "bounces": 0, "boosted": false, "damage": damage, "ttl": BALL_LIFE, "power": power, "ghost": powers[team].ghost_time > 0})
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
		for obstacle in (obstacles if not ball.get("ghost", false) else []):
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
		var solid_barriers: Array = barriers if not ball.get("ghost", false) else []
		if not ball.get("ghost", false):
			# Raised walls only stop the other side's shots, like the bricks they cover.
			for defender in range(2):
				if defender != ball.owner and powers[defender].walls_time > 0:
					solid_barriers = solid_barriers + wall_slabs[defender]
		for barrier in solid_barriers:
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
				if powers[bricks[target].team].mirror_time > 0:
					# The cape hands the shot back as a boosted round: faster, harder and
					# out of ricochets, so it has to find a target on the way home.
					ball.owner = bricks[target].team
					ball.v = -ball.v.normalized() * BALL_SPEED * BOOST_SPEED
					ball.boosted = true
					ball.damage = BOOST_DAMAGE
					ball.p += ball.v.normalized() * 0.02
					ball.bounces = MAX_BOUNCES
					if not preview:
						events.append({"kind": "mirror", "p": ball.p, "team": bricks[target].team})
					remaining *= 1.0 - best
					continue
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
				# Every surface reflects, up to MAX_BOUNCES: after that the shot fades.
				ball.bounces += 1
				if ball.bounces > MAX_BOUNCES:
					# Out of ricochets: the shot fades against this surface.
					if preview:
						return {"kind": "spent"}
					if ball.get("power", 0) == 1:
						explode(ball)
					balls.erase(ball)
					events.append({"kind": "spent", "p": ball.p, "team": ball.owner})
					return {"kind": "spent"}
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
		else:
			# A wide fan needs no lined-up shot, so it covers the banks the boss cannot reach.
			power = ai_slot(["air"], level)
		if power < 0:
			power = ai_defensive_power(level)
	return {"move": move, "fire": fire, "power": power}

func ai_power(outcome: Dictionary, level: Dictionary) -> int:
	# The boss only spends a power on a shot already worth taking, and the heavier
	# burst goes first so it does not sit unused behind the cheaper blast.
	if elapsed < ai_next_power or outcome.get("kind", "") != "brick":
		return -1
	# Heavier powers first, so a cheap one does not keep the expensive kit idle.
	return ai_slot(["laser", "rapid", "stun", "blast", "ghost"], level)

func ai_slot(wanted: Array, level: Dictionary) -> int:
	# One power at a time, never before its own pause has run out.
	if elapsed < ai_next_power:
		return -1
	for id in wanted:
		for index in range(POWER_SLOTS):
			if power_id(1, index) == id and can_activate_power(1, index):
				ai_next_power = elapsed + float(level.get("power_gap", AI_POWER_GAP))
				return index
	return -1

func ai_defensive_power(level: Dictionary) -> int:
	# With its wall coming down, the boss reaches for whatever keeps the goal shut.
	if elapsed < ai_next_power:
		return -1
	var standing = brick_count(1)
	var wanted: Array = []
	if standing <= 6:
		wanted.append("rebuild")
	if standing <= 10:
		wanted.append("walls")
	if standing <= 14:
		wanted.append_array(["mirror", "stun"])
	return ai_slot(wanted, level)

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
	return {"players": players.duplicate(true), "powers": powers.duplicate(true), "loadouts": loadouts.duplicate(true), "obstacle_stun": obstacle_stun, "brick_hp": hp, "balls": balls.duplicate(true), "obstacles": obstacles.duplicate(true), "obstacle_time": obstacle_time, "scores": scores.duplicate(), "phase": phase, "timer": timer, "winner": winner, "elapsed": elapsed}

func apply_snapshot(data: Dictionary) -> void:
	players = data.players
	powers = data.powers.duplicate(true)
	for i in range(bricks.size()):
		bricks[i].hp = data.brick_hp[i]
		bricks[i].alive = bricks[i].hp > 0
	balls = data.balls
	obstacles = data.obstacles
	obstacle_time = data.obstacle_time
	obstacle_stun = data.get("obstacle_stun", 0.0)
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
		ball_data.append_array([ball.id, ball.owner, ball.p.x, ball.p.y, ball.v.x, ball.v.y, ball.bounces, 1.0 if ball.get("boosted", false) else 0.0, ball.get("damage", 1), ball.ttl, ball.get("power", 0), 1.0 if ball.get("ghost", false) else 0.0, 1.0 if ball.get("held", false) else 0.0])
	var power_data = PackedFloat32Array()
	for state in powers:
		power_data.append_array([state.charge[0], state.charge[1], state.charge[2], state.destroyed, state.rapid_time,
			state.ghost_time, state.laser_time, state.mirror_time, state.walls_time, state.ultimate_windup, state.ultimate_time])
	var phase_id = ["countdown", "play", "goal", "finished"].find(phase)
	var match_data = PackedFloat32Array([obstacle_time, scores[0], scores[1], phase_id, timer, winner, elapsed, obstacle_stun])
	return {"p": player_data, "h": hp, "b": ball_data, "m": match_data, "w": power_data}

func apply_network_snapshot(data: Dictionary) -> bool:
	if not data.has_all(["p", "h", "b", "m", "w"]):
		return false
	var player_data: PackedFloat32Array = data.p
	var hp: PackedByteArray = data.h
	var ball_data: PackedFloat32Array = data.b
	var match_data: PackedFloat32Array = data.m
	var power_data: PackedFloat32Array = data.w
	if player_data.size() != 8 or hp.size() != bricks.size() or match_data.size() != 8 or power_data.size() != 22 or ball_data.size() % BALL_FIELDS != 0 or ball_data.size() > MAX_BALLS * BALL_FIELDS:
		return false
	for packed in [player_data, ball_data, match_data, power_data]:
		for value in packed:
			if not is_finite(value):
				return false
	for offset in range(0, ball_data.size(), BALL_FIELDS):
		if ball_data[offset + 1] not in [0.0, 1.0] or ball_data[offset + 10] not in [0.0, 1.0, 2.0, 3.0] or ball_data[offset + 11] not in [0.0, 1.0] or ball_data[offset + 12] not in [0.0, 1.0]:
			return false
	for team in range(2):
		var base = team * 11
		for index in range(POWER_SLOTS):
			powers[team].charge[index] = clampi(int(power_data[base + index]), 0, maxi(power_charge_cost(team, index), 0))
		powers[team].destroyed = maxi(0, int(power_data[base + 3]))
		powers[team].rapid_time = clampf(power_data[base + 4], 0, RAPID_SECONDS)
		powers[team].ghost_time = clampf(power_data[base + 5], 0, GHOST_SECONDS)
		powers[team].laser_time = clampf(power_data[base + 6], 0, LASER_SECONDS)
		powers[team].mirror_time = clampf(power_data[base + 7], 0, MIRROR_SECONDS)
		powers[team].walls_time = clampf(power_data[base + 8], 0, WALLS_SECONDS)
		powers[team].ultimate_windup = clampf(power_data[base + 9], 0, ULTIMATE_WINDUP)
		powers[team].ultimate_time = clampf(power_data[base + 10], 0, maxf(THUNDER_SECONDS, SINGULARITY_PULL))
		powers[team].ultimate_id = power_id(team, 2)
		var angle = clampf(player_data[team * 4], -TRACK_LIMIT, TRACK_LIMIT)
		players[team].angle = angle
		players[team].p = track_position(team, angle)
		players[team].aim = forward_direction(team, angle)
		players[team].hp = clampi(int(player_data[team * 4 + 1]), 0, PLAYER_LIVES)
		players[team].stun = maxf(0.0, player_data[team * 4 + 2])
		players[team].cooldown = maxf(0.0, player_data[team * 4 + 3])
	for i in range(bricks.size()):
		bricks[i].hp = mini(int(hp[i]), BRICK_MAX_LIVES)
		bricks[i].alive = bricks[i].hp > 0
	balls.clear()
	for offset in range(0, ball_data.size(), BALL_FIELDS):
		balls.append({"id": int(ball_data[offset]), "owner": int(ball_data[offset + 1]), "p": Vector2(ball_data[offset + 2], ball_data[offset + 3]), "v": Vector2(ball_data[offset + 4], ball_data[offset + 5]), "bounces": int(ball_data[offset + 6]), "boosted": ball_data[offset + 7] > 0.5, "damage": int(ball_data[offset + 8]), "ttl": ball_data[offset + 9], "power": int(ball_data[offset + 10]), "ghost": ball_data[offset + 11] > 0.5, "held": ball_data[offset + 12] > 0.5})
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
	obstacle_stun = clampf(match_data[7], 0, STUN_POWER_SECONDS)
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
