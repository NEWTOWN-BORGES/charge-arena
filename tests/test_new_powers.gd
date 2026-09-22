extends SceneTree
# The five powers added to the shop: the weld, the thorns, the frost, the magnet and the
# armour piercing round. Each one is measured against the same match without it.
const Rules = preload("res://scripts/arena_rules.gd")
const Powers = preload("res://scripts/powers.gd")
var failures = 0
var idle = {"move": Vector2.ZERO, "fire": false}

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func playing(id: String):
	var r = Rules.new()
	r.phase = "play"
	r.loadouts = [[id, "air", ""], [id, "air", ""]]
	return r

func launch(r, team: int = 0) -> void:
	r.powers[team].charge[0] = r.power_charge_cost(team, 0)
	var own = {"move": Vector2.ZERO, "fire": false, "power": 0}
	r.step(1.0 / 60, [own, idle] if team == 0 else [idle, own])

func wait(r, seconds: float) -> Array:
	var seen: Array = []
	for tick in range(roundi(seconds * 60)):
		r.step(1.0 / 60, [idle, idle])
		seen.append_array(r.events)
	return seen

func graze(r, keep: int, from: Vector2, heading: Vector2) -> float:
	# Fire one round past the only brick left standing and report how close it came.
	only_brick(r, keep)
	r.balls.clear()
	r.balls.append({"id": 7002, "owner": 0, "p": from, "v": heading * Rules.BALL_SPEED, "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": true})
	var nearest := INF
	for tick in range(12):
		r.step(1.0 / 60, [idle, idle])
		for ball in r.balls:
			if ball.id == 7002:
				nearest = minf(nearest, ball.p.distance_to(r.bricks[keep].p))
	return nearest

func only_brick(r, keep: int) -> void:
	# Leave one enemy brick standing, so what the round does is about the power under test
	# and not about whichever brick of forty happened to be in the way.
	for index in range(r.bricks.size()):
		if r.bricks[index].team == 1 and index != keep:
			r.bricks[index].hp = 0
			r.bricks[index].alive = false

