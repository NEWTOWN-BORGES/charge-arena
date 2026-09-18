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
	check(Powers.ULTIMATES.size() == 5 and Powers.ULTIMATES.all(func(u): return u.charge == Powers.ULTIMATE_CHARGE and u.price == 0), "Five ultimates, none of them for sale and all charging the same")
	check(Powers.ULTIMATES.all(func(u): return Powers.is_ultimate(u.id) and not Powers.entry(u.id).is_empty()), "Each one is found by id, like any other power")
	var carriers = Skins.CATALOG.filter(func(s): return s.ultimate != "")
	check(carriers.size() == 5 and carriers.all(func(s): return Powers.is_ultimate(s.ultimate)), "Five skins carry one each")
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
