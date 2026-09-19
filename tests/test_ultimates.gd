extends SceneTree
# The skin ultimates: two seconds of glow, then the sun ray, the meteor shower, the
# thunderstorm, the bloom that heals past full and the plunder that swaps the two walls.
const Rules = preload("res://scripts/arena_rules.gd")
const Powers = preload("res://scripts/powers.gd")
const Skins = preload("res://scripts/skins.gd")
var failures = 0
var idle = {"move": Vector2.ZERO, "fire": false}

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func playing(ultimate: String):
	var r = Rules.new()
	r.phase = "play"
	r.loadouts = [["blast", "air", ultimate], ["blast", "air", ultimate]]
	return r

func launch(r) -> void:
	# Charge the third slot and ask for it; the wind-up starts on that same step.
	r.powers[0].charge[2] = r.power_charge_cost(0, 2)
	r.step(1.0 / 60, [{"move": Vector2.ZERO, "fire": false, "power": 2}, idle])

func wait(r, seconds: float) -> Array:
	# Events are cleared on every step, so they are gathered as the clock runs.
	var seen: Array = []
	for tick in range(roundi(seconds * 60)):
		r.step(1.0 / 60, [idle, idle])
		seen.append_array(r.events)
	return seen

func run_until(r, kind: String, limit: float) -> Array:
	# Steps only until that event lands: what follows is measured at the very moment.
	var seen: Array = []
	for tick in range(roundi(limit * 60)):
		r.step(1.0 / 60, [idle, idle])
		seen.append_array(r.events)
		if r.events.any(func(e): return e.kind == kind):
			break
	return seen

func in_band(r, origin: Vector2, heading: Vector2, side: Vector2) -> int:
	return r.bricks.filter(func(b): return b.team == 1 and (b.p - origin).dot(heading) > 0 and absf((b.p - origin).dot(side)) <= Rules.SUN_RAY_HALF_WIDTH + Rules.BRICK_EXTENT.x).size()

func aim_at_bricks(r) -> void:
	# The middle of the arc points at the gap between the banks; this angle does not.
	r.players[0].angle = -0.34
	r.players[0].p = Rules.track_position(0, -0.34)

func team_health(r, team: int) -> int:
	return r.bricks.filter(func(b): return b.team == team).reduce(func(total, b): return total + b.hp, 0)