func run() -> void:
	check(Powers.CATALOG.filter(func(e): return e.id in ["weld", "thorns", "freeze", "magnet", "pierce"]).size() == 5, "All five are in the shop, with a price of their own")
	check(Powers.CATALOG.filter(func(e): return e.id in ["weld", "thorns", "freeze", "magnet", "pierce"]).all(func(e): return e.price > 0 and e.charge > 0 and e.about.length() > 60), "Each one costs tijolos, charges, and says what it does")

	# ---------------------------------------------------------------------- solda
	var weld = playing("weld")
	for brick in weld.bricks:
		if brick.team == 0:
			brick.hp = 1
	weld.bricks[0].hp = 0
	weld.bricks[0].alive = false
	var before: int = weld.team_health(0)
	launch(weld)
	check(weld.team_health(0) - before == weld.brick_count(0) * Rules.WELD_HEAL, "Solda: one life back on every brick of yours still standing")
	check(not weld.bricks[0].alive, "Solda: and nothing at all for the ones already down")
	var full = playing("weld")
	var whole: int = full.team_health(0)
	launch(full)
	check(full.team_health(0) == whole, "Solda: a wall with nothing wrong with it is left alone")

	# -------------------------------------------------------------------- espinhos
	var spikes = playing("thorns")
	launch(spikes)
	check(spikes.powers[0].thorns_time > 0, "Espinhos: the spikes come out")
	var lives: int = spikes.players[1].hp
	var victim: int = spikes.bricks.find_custom(func(b): return b.team == 0 and b.alive)
	spikes.bricks[victim].hp = 1
	spikes.balls.append({"id": 7001, "owner": 1, "p": spikes.bricks[victim].p + Vector2(0, 0.5), "v": Vector2.DOWN * Rules.BALL_SPEED, "bounces": 0, "boosted": false, "damage": 1, "ttl": 2.0, "power": 0, "ghost": true})
	wait(spikes, 0.3)
	check(not spikes.bricks[victim].alive, "Espinhos: the round still breaks the brick")
	check(spikes.players[1].hp == lives - Rules.THORNS_BITE, "Espinhos: and it costs the pilot that fired it a life")

	# ------------------------------------------------------------------------ gelo
	var frost = playing("freeze")
	launch(frost)
	check(frost.powers[1].freeze_time > 0 and frost.powers[0].freeze_time <= 0, "Gelo: the frost lands on the rival, not on you")
	var warm = playing("freeze")
	var push = {"move": Vector2(1, 0), "fire": false}
	for tick in range(30):
		warm.step(1.0 / 60, [idle, push])
	var free_walk: float = warm.players[1].angle
	frost.players[1].angle = 0.0
	for tick in range(30):
		frost.step(1.0 / 60, [idle, push])
	check(frost.players[1].angle < free_walk * 0.6, "Gelo: it walks at well under half pace (%.3f contra %.3f)" % [frost.players[1].angle, free_walk])
	frost.players[1].cooldown = 0.0
	frost.shoot(1)
	check(frost.players[1].cooldown > Rules.FIRE_INTERVAL * 1.5, "Gelo: and waits far longer between rounds")
	# And the whole kit is shut while it holds: that is what the frost is paid for.
	for slot in range(Rules.POWER_SLOTS):
		frost.powers[1].charge[slot] = frost.power_charge_cost(1, slot)
		frost.powers[1].cool[slot] = 0.0
	check(not range(Rules.POWER_SLOTS).any(func(i): return frost.can_activate_power(1, i)), "Gelo: and it cannot reach for a single power while frozen")
	wait(frost, Rules.FREEZE_SECONDS)
	check(frost.powers[1].freeze_time <= 0, "Gelo: five seconds and the frost is gone")
	check(frost.can_activate_power(1, 0), "Gelo: and the kit answers again the moment it lifts")

	# ------------------------------------------------------------------------ iman
	var pull = playing("magnet")
	launch(pull)
	check(pull.powers[0].magnet_time > 0, "Íman: the magnet comes on")
	# A near miss, which is what the magnet is for: the same shot is run twice, once with
	# the magnet on and once without, and the one with it has to end up closer to the brick.
	var brick_index: int = pull.bricks.find_custom(func(b): return b.team == 1 and b.alive)
	var target: Vector2 = pull.bricks[brick_index].p
	var from: Vector2 = target + Vector2(0.85, 3.9)
	var grazing: Vector2 = Vector2(0, -1)
	var with_pull: float = graze(pull, brick_index, from, grazing)
	var plain = playing("magnet")
	var without: float = graze(plain, brick_index, from, grazing)
	check(with_pull < without, "Íman: the round bends onto a brick it would have grazed (%.3f contra %.3f)" % [with_pull, without])
	check(without - with_pull > 0.1, "Íman: and by enough to matter, not by a whisker")

	# ------------------------------------------------------------------ perfurante
	var drill = playing("pierce")
	launch(drill)
	check(drill.powers[0].pierce_time > 0, "Perfurante: the rounds are armed")
	var front: int = drill.bricks.find_custom(func(b): return b.team == 1 and b.alive)
	only_brick(drill, front)
	drill.bricks[front].hp = 1
	drill.balls.clear()
	# The rival's wall sits at negative y, so an attacking round comes at it from below.
	drill.balls.append({"id": 7003, "owner": 0, "p": drill.bricks[front].p + Vector2(0, 0.6), "v": Vector2.UP * Rules.BALL_SPEED, "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": true})
	wait(drill, 0.2)
	check(not drill.bricks[front].alive, "Perfurante: the brick breaks")
	check(drill.balls.any(func(b): return b.id == 7003), "Perfurante: and the round carries on through instead of stopping")
	var blunt = playing("air")
	var last: int = blunt.bricks.find_custom(func(b): return b.team == 1 and b.alive)
	only_brick(blunt, last)
	blunt.bricks[last].hp = 1
	blunt.balls.append({"id": 7004, "owner": 0, "p": blunt.bricks[last].p + Vector2(0, 0.6), "v": Vector2.UP * Rules.BALL_SPEED, "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 0, "ghost": true})
	wait(blunt, 0.2)
	check(not blunt.bricks[last].alive and not blunt.balls.any(func(b): return b.id == 7004), "Perfurante: without it, the same round stops on the brick it broke")

	print("NEW_POWERS_RESULT failures=", failures)
	quit(failures)
