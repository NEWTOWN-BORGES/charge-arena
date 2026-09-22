extends SceneTree
# The kit and the six new powers: shop purchases, the two equipped slots, and what each
# power does in the simulation (ghost rounds, laser, rebuild, mirror cape, goal shield,
# repulsor field). Config writes go to a temporary file, never to the real save.
const Rules = preload("res://scripts/arena_rules.gd")
const Powers = preload("res://scripts/powers.gd")
const Campaign = preload("res://scripts/campaign.gd")
const TMP = "res://tests/power_kit.tmp"
var failures = 0
var idle = {"move": Vector2.ZERO, "fire": false}

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func playing(kit: Array):
	var r = Rules.new()
	r.phase = "play"
	r.loadouts = [kit.duplicate(), kit.duplicate()]
	return r

func ready_power(r, index: int) -> void:
	r.powers[0].charge[index] = r.power_charge_cost(0, index)

func use(r, index: int) -> void:
	ready_power(r, index)
	r.step(1.0 / 60, [{"move": Vector2.ZERO, "fire": false, "power": index}, idle])

func standing(r, team: int) -> int:
	return r.bricks.filter(func(b): return b.team == team and b.alive).size()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# ---------------------------------------------------------------- the shop
	# The testing build hands out everything; these checks use the real progression.
	var testing = Powers.new()
	testing.unlock_all = true
	testing.load_preferences()
	check(Powers.CATALOG.all(func(e): return testing.is_owned(e.id)) and testing.bricks >= Powers.TEST_WALLET, "A testing build can hand over every power with a full wallet")
	testing.unlock_all = false
	testing.owned = Powers.STARTER_KIT.duplicate()
	testing.bricks = 0
	check(not Powers.UNLOCK_ALL_FOR_TESTS and testing.owned.size() == 2 and not testing.is_owned("laser"), "The shipped build starts with the two free powers and an empty wallet")
	var shop = Powers.new()
	shop.unlock_all = false
	shop.owned = Powers.STARTER_KIT.duplicate()
	shop.bricks = 0
	shop.config_path = TMP
	check(Powers.CATALOG.size() == 14 and Powers.CATALOG.all(func(e): return e.has("short") and e.about != "" and e.charge > 0), "Fourteen powers, each with a name, a charge cost and a description")
	check(Powers.CATALOG.filter(func(e): return e.kind == "defesa").size() == 5, "Five of them are defensive, and between the rest there is life, a buff and a debuff")
	var families: Array = Powers.CATALOG.map(func(e): return String(e.kind))
	check(["ataque", "defesa", "vida", "buff", "debuff"].all(func(k): return families.has(k)), "Every family has at least one power in it")
	check(shop.owned == Powers.STARTER_KIT and shop.kit == Powers.STARTER_KIT and shop.bricks == 0, "A new pilot owns the starter kit and no bricks")
	check(not shop.can_buy("laser") and not shop.buy("laser"), "A power cannot be bought without bricks")
	shop.add_bricks(300)
	check(not shop.can_buy("laser") and shop.can_buy("ghost"), "Only what the wallet covers can be bought (%d tijolos)" % shop.bricks)
	check(shop.buy("ghost") and shop.bricks == 150 and shop.is_owned("ghost"), "Buying pays the price and keeps the power")
	check(not shop.buy("ghost") and not shop.buy("nada"), "A power is bought once, and an unknown id never")
	check(not shop.equip(0, "laser") and shop.kit == Powers.STARTER_KIT, "A power that is not owned cannot be equipped")
	check(shop.equip(1, "ghost") and shop.kit == ["blast", "ghost"], "Equipping fills that slot")
	check(shop.equip(0, "ghost") and shop.kit == ["ghost", "blast"], "Equipping a power already in the kit swaps the two slots")
	check(not shop.equip(0, "ghost") and not shop.equip(2, "blast"), "Re-equipping the same slot, or a slot that does not exist, changes nothing")
	check(shop.loadout("") == ["ghost", "blast", ""], "The match loadout is the kit plus the ultimate slot")
	check(shop.save_preferences() == OK, "The shop saves")
	var restored = Powers.new()
	restored.unlock_all = false
	restored.config_path = TMP
	restored.load_preferences()
	check(restored.bricks == 150 and restored.owned == ["blast", "air", "ghost"] and restored.kit == ["ghost", "blast"], "Wallet, purchases and kit survive a restart")
	var edited = ConfigFile.new()
	edited.load(TMP)
	edited.set_value("powers", "owned", ["blast", "air", "inventado"])
	edited.set_value("powers", "kit", ["inventado", "laser"])
	edited.set_value("powers", "bricks", -20)
	edited.save(TMP)
	restored.load_preferences()
	check(restored.owned == ["blast", "air"] and restored.kit == Powers.STARTER_KIT and restored.bricks == 0, "An edited save falls back to what the pilot really owns")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))

	# ---------------------------------------------------------------- ghost rounds
	var r = playing(["ghost", "blast", ""])
	check(r.power_charge_cost(0, 0) == 3, "The ghost rounds are the cheapest power to charge")
	use(r, 0)
	check(r.powers[0].ghost_time == Rules.GHOST_SECONDS, "They last %.0f seconds" % Rules.GHOST_SECONDS)
	r.step(1.0 / 60, [{"move": Vector2.ZERO, "fire": true}, idle])
	var ghost: Dictionary = r.balls[0]
	check(ghost.ghost, "A round fired while they are up is a ghost round")
	# Straight at the central bumper: a ghost round goes through, a normal one bounces.
	var bumper: Vector2 = r.obstacles[0].p
	ghost.p = bumper - Vector2(0, 1.2)
	ghost.v = Vector2(0, Rules.BALL_SPEED)
	r.advance_ball(ghost, 0.2)
	check(ghost.v.y > 0 and ghost.bounces == 0, "It crosses the bumper without bouncing")
	var barrier_rules = playing(["ghost", "blast", ""])
	barrier_rules.barriers = [{"a": Vector2(-1.0, 0.6), "b": Vector2(1.0, 0.6)}]
	use(barrier_rules, 0)
	var through = {"id": 1, "owner": 0, "p": Vector2(0, -0.4), "v": Vector2(0, Rules.BALL_SPEED), "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": true}
	barrier_rules.balls = [through]
	barrier_rules.advance_ball(through, 0.06)
	check(through.v.y > 0 and through.bounces == 0, "It crosses a barrier as well")
	var solid = {"id": 2, "owner": 0, "p": Vector2(0, -0.4), "v": Vector2(0, Rules.BALL_SPEED), "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": false}
	barrier_rules.balls = [solid]
	barrier_rules.advance_ball(solid, 0.06)
	check(solid.v.y < 0 and solid.bounces == 1, "A normal round still bounces off that barrier")
	var wall = {"id": 3, "owner": 0, "p": Vector2(Rules.HALF_WIDTH - 0.2, 1.4), "v": Vector2.RIGHT * Rules.BALL_SPEED, "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": true}
	barrier_rules.balls = [wall]
	barrier_rules.advance_ball(wall, 0.05)
	check(wall.v.x < 0, "The arena wall still reflects a ghost round")
	for tick in range(roundi(Rules.GHOST_SECONDS * 60) + 2):
		r.step(1.0 / 60, [idle, idle])
	check(r.powers[0].ghost_time == 0, "They run out on their own")

	# ---------------------------------------------------------------- laser
	r = playing(["laser", "blast", ""])
	check(r.power_charge_cost(0, 0) == 11 and Powers.CATALOG.all(func(e): return e.charge <= 11), "The laser is the dearest power to charge")
	# An angle whose straight beam crosses the rival's bank; a ball there would ricochet first.
	r.players[0].angle = -0.34
	r.players[0].p = Rules.track_position(0, -0.34)
	var enemy_health = r.bricks.filter(func(b): return b.team == 1).reduce(func(total, b): return total + b.hp, 0)
	use(r, 0)
	check(r.powers[0].laser_time > 0 and r.events.any(func(e): return e.kind == "laser"), "Firing it opens a beam at once")
	var beams = 1
	for tick in range(roundi(Rules.LASER_SECONDS * 60) + 6):
		r.step(1.0 / 60, [idle, idle])
		beams += r.events.filter(func(e): return e.kind == "laser").size()
	var after = r.bricks.filter(func(b): return b.team == 1).reduce(func(total, b): return total + b.hp, 0)
	check(r.powers[0].laser_time == 0 and beams == roundi(Rules.LASER_SECONDS / Rules.LASER_TICK), "It bites %d times across %.1f seconds (%d)" % [roundi(Rules.LASER_SECONDS / Rules.LASER_TICK), Rules.LASER_SECONDS, beams])
	check(enemy_health - after >= Rules.LASER_DAMAGE * 2, "The beam eats through the bricks in front of it (%d de vida)" % (enemy_health - after))
	check(r.bricks.filter(func(b): return b.team == 0).all(func(b): return b.hp == Rules.BRICK_LIVES), "It never touches the pilot's own bricks")

	# ---------------------------------------------------------------- rebuild
	r = playing(["rebuild", "blast", ""])
	for i in range(r.bricks.size()):
		if r.bricks[i].team == 0:
			r.bricks[i].hp = 0
			r.bricks[i].alive = false
	use(r, 0)
	check(standing(r, 0) == Rules.REBUILD_BRICKS, "Rebuilding brings %d bricks back" % Rules.REBUILD_BRICKS)
	check(r.bricks.filter(func(b): return b.team == 0 and b.alive).all(func(b): return b.hp == Rules.BRICK_LIVES), "They come back whole")
	var restored_event = r.events.filter(func(e): return e.kind == "rebuild")
	check(restored_event.size() == 1 and restored_event[0].bricks.size() == Rules.REBUILD_BRICKS, "The rebuild is announced so the arena can light it up")
	var goal_row = r.bricks.filter(func(b): return b.team == 0 and b.alive).map(func(b): return absf(b.p.y))
	check(goal_row.min() > 0, "The bricks closest to the goal come back first")
	check(standing(r, 1) == Rules.BRICK_COUNT, "The rival's wall is untouched")

	# ---------------------------------------------------------------- mirror cape
	r = playing(["mirror", "blast", ""])
	use(r, 0)
	check(r.powers[0].mirror_time == Rules.MIRROR_SECONDS, "The cape lasts %.1f seconds" % Rules.MIRROR_SECONDS)
	var target = -1
	for i in range(r.bricks.size()):
		if r.bricks[i].team == 0 and r.bricks[i].alive:
			target = i
			break
	var shot = {"id": 9, "owner": 1, "p": r.bricks[target].p - Vector2(0, 0.6), "v": Vector2(0, Rules.BALL_SPEED), "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": false}
	r.balls = [shot]
	r.advance_ball(shot, 0.08)
	check(r.bricks[target].hp == Rules.BRICK_LIVES, "A caped brick takes no damage")
	check(shot.owner == 0 and shot.v.y < 0, "The shot turns around and changes sides")
	check(shot.boosted and shot.damage == Rules.BOOST_DAMAGE and is_equal_approx(shot.v.length(), Rules.BALL_SPEED * Rules.BOOST_SPEED), "It comes back as a boosted round: faster and twice as heavy")
	check(shot.bounces == Rules.MAX_BOUNCES, "And out of ricochets, so it has to find a target on the way home")
	check(r.events.any(func(e): return e.kind == "mirror"), "The reflection is announced, so the ball can change colour")
	for tick in range(roundi(Rules.MIRROR_SECONDS * 60) + 2):
		r.step(1.0 / 60, [idle, idle])
	check(r.powers[0].mirror_time == 0, "The cape fades on its own")

	# ---------------------------------------------------------------- the four walls
	r = playing(["walls", "blast", ""])
	var slabs: Array = r.wall_slabs[0]
	check(slabs.size() >= 2 and slabs.all(func(w): return absf(w.a.y - w.b.y) < 0.001 and w.b.x - w.a.x > 0.8), "A level slab stands in front of each bank of bricks")
	var gaps = 0
	for i in range(slabs.size() - 1):
		if slabs[i + 1].a.x - slabs[i].b.x > 0.5:
			gaps += 1
	check(gaps == slabs.size() - 1, "They leave gaps to shoot through, so the rival can still aim past them")
	# Each slab covers its own bank and stands between those bricks and the middle.
	for slab in slabs:
		var covered = r.bricks.filter(func(b): return b.team == 0 and b.p.x > slab.a.x - 0.4 and b.p.x < slab.b.x + 0.4)
		check(not covered.is_empty() and covered.all(func(b): return absf(b.p.y) > absf(slab.a.y)), "The slab at x %.1f covers %d bricks and stands in front of them" % [slab.a.x, covered.size()])
	var other_map = Rules.new()
	other_map.set_map({"id": "arc", "outline": "pinch", "boosters": true, "bricks": "arc", "barriers": [], "obstacles": []})
	check(other_map.wall_slabs[0] != r.wall_slabs[0] and not other_map.wall_slabs[0].is_empty(), "On another layout the walls follow that layout's banks")
	use(r, 0)
	check(r.powers[0].walls_time == Rules.WALLS_SECONDS and r.events.any(func(e): return e.kind == "walls"), "They stand for %.0f seconds and announce themselves" % Rules.WALLS_SECONDS)
	var slab: Dictionary = slabs[slabs.size() - 1]
	var stopped = {"id": 4, "owner": 1, "p": Vector2(slab.a.x + 0.4, slab.a.y - 1.0), "v": Vector2(0, Rules.BALL_SPEED), "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": false}
	r.balls = [stopped]
	r.advance_ball(stopped, 0.06)
	check(stopped.v.y < 0 and stopped.bounces == 1, "An enemy shot bounces off a raised wall")
	var through_gap = {"id": 5, "owner": 1, "p": Vector2((slabs[0].b.x + slabs[1].a.x) * 0.5, slabs[0].a.y - 1.0), "v": Vector2(0, Rules.BALL_SPEED), "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": false}
	r.balls = [through_gap]
	r.advance_ball(through_gap, 0.06)
	check(through_gap.v.y > 0 and through_gap.bounces == 0, "A shot threaded through a gap still gets past")
	var friendly = {"id": 6, "owner": 0, "p": Vector2(slab.a.x + 0.4, slab.a.y - 1.0), "v": Vector2(0, Rules.BALL_SPEED), "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": false}
	r.balls = [friendly]
	r.advance_ball(friendly, 0.06)
	check(friendly.v.y > 0 and friendly.bounces == 0, "The pilot's own shots pass through its own walls")
	for tick in range(roundi(Rules.WALLS_SECONDS * 60) + 2):
		r.step(1.0 / 60, [idle, idle])
	check(r.powers[0].walls_time == 0, "Then they go back into the ground")

	# ---------------------------------------------------------------- shock pulse
	r = playing(["stun", "blast", ""])
	r.balls = [
		{"id": 7, "owner": 0, "p": Vector2(0.4, 1.0), "v": Vector2(0, -Rules.BALL_SPEED), "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": false},
		{"id": 8, "owner": 1, "p": Vector2(-0.4, -1.0), "v": Vector2(0, Rules.BALL_SPEED), "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": false},
	]
	use(r, 0)
	check(r.balls.is_empty(), "The pulse sweeps every ball off the field")
	check(r.players[1].stun > Rules.STUN_POWER_SECONDS - 0.05 and r.players[0].stun == 0, "The rival is left stunned for %.0f seconds, the caster is not" % Rules.STUN_POWER_SECONDS)
	check(r.events.any(func(e): return e.kind == "shock") and r.events.any(func(e): return e.kind == "stun" and e.team == 1), "The wave and the stun are both announced")
	check(r.obstacle_stun > Rules.STUN_POWER_SECONDS - 0.05, "The moving bumpers seize up for the same time")
	var bumper_before: Vector2 = r.obstacles[0].p
	for tick in range(60):
		r.step(1.0 / 60, [idle, idle])
	check(r.obstacles[0].p.distance_to(bumper_before) < 0.001, "And they stay exactly where they were while it lasts")
	var free_shots = 0
	while r.players[1].stun > 0.05:
		r.step(1.0 / 60, [{"move": Vector2.ZERO, "fire": true}, r.ai_command()])
		free_shots += r.events.filter(func(e): return e.kind == "shot" and e.team == 1).size()
	check(free_shots == 0, "A stunned boss cannot fire back while it lasts")
	for tick in range(30):
		r.step(1.0 / 60, [idle, idle])
	check(r.players[1].stun == 0 and r.obstacle_stun == 0, "Pilot and bumpers both come back to life once it passes")
	var moving_again: Vector2 = r.obstacles[0].p
	for tick in range(30):
		r.step(1.0 / 60, [idle, idle])
	check(r.obstacles[0].p.distance_to(moving_again) > 0.01, "The bumpers pick up their route again")

	# ---------------------------------------------------------------- the boss kits
	# One kit per boss in the table; the station pilots carry their own on the level itself.
	var boss_levels: Array = range(Campaign.LEVELS.size()).filter(func(i): return not Campaign.is_minor(i))
	check(Campaign.BOSS_KITS.size() == boss_levels.size(), "Every boss names its kit in the table (%d de %d)" % [Campaign.BOSS_KITS.size(), boss_levels.size()])
	check(range(Campaign.LEVELS.size()).filter(func(i): return Campaign.is_minor(i)).all(func(i): return Campaign.boss_kit(i) == Array(Campaign.LEVELS[i].kit)), "And every station pilot carries its own")
	check(Campaign.BOSS_KITS.all(func(kit): return kit.size() == Powers.KIT_SIZE and kit.all(func(id): return Powers.index_of(id) >= 0)), "Each kit holds two powers from the catalogue")
	var early: Array = Campaign.boss_kit(0)
	var late: Array = Campaign.boss_kit(Campaign.LEVELS.size() - 1)
	check(early == ["blast", "air"] and late.has("laser") and late.has("magnet"), "The first boss only shoots; the last one brings the laser and the magnet")
	check(Campaign.BOSS_KITS.any(func(kit): return kit.any(func(id): return Powers.entry(id).kind == "defesa")), "Later bosses defend as well as attack")
	var defended = playing(["blast", "rebuild", ""])
	defended.ai_level = 2
	defended.loadouts[1] = ["blast", "rebuild", ""]
	defended.powers[1].charge = [99, 99, 99]
	for i in range(defended.bricks.size()):
		if defended.bricks[i].team == 1 and i % 8 != 0:
			defended.bricks[i].hp = 0
			defended.bricks[i].alive = false
	var rebuilt = false
	for tick in range(240):
		defended.powers[1].charge = [99, 99, 99]
		defended.step(1.0 / 60, [idle, defended.ai_command()])
		if defended.events.any(func(e): return e.kind == "rebuild" and e.team == 1):
			rebuilt = true
			break
	check(rebuilt, "A boss with its wall in ruins rebuilds it")

	print("POWER_KIT_RESULT failures=", failures)
	quit(failures)