func standing(r, team: int) -> int:
	return r.bricks.filter(func(b): return b.team == team and b.alive).size()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# ---------------------------------------------------------------- the catalogue
	check(Powers.ULTIMATES.size() == 7 and Powers.ULTIMATES.all(func(u): return u.charge == Powers.ULTIMATE_CHARGE and u.price == 0), "Seven ultimates, none of them for sale and all charging the same")
	check(Powers.ULTIMATES.all(func(u): return Powers.is_ultimate(u.id) and not Powers.entry(u.id).is_empty()), "Each one is found by id, like any other power")
	var carriers = Skins.CATALOG.filter(func(s): return s.ultimate != "")
	check(carriers.size() == 7 and carriers.all(func(s): return Powers.is_ultimate(s.ultimate)), "Seven skins carry one each")
	check(Skins.CATALOG[10].ultimate == "sun_ray" and Skins.CATALOG[2].ultimate == "meteors" and Skins.CATALOG[7].ultimate == "thunder" and Skins.CATALOG[3].ultimate == "bloom" and Skins.CATALOG[9].ultimate == "plunder", "Arconte, Astrónomo, Caça-Trovões, Jardineiro and Corsário, each with its own")

	# ---------------------------------------------------------------- every ultimate glows first
	var r = playing("sun_ray")
	aim_at_bricks(r)
	launch(r)
	check(r.powers[0].ultimate_windup > Rules.ULTIMATE_WINDUP - 0.05 and r.events.any(func(e): return e.kind == "ultimate_charge"), "Asking for it starts a %.0f second glow" % Rules.ULTIMATE_WINDUP)
	check(not r.can_activate_power(0, 0), "Nothing else can be fired while it charges")
	check(r.events.filter(func(e): return e.kind == "sun_ray").is_empty(), "Nothing happens yet")
	var before_enemy = team_health(r, 1)
	var glow_events: Array = wait(r, Rules.ULTIMATE_WINDUP + 0.05)
	check(glow_events.any(func(e): return e.kind == "ultimate" and e.id == "sun_ray"), "When the glow ends the ultimate goes off")

	# ---------------------------------------------------------------- sun ray
	var ray_events: Array = glow_events + wait(r, Rules.SUN_RAY_SECONDS + 0.1)
	var bites: int = ray_events.filter(func(e): return e.kind == "sun_ray").size()
	check(bites == roundi(Rules.SUN_RAY_SECONDS / Rules.SUN_RAY_TICK), "The ray bites %d times" % roundi(Rules.SUN_RAY_SECONDS / Rules.SUN_RAY_TICK))
	check(before_enemy - team_health(r, 1) >= Rules.SUN_RAY_DAMAGE * 4, "It eats a whole row of bricks (%d de vida)" % (before_enemy - team_health(r, 1)))
	check(team_health(r, 0) == Rules.BRICK_COUNT * Rules.BRICK_LIVES, "And never touches the caster's own wall")
	# Wide enough for four bricks of a row, standing at the middle of the arc.
	var straight = playing("sun_ray")
	aim_at_bricks(straight)
	var origin: Vector2 = straight.players[0].p
	var heading: Vector2 = Rules.forward_direction(0, straight.players[0].angle)
	var side = Vector2(-heading.y, heading.x)
	check(in_band(straight, origin, heading, side) > 0, "Aimed at a bank, the ray finds bricks to eat")
	# Width: on an unbroken row, the band has to swallow four bricks side by side.
	var wall_layout: Array = Rules.make_bricks("wall").filter(func(b): return b.team == 1)
	var row: Array = wall_layout.filter(func(b): return absf(b.p.y - wall_layout[0].p.y) < 0.02)
	row.sort_custom(func(a, b): return a.p.x < b.p.x)
	var widest = 0
	for anchor in row:
		var covered: int = row.filter(func(b): return absf(b.p.x - anchor.p.x) <= Rules.SUN_RAY_HALF_WIDTH + Rules.BRICK_EXTENT.x).size()
		widest = maxi(widest, covered)
	check(widest >= 4, "The band covers at least four bricks side by side (%d)" % widest)

	# ---------------------------------------------------------------- meteors and thunder
	for kind in [["meteors", "meteor", Rules.METEOR_COUNT, Rules.METEOR_SECONDS], ["thunder", "thunder", Rules.THUNDER_COUNT, Rules.THUNDER_SECONDS]]:
		var sky = playing(kind[0])
		# A fixed seed: where the strikes land is random in a real match, not here.
		sky.power_rng.seed = 20260918
		launch(sky)
		var sky_events: Array = wait(sky, Rules.ULTIMATE_WINDUP + 0.05)
		var before = team_health(sky, 1)
		var storm: Array = sky_events + wait(sky, float(kind[3]) + 0.1)
		var strikes: Array = storm.filter(func(e): return e.kind == kind[1])
		check(strikes.size() == kind[2], "%s falls %d times" % [kind[0], kind[2]])
		check(strikes.all(func(e): return Rules.point_inside(sky.walls, e.p) and e.p.y < 0), "Every strike lands inside the arena, on the rival's half")
		check(team_health(sky, 0) == Rules.BRICK_COUNT * Rules.BRICK_LIVES, "The caster's own bricks are never hit")
		check(before - team_health(sky, 1) > 0, "The rival's wall takes the damage (%d de vida)" % (before - team_health(sky, 1)))
		check(sky.powers[0].ultimate_time == 0, "And it ends on its own")

	# ---------------------------------------------------------------- bloom
	var garden = playing("bloom")
	for i in range(garden.bricks.size()):
		if garden.bricks[i].team == 0 and i % 3 == 0:
			garden.bricks[i].hp = 1
	var wounded = garden.bricks.filter(func(b): return b.team == 0 and b.hp == 1).size()
	launch(garden)
	var garden_events: Array = wait(garden, Rules.ULTIMATE_WINDUP + 0.05)
	check(garden.bricks.filter(func(b): return b.team == 0 and b.hp == 1).is_empty() and wounded > 0, "Every wounded brick is healed")
	check(garden.bricks.filter(func(b): return b.team == 0 and b.hp == Rules.BRICK_LIVES + Rules.BLOOM_HEAL).size() > 0, "Bricks already whole go past full")
	check(garden.bricks.all(func(b): return b.hp <= Rules.BRICK_MAX_LIVES), "Never past the ceiling of %d lives" % Rules.BRICK_MAX_LIVES)
	check(Rules.brick_scale(Rules.BRICK_MAX_LIVES) > Rules.brick_scale(Rules.BRICK_LIVES), "An overgrown brick is drawn bigger")
	check(team_health(garden, 1) == Rules.BRICK_COUNT * Rules.BRICK_LIVES, "The rival's wall is left alone")
	var bloom_event: Array = garden_events.filter(func(e): return e.kind == "bloom")
	check(bloom_event.size() == 1 and bloom_event[0].heal == Rules.BLOOM_HEAL, "The heal is announced for the +2 marks")

	# ---------------------------------------------------------------- plunder
	var reef = playing("plunder")
	for i in range(reef.bricks.size()):
		# The pilot is down to a few bricks; the rival still has most of the wall.
		if reef.bricks[i].team == 0 and i % 5 != 0:
			reef.bricks[i].hp = 0
			reef.bricks[i].alive = false
		if reef.bricks[i].team == 1 and i % 9 == 0:
			reef.bricks[i].hp = 0
			reef.bricks[i].alive = false
	var mine_before = standing(reef, 0)
	var theirs_before = standing(reef, 1)
	var mirror_before: Array = reef.bricks.slice(Rules.BRICK_COUNT).map(func(b): return b.hp)
	launch(reef)
	var reef_events: Array = wait(reef, Rules.ULTIMATE_WINDUP + 0.05)
	check(standing(reef, 0) == theirs_before and standing(reef, 1) == mine_before and theirs_before != mine_before, "The two walls swap: %d bricks for %d" % [theirs_before, mine_before])
	check(reef.bricks.slice(0, Rules.BRICK_COUNT).map(func(b): return b.hp) == mirror_before, "Brick for brick, in the mirrored place")
	check(reef_events.any(func(e): return e.kind == "plunder"), "The swap is announced so the arena can flash")

	# ---------------------------------------------------------------- singularity
	var hole = playing("singularity")
	launch(hole)
	var opening: Array = wait(hole, Rules.ULTIMATE_WINDUP + 0.05)
	check(opening.any(func(e): return e.kind == "singularity"), "The collapse is announced when the hole opens")
	# Four shots in flight once the hole is open, two of each side, spread around the arena.
	for spot in [Vector2(-3.0, 1.0), Vector2(2.5, -1.5), Vector2(-1.0, -3.0), Vector2(3.5, 2.0)]:
		hole.balls.append({"id": hole.next_id, "owner": hole.next_id % 2, "p": spot, "v": Vector2(Rules.BALL_SPEED, 0),
			"bounces": 0, "boosted": false, "damage": 1, "ttl": Rules.BALL_LIFE, "power": 0, "ghost": false})
		hole.next_id += 1
	# The waves sweep in three times, each pass reaching out from the core to the rim.
	var sweep = playing("singularity")
	launch(sweep)
	var fronts: Array = []
	var waves: Array = []
	# The first wave breaks with the discharge itself, at the end of the wind-up.
	for event in wait(sweep, Rules.ULTIMATE_WINDUP + 0.05):
		if event.kind == "singularity_wave":
			waves.append(event.index)
	for sample in range(36):
		fronts.append(sweep.singularity_front(0))
		for event in wait(sweep, Rules.SINGULARITY_PULL / 36.0):
			if event.kind == "singularity_wave":
				waves.append(event.index)
	var restarts = 0
	for i in range(1, fronts.size()):
		if fronts[i] > fronts[i - 1] + 0.01:
			restarts += 1
	check(waves == [0, 1, 2], "Three waves break, one after the other, and both sides hear them (%s)" % str(waves))
	check(restarts >= 1, "The front restarts at the rim for each new wave (%d recomeços em %d amostras)" % [restarts, fronts.size()])
	check(fronts.max() > Rules.HALF_LENGTH and fronts.min() < 1.5, "The front washes over everything, from %.1f down to %.1f" % [fronts.max(), fronts.min()])
	# Whatever a wave has passed over is held, crawling, and pointed at the pilot.
	wait(hole, Rules.SINGULARITY_PULL * 0.5)
	var core: Vector2 = hole.players[0].p
	var held: Array = hole.balls.filter(func(b): return b.get("held", false))
	var inward = held.all(func(b): return b.v.normalized().dot((core - b.p).normalized()) > 0.99)
	var crawling = held.all(func(b): return b.v.length() < Rules.BALL_SPEED)
	check(not held.is_empty(), "The waves catch the shots they wash over (%d)" % held.size())
	check(inward and crawling, "They crawl straight at the core instead of flying their own course")
	var mine_mid = team_health(hole, 0)
	# The release: the fan, turbocharged, two of damage and out of ricochets.
	var release: Array = run_until(hole, "singularity_burst", Rules.SINGULARITY_PULL + 0.5)
	var burst: Array = release.filter(func(e): return e.kind == "singularity_burst")
	check(burst.size() == 1, "The core opens exactly once")
	check(release.any(func(e): return e.kind == "swallow"), "Each round swallowed is announced")
	check(hole.balls.size() == int(burst[0].count) and int(burst[0].count) >= Rules.SINGULARITY_MIN_SHOTS, "It fires back %d rounds, never fewer than %d" % [int(burst[0].count), Rules.SINGULARITY_MIN_SHOTS])
	check(hole.balls.all(func(b): return b.owner == 0), "All of them belong to the pilot that cast it")
	check(hole.balls.all(func(b): return b.damage == Rules.BOOST_DAMAGE and b.boosted and b.bounces >= Rules.MAX_BOUNCES), "Turbocharged, 2 of damage and out of ricochets, like a booster shot")
	check(hole.balls.all(func(b): return b.get("ghost", false)), "And they go straight through the moving obstacles")
	check(hole.balls.all(func(b): return not b.get("held", false)), "Nothing is left holding in the core")
	var out_way: Vector2 = Rules.forward_direction(0, hole.players[0].angle)
	var forward = hole.balls.all(func(b): return b.v.normalized().dot(out_way) > cos(Rules.SINGULARITY_FAN * 0.5 + 0.02))
	var fanned: Array = hole.balls.map(func(b): return out_way.angle_to(b.v))
	check(forward and absf(fanned.max() - fanned.min()) > Rules.SINGULARITY_FAN * 0.8, "They leave forwards, in a fan of %.0f degrees" % rad_to_deg(absf(fanned.max() - fanned.min())))
	check(team_health(hole, 0) == mine_mid, "The draw itself never scratches the caster's own wall")
	# On the wire, a held round keeps holding.
	var wire = playing("singularity")
	var mirror_wire = playing("singularity")
	wire.balls.append({"id": 1, "owner": 1, "p": Vector2(-2.0, 0.5), "v": Vector2(Rules.BALL_SPEED, 0), "bounces": 0,
		"boosted": false, "damage": 1, "ttl": Rules.BALL_LIFE, "power": 0, "ghost": false, "held": true})
	check(mirror_wire.apply_network_snapshot(wire.network_snapshot()), "The snapshot with a held round is accepted")
	check(mirror_wire.balls.size() == 1 and mirror_wire.balls[0].get("held", false), "And the client knows the round is inside the hole")

	# ---------------------------------------------------------------- sentries
	var watch = playing("sentries")
	launch(watch)
	var posted: Array = wait(watch, Rules.ULTIMATE_WINDUP + 0.05)
	check(watch.turrets.size() == 2 and watch.turrets.all(func(t): return t.alive and t.hp == Rules.TURRET_LIVES), "Two sentries are posted, five lives each")
	check(watch.turrets.all(func(t): return absf(t.p.y) < 1.0), "They stand out in the middle of the ring, where any ball can reach them")
	check(posted.any(func(e): return e.kind == "sentries"), "The arena is told to build them")
	var wall_before = team_health(watch, 1)
	var firing: Array = wait(watch, 4.0)
	var rounds: Array = firing.filter(func(e): return e.kind == "turret_shot")
	check(rounds.size() >= 14, "They fire by themselves at the normal rate (%d rondas em 4 s)" % rounds.size())
	check(team_health(watch, 1) < wall_before, "And they chew through the rival wall (%d de dano)" % (wall_before - team_health(watch, 1)))
	var sentry_rounds: Array = watch.balls.filter(func(b): return b.owner == 0 and b.damage == Rules.TURRET_DAMAGE)
	check(sentry_rounds.all(func(b): return b.bounces >= Rules.MAX_BOUNCES and not b.get("boosted", false)), "Their rounds carry two of damage and never ricochet")
	# The rival shoots one down: five hits and it is gone.
	var doomed: Dictionary = watch.turrets[0]
	var knocks: Array = []
	for hit in range(Rules.TURRET_LIVES):
		watch.balls.append({"id": watch.next_id, "owner": 1, "p": doomed.p + Vector2(0, -1.0), "v": Vector2(0, Rules.BALL_SPEED),
			"bounces": 0, "boosted": false, "damage": 1, "ttl": 2.0, "power": 0, "ghost": false, "held": false})
		watch.next_id += 1
		knocks.append_array(wait(watch, 0.2))
	check(not doomed.alive and doomed.hp == 0, "Five rounds bring a sentry down")
	check(knocks.any(func(e): return e.kind == "turret_down"), "And its fall is announced, so the arena can blow it apart")
	check(watch.turrets.filter(func(t): return t.alive).size() == 1, "The other one keeps firing")
	# An open goal: with the wall gone, a sentry takes the shot.
	var open_goal = playing("sentries")
	launch(open_goal)
	wait(open_goal, Rules.ULTIMATE_WINDUP + 0.05)
	for brick in open_goal.bricks:
		if brick.team == 1:
			brick.hp = 0
			brick.alive = false
	var scoring: Array = wait(open_goal, 3.0)
	check(open_goal.scores[0] > 0 or scoring.any(func(e): return e.kind == "goal"), "With the wall down they put it in the empty net")
	# On the wire the sentries travel with everything else.
	var watcher = playing("sentries")
	check(watcher.apply_network_snapshot(watch.network_snapshot()), "The snapshot carrying sentries is accepted")
	check(watcher.turrets.size() == watch.turrets.filter(func(t): return true).size() and watcher.turrets[0].hp == watch.turrets[0].hp, "And the client sees them where they stand, with the health they have left")

	# ---------------------------------------------------------------- the kit carries it
	var shop = Powers.new()
	check(shop.loadout("sun_ray") == [shop.kit[0], shop.kit[1], "sun_ray"], "The ultimate always rides in the third slot")
	var empty = playing("")
	check(empty.power_id(0, 2) == "" and not empty.can_activate_power(0, 2), "A skin without an ultimate leaves the slot dead")
	var spent = playing("thunder")
	launch(spent)
	check(spent.powers[0].charge[2] == 0 and spent.power_charge_cost(0, 2) == Powers.ULTIMATE_CHARGE, "It costs %d bricks of charge, and spends them" % Powers.ULTIMATE_CHARGE)

	print("ULTIMATES_RESULT failures=", failures)
	quit(failures)
