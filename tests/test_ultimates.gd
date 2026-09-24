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

func hold_fire(r, seconds: float) -> Array:
	# The stick still, the trigger down: what the pilot actually does for most of a match.
	var firing = {"move": Vector2.ZERO, "fire": true}
	var seen: Array = []
	for tick in range(roundi(seconds * 60)):
		r.step(1.0 / 60, [firing, idle])
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
	check(Powers.ULTIMATES.size() == 10 and Powers.ULTIMATES.all(func(u): return u.charge == Powers.ULTIMATE_CHARGE and u.price == 0), "Ten ultimates, none of them for sale and all charging the same")
	check(Powers.ULTIMATES.all(func(u): return Powers.is_ultimate(u.id) and not Powers.entry(u.id).is_empty()), "Each one is found by id, like any other power")
	var carriers = Skins.CATALOG.filter(func(s): return s.ultimate != "")
	check(carriers.size() == Skins.CATALOG.size() - 1 and carriers.all(func(s): return Powers.is_ultimate(s.ultimate)), "Every skin but one carries an ultimate of its own")
	check(String(Skins.CATALOG[0].ultimate) == "", "The standard pilot is the one without: it is the training opponent, not a boss")
	var ids: Array = carriers.map(func(s): return String(s.ultimate))
	ids.sort()
	check(Powers.ULTIMATES.all(func(u): return ids.count(u.id) == 1) and ids.count("b_forge") == 1 and range(1, ids.size()).all(func(i): return ids[i] != ids[i - 1]), "Each boss has its ultimate and Aurel carries Forge")
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
	var mirror_before: Array = reef.bricks.slice(reef.bricks.size() / 2).map(func(b): return b.hp)
	launch(reef)
	# The walls cross over in the air first, and the lives change hands when they land.
	var reef_events: Array = wait(reef, Rules.ULTIMATE_WINDUP + Rules.PLUNDER_SWAP + 0.1)
	check(standing(reef, 0) == theirs_before and standing(reef, 1) == mine_before and theirs_before != mine_before, "The two walls swap: %d bricks for %d" % [theirs_before, mine_before])
	check(reef.bricks.slice(0, reef.bricks.size() / 2).map(func(b): return b.hp) == mirror_before, "Brick for brick, in the mirrored place")
	check(reef_events.any(func(e): return e.kind == "plunder"), "The flight is announced so the arena can flash")
	check(reef_events.any(func(e): return e.kind == "plunder_land"), "And so is the landing, which is when they change hands")

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
	# The release: one wave, not a fan of rounds. Everything the core was holding is thrown
	# back out with it, so nobody loses the shots they had in play.
	var caught: int = hole.balls.filter(func(b): return b.get("held", false)).size()
	var release: Array = run_until(hole, "shock_wave", Rules.SINGULARITY_PULL + 0.5)
	var blow: Array = release.filter(func(e): return e.kind == "shock_wave")
	check(blow.size() == 1, "The core lets go exactly once")
	check(release.any(func(e): return e.kind == "swallow"), "Each round swallowed is announced")
	check(caught > 0 and hole.balls.all(func(b): return not b.get("held", false)), "Everything it had a hold of went into the blow (%d)" % caught)
	var core_at: Vector2 = hole.players[0].p
	check(hole.balls.all(func(b): return (b.p - core_at).normalized().dot(b.v.normalized()) > 0.9), "Anything still in flight is thrown outwards with it")
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
	check(watch.turrets.size() == 2 and watch.turrets.all(func(t): return t.alive and t.hp == Rules.TURRET_LIVES), "Two sentries are posted, two lives each")
	check(watch.turrets.all(func(t): return absf(t.p.y) < 1.0), "They stand out in the middle of the ring, where any ball can reach them")
	check(posted.any(func(e): return e.kind == "sentries"), "The arena is told to build them")
	var wall_before = team_health(watch, 1)
	var firing: Array = wait(watch, 4.0)
	var rounds: Array = firing.filter(func(e): return e.kind == "turret_shot")
	var expected = int(4.0 / Rules.TURRET_INTERVAL) * 2 - 2
	check(rounds.size() >= expected, "They fire by themselves, on their own slow clock (%d rondas em 4 s)" % rounds.size())
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
	check(not doomed.alive and doomed.hp == 0, "Two rounds bring a sentry down")
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

	# ---------------------------------------------------------------- the bosses use theirs
	var Campaign = load("res://scripts/campaign.gd")
	var waits: Array = []
	for level in range(Campaign.LEVELS.size()):
		waits.append(float(Campaign.ai_profile(level, 1).ultimate_wait))
	var ramps = true
	for i in range(1, waits.size()):
		ramps = ramps and waits[i] <= waits[i - 1] + 0.001
	check(ramps and waits[0] > waits[waits.size() - 1] * 1.5, "The later the level, the sooner the boss reaches for its ultimate (%.0f s no primeiro, %.0f s no último)" % [waits[0], waits[waits.size() - 1]])
	check(float(Campaign.ai_profile(8, 2).ultimate_wait) < float(Campaign.ai_profile(8, 0).ultimate_wait), "And DIFÍCIL brings it out sooner than FÁCIL")

	# A boss left to its own devices, with nobody handing it charge, still brings out its
	# kit and its ultimate: the charge used to come only from the bricks it broke, and in a
	# hundred seconds of play it never reached twenty.
	var alone = Rules.new()
	alone.set_map(Campaign.LEVELS[7].map)
	alone.phase = "play"
	alone.ai_profile = Campaign.ai_profile(7, 1)
	alone.loadouts = [["blast", "air", ""], Campaign.boss_kit(7) + ["thunder"]]
	var kit_uses = 0
	var cast = 0
	for tick in range(60 * 100):
		alone.step(1.0 / 60, [{"move": Vector2(sin(tick * 0.011), 0), "fire": true}, alone.ai_command()])
		for event in alone.events:
			if int(event.get("team", -1)) != 1:
				continue
			if event.kind == "power":
				kit_uses += 1
			elif event.kind == "ultimate":
				cast += 1
		if alone.phase != "play":
			alone.phase = "play"
	check(kit_uses >= 6, "A boss winds its kit up on its own and spends it (%d poderes em 100 s)" % kit_uses)
	check(cast >= 1 and cast <= 4, "And brings its ultimate out, without spamming it (%d vezes)" % cast)

	# The last boss, played against a pilot that fights back, actually fires it.
	var arena = playing("sun_ray")
	arena.loadouts = [["blast", "air", ""], ["laser", "stun", "sun_ray"]]
	arena.ai_profile = Campaign.ai_profile(10, 1)
	var unleashed = -1.0
	var too_early = false
	for tick in range(60 * 90):
		if tick % 30 == 0:
			for slot in range(3):
				arena.powers[1].charge[slot] = mini(arena.powers[1].charge[slot] + 1, Powers.ULTIMATE_CHARGE)
		arena.step(1.0 / 60, [{"move": Vector2(sin(tick * 0.012), 0), "fire": true}, arena.ai_command()])
		for event in arena.events:
			if event.kind == "ultimate" and event.team == 1 and unleashed < 0:
				unleashed = arena.elapsed
				too_early = arena.elapsed < float(arena.ai_profile.ultimate_wait)
		if unleashed >= 0:
			break
	check(unleashed >= 0, "The boss of the last level unleashes its ultimate on its own (%s)" % ("nunca" if unleashed < 0 else "%.1f s" % unleashed))
	check(not too_early, "And not before the level says it may")

	# A sentry boss puts its platforms down; a plunder boss only trades when it is behind.
	var clockwork = playing("sentries")
	clockwork.loadouts = [["blast", "air", ""], ["blast", "air", "sentries"]]
	clockwork.ai_profile = Campaign.ai_profile(1, 1)
	clockwork.elapsed = float(clockwork.ai_profile.ultimate_wait) + 1.0
	for slot in range(3):
		clockwork.powers[1].charge[slot] = Powers.ULTIMATE_CHARGE
	check(clockwork.ai_ultimate(clockwork.ai_profile, false) == 2, "The Relojoeiro reaches for its sentries as soon as it may")
	var corsair = playing("plunder")
	corsair.loadouts = [["blast", "air", ""], ["blast", "air", "plunder"]]
	corsair.ai_profile = Campaign.ai_profile(9, 1)
	corsair.elapsed = float(corsair.ai_profile.ultimate_wait) + 1.0
	for slot in range(3):
		corsair.powers[1].charge[slot] = Powers.ULTIMATE_CHARGE
	check(corsair.ai_ultimate(corsair.ai_profile, false) < 0, "The Corsário does not trade a wall that is already the better one")
	var knocked = 0
	for brick in corsair.bricks:
		if brick.team == 1 and knocked < 22:
			brick.hp = 0
			brick.alive = false
			knocked += 1
	check(corsair.ai_ultimate(corsair.ai_profile, false) == 2, "But it trades the moment its own wall is the worse one")

	# ---------------------------------------------------------------- the kit carries it
	var shop = Powers.new()
	check(shop.loadout("sun_ray") == [shop.kit[0], shop.kit[1], "sun_ray"], "The ultimate always rides in the third slot")
	var empty = playing("")
	check(empty.power_id(0, 2) == "" and not empty.can_activate_power(0, 2), "A skin without an ultimate leaves the slot dead")
	var spent = playing("thunder")
	launch(spent)
	check(spent.power_charge_cost(0, 2) == Powers.ULTIMATE_CHARGE and spent.powers[0].charge[2] == Powers.ULTIMATE_CHARGE, "It costs %d bricks to open, and they are not taken back" % Powers.ULTIMATE_CHARGE)
	check(is_equal_approx(spent.powers[0].cool[2], Powers.ULTIMATE_WAIT) and not spent.can_activate_power(0, 2), "And then it sits out %d seconds before it can be called again" % Powers.ULTIMATE_WAIT)

	# --------------------------------------- the three that open the campaign
	# Sobrecarga, now the Alquimista's: turbocharged rounds, twice as fast, while it lasts.
	var surge = playing("surge")
	aim_at_bricks(surge)
	var plain_health: int = team_health(surge, 1)
	hold_fire(surge, 3.0)
	var plain_damage: int = plain_health - team_health(surge, 1)
	surge = playing("surge")
	aim_at_bricks(surge)
	launch(surge)
	wait(surge, Rules.ULTIMATE_WINDUP + 0.05)
	check(surge.powers[0].surge_time > 0, "Sobrecarga: the gauntlet is overloaded once the glow ends")
	var loaded: int = team_health(surge, 1)
	var storm: Array = hold_fire(surge, 3.0)
	var surged_damage: int = loaded - team_health(surge, 1)
	check(storm.filter(func(e): return e.kind == "shot" and e.team == 0).size() > 0, "Sobrecarga: the pilot keeps firing under it")
	check(surge.balls.all(func(b): return b.owner != 0 or b.boosted), "Sobrecarga: every round it hands out comes turbocharged")
	check(surged_damage > plain_damage, "Sobrecarga: and it takes the wall down faster (%d contra %d em 3 s)" % [surged_damage, plain_damage])
	hold_fire(surge, Rules.SURGE_SECONDS)
	check(surge.powers[0].surge_time <= 0, "Sobrecarga: it runs out on its own")

	# Rajada do Farol: the fan of the Leque, five times over.
	var volley = playing("volley")
	aim_at_bricks(volley)
	var fan_before: int = team_health(volley, 1)
	var first_id: int = volley.next_id
	launch(volley)
	var fired: Array = wait(volley, Rules.ULTIMATE_WINDUP + Rules.VOLLEY_SECONDS + 0.2)
	var fans: Array = fired.filter(func(e): return e.kind == "volley")
	check(fans.size() == Rules.VOLLEY_WAVES, "Rajada: five waves leave the lantern (%d)" % fans.size())
	check(volley.next_id - first_id == Rules.VOLLEY_WAVES * Rules.AIR_PELLETS, "Rajada: five balls a wave, twenty-five in all (%d)" % (volley.next_id - first_id))
	# A pellet that has met a bumper on the way is a boosted round and bites like one.
	check(volley.balls.filter(func(b): return b.owner == 0 and not b.boosted).all(func(b): return b.damage == Rules.VOLLEY_DAMAGE), "Rajada: each pellet bites for one")
	wait(volley, 1.6)
	check(fan_before - team_health(volley, 1) > 0, "Rajada: and the wall feels it (%d de vida)" % (fan_before - team_health(volley, 1)))

	# Couraca de cristal: every blow on the miner's wall loses a life on the way in.
	var armour = playing("plating")
	launch(armour)
	wait(armour, Rules.ULTIMATE_WINDUP + 0.05)
	check(armour.powers[0].plating_time > 0, "Couraca: the plating closes once the glow ends")
	var mine_index: int = armour.bricks.find_custom(func(b): return b.team == 0 and b.alive)
	var plated_hp: int = armour.bricks[mine_index].hp
	armour.damage_brick(mine_index, 1, 1, armour.bricks[mine_index].p)
	check(armour.bricks[mine_index].hp == plated_hp, "Couraca: an ordinary round stops doing anything at all")
	armour.damage_brick(mine_index, 3, 1, armour.bricks[mine_index].p)
	check(plated_hp - armour.bricks[mine_index].hp == 2, "Couraca: and a blow of three lands as two")
	var theirs_index: int = armour.bricks.find_custom(func(b): return b.team == 1 and b.alive)
	var bare_hp: int = armour.bricks[theirs_index].hp
	armour.damage_brick(theirs_index, 1, 0, armour.bricks[theirs_index].p)
	check(bare_hp - armour.bricks[theirs_index].hp == 1, "Couraca: the rival's wall is not plated by it")
	wait(armour, Rules.PLATING_SECONDS)
	check(armour.powers[0].plating_time <= 0, "Couraca: seven seconds and the crystal is gone")

	# Onda de choque: the vortex lets go in one blow, worst on the front row.
	var vortex = playing("singularity")
	var ranks: Dictionary = vortex.brick_ranks(1)
	var front: int = -1
	var third: int = -1
	for index in ranks.keys():
		if int(ranks[index]) == 0 and front < 0:
			front = index
		if int(ranks[index]) >= 2 and third < 0:
			third = index
	check(front >= 0 and third >= 0, "Onda: the rival's wall is four rows deep, so there is a front and a back")
	var front_hp: int = vortex.bricks[front].hp
	var third_hp: int = vortex.bricks[third].hp
	var vortex_before: int = team_health(vortex, 1)
	launch(vortex)
	var blast: Array = wait(vortex, Rules.ULTIMATE_WINDUP + Rules.SINGULARITY_PULL + 0.3)
	check(blast.any(func(e): return e.kind == "shock_wave"), "Onda: one wave leaves the core, not a fan of rounds")
	check(front_hp - vortex.bricks[front].hp == Rules.SHOCK_FRONT, "Onda: three off the front row")
	check(vortex.players[1].hp < Rules.PLAYER_LIVES, "Onda: it runs past the wall and catches the pilot too")
	# The front line is taken whole; the rows behind it are caught in patches.
	var front_row: Array = ranks.keys().filter(func(i): return int(ranks[i]) == 0)
	check(front_row.all(func(i): return vortex.bricks[i].hp <= front_hp - Rules.SHOCK_FRONT or not vortex.bricks[i].alive), "Onda: every brick of the front row is caught, not a sample of them")
	var wave: Dictionary = blast.filter(func(e): return e.kind == "shock_wave")[0]
	check(wave.marks.size() > 0 and wave.marks.all(func(m): return m.has("p") and m.has("bite")), "Onda: each brick it catches is named, with what it took, so the arena can show it")
	for rank in range(1, 3):
		var tier: Array = ranks.keys().filter(func(i): return int(ranks[i]) == rank)
		if tier.is_empty():
			continue
		var bitten: int = tier.filter(func(i): return vortex.bricks[i].hp < 3).size()
		check(bitten == tier.size(), "Onda: row %d is taken whole, not sampled (%d de %d)" % [rank, bitten, tier.size()])
	check(third_hp - vortex.bricks[third].hp == Rules.SHOCK_REST, "Onda: and one off the rows further back")
	print("ONDA: %d de vida na muralha" % (vortex_before - team_health(vortex, 1)))

	# The rows are counted over the wall still standing, which is the whole point: by the
	# time this is charged the original front rows are usually rubble.
	var late = playing("singularity")
	var late_ranks: Dictionary = late.brick_ranks(1)
	for index in late_ranks.keys():
		if int(late_ranks[index]) < 2:
			late.bricks[index].hp = 0
			late.bricks[index].alive = false
	var survivors: Dictionary = late.brick_ranks(1)
	var new_front: Array = survivors.keys().filter(func(i): return int(survivors[i]) == 0)
	check(not new_front.is_empty() and new_front.all(func(i): return int(late_ranks[i]) == 2), "Onda: with the first two rows already gone, the third becomes the front line")
	var mark_hp: int = late.bricks[new_front[0]].hp
	launch(late)
	wait(late, Rules.ULTIMATE_WINDUP + Rules.SINGULARITY_PULL + 0.3)
	check(mark_hp - late.bricks[new_front[0]].hp == Rules.SHOCK_FRONT, "Onda: and it takes the full three, not the one its old row would have given")

	# Pilhagem: the two walls cross over in the air before the lives change hands.
	var raid = playing("plunder")
	for brick in raid.bricks:
		if brick.team == 1:
			brick.hp = 1
	var stolen: int = team_health(raid, 1)
	var given: int = team_health(raid, 0)
	launch(raid)
	wait(raid, Rules.ULTIMATE_WINDUP + 0.05)
	check(raid.powers[0].plunder_time > 0, "Pilhagem: the walls take off once the glow ends")
	wait(raid, Rules.PLUNDER_SWAP * 0.5)
	var homes_left: int = raid.bricks.filter(func(b): return b.p.distance_to(b.home) > 0.5).size()
	check(homes_left > raid.bricks.size() * 0.7, "Pilhagem: half way over, the walls are in the air (%d de %d)" % [homes_left, raid.bricks.size()])
	check(team_health(raid, 1) == stolen, "Pilhagem: and the lives have not changed hands yet")
	var landing: Array = wait(raid, Rules.PLUNDER_SWAP)
	check(landing.any(func(e): return e.kind == "plunder_land"), "Pilhagem: they land together")
	check(team_health(raid, 0) == stolen and team_health(raid, 1) == given, "Pilhagem: and that is when the two walls change hands")
	check(raid.bricks.all(func(b): return b.p.is_equal_approx(b.home)), "Pilhagem: every brick back on a spot of its own")
	# The wall has to come down again whatever ends the flight, not only a clean landing.
	for ending in ["goal", "finished", "countdown"]:
		var cut = playing("plunder")
		launch(cut)
		wait(cut, Rules.ULTIMATE_WINDUP + Rules.PLUNDER_SWAP * 0.5)
		check(cut.bricks.any(func(b): return b.p.distance_to(b.home) > 0.3), "Pilhagem: half way over, the wall is in the air (%s)" % ending)
		cut.phase = ending
		cut.timer = 1.0
		wait(cut, 0.5)
		check(cut.bricks.all(func(b): return b.p.is_equal_approx(b.home)), "Pilhagem: and it lands back home when the round turns to %s" % ending)

	print("ULTIMATES_RESULT failures=", failures)
	quit(failures)
