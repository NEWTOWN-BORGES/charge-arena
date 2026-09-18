extends SceneTree
# Three powers earned by destroying bricks: area blast, machine gun and air burst.
# Charges, activation, effects, round resets, network state and the HUD buttons.
const Rules = preload("res://scripts/arena_rules.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Powers = preload("res://scripts/powers.gd")
const TMP = "res://tests/powers.tmp"
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

func settle() -> void:
	for i in range(3):
		await process_frame

func drawn_arena(game) -> Rect2:
	# Project the measured stadium bounds through the real camera, offsets included.
	var cam: Camera3D = game.arena.camera
	var basis = cam.global_transform.basis
	var b: Rect2 = game.arena.view_bounds
	var result = Rect2()
	var first = true
	for corner in [b.position, b.end, Vector2(b.position.x, b.end.y), Vector2(b.end.x, b.position.y)]:
		var world = cam.global_position + basis.x * corner.x + basis.y * corner.y - basis.z * 20.0
		var pixel = cam.unproject_position(world)
		result = Rect2(pixel, Vector2.ZERO) if first else result.expand(pixel)
		first = false
	return result

func first_brick(r, team: int) -> int:
	for i in range(r.bricks.size()):
		if r.bricks[i].team == team and r.bricks[i].alive:
			return i
	return -1

func team_health(r, team: int) -> int:
	var total = 0
	for brick in r.bricks:
		if brick.team == team:
			total += brick.hp
	return total

func angle_hitting_brick(r) -> float:
	for i in range(61):
		var angle = -0.6 + i * 0.02
		if r.predict_shot(0, angle).get("kind", "") == "brick":
			return angle
	return INF

func playing(kit: Array = ["blast", "rapid", "air"]):
	var r = Rules.new()
	r.phase = "play"
	# Both sides carry the same three powers unless a check says otherwise.
	r.loadouts = [kit.duplicate(), kit.duplicate()]
	return r

func cost(r, index: int) -> int:
	return r.power_charge_cost(0, index)

func fire_power(r, index: int) -> void:
	r.step(1.0 / 60, [{"move": Vector2.ZERO, "fire": false, "power": index}, idle])

func count_boss_powers(level: int, seconds: float) -> Array:
	# Charges are topped up every tick, so this measures the pace, not the income.
	var r = playing()
	r.ai_level = level
	var used: Array = []
	for tick in range(roundi(seconds * 60)):
		r.powers[1].charge = [99, 99, 99]
		r.step(1.0 / 60, [idle, r.ai_command()])
		for event in r.events:
			if event.kind == "power" and event.team == 1:
				used.append(event.power)
		if r.phase != "play":
			r.phase = "play"
	return used

func run() -> void:
	# Charges: one per destroyed enemy brick, capped at each power's own cost.
	var r = playing()
	check(r.powers.size() == 2 and r.powers[0].charge == [0, 0, 0] and r.powers[0].destroyed == 0, "A match starts with every power empty")
	check([cost(r, 0), cost(r, 1), cost(r, 2)] == [5, 10, 12] and Powers.CATALOG.size() == 9, "The nine powers charge at their own cost: blast 5, machine gun 10, air burst 12")
	for i in range(3):
		var index = first_brick(r, 1)
		r.damage_brick(index, Rules.BRICK_LIVES, 0, r.bricks[index].p)
	check(r.powers[0].charge == [3, 3, 3] and r.powers[0].destroyed == 3 and r.powers[1].charge == [0, 0, 0], "Each destroyed enemy brick charges all three powers by one")
	var own = first_brick(r, 0)
	r.damage_brick(own, Rules.BRICK_LIVES, 0, r.bricks[own].p)
	check(r.powers[0].charge == [3, 3, 3], "Bricks of your own team never charge a power")
	for i in range(20):
		var index = first_brick(r, 1)
		r.damage_brick(index, Rules.BRICK_LIVES, 0, r.bricks[index].p)
	check(r.powers[0].charge == [5, 10, 12] and r.powers[0].destroyed == 23, "Charges stop at the cost of each power")
	check(r.events.any(func(e): return e.kind == "power_ready" and e.power == 2 and e.team == 0), "Filling a power announces it")

	# Gating: enough charge, alive, playing, and one power at a time.
	r = playing()
	check(not r.can_activate_power(0, 0) and not r.activate_power(0, 0), "An empty power cannot be used")
	r.powers[0].charge = [5, 10, 12]
	check(r.can_activate_power(0, 0) and r.can_activate_power(0, 1) and r.can_activate_power(0, 2), "A full charge unlocks the power")
	check(not r.can_activate_power(0, 3) and not r.can_activate_power(0, -1) and not r.can_activate_power(5, 0), "Unknown powers and teams are refused")
	r.players[0].stun = 0.4
	check(not r.can_activate_power(0, 0), "A stunned pilot cannot use a power")
	r.players[0].stun = 0
	r.phase = "countdown"
	check(not r.can_activate_power(0, 0), "Powers stay locked outside play")
	r.phase = "play"
	check(r.activate_power(0, 1) and not r.can_activate_power(0, 0), "A running burst blocks the other powers")
	check(r.powers[0].charge == [5, 0, 12], "Using a power spends only its own charge")

	# Area blast: the direct hit plus every enemy brick inside the radius.
	r = playing()
	var seed_brick: int = first_brick(r, 1)
	var centre: Vector2 = r.bricks[seed_brick].p
	var before_enemy = team_health(r, 1)
	var before_own = team_health(r, 0)
	r.explode({"owner": 0, "p": centre, "power": 1})
	var hurt = 0
	var outside = 0
	for brick in r.bricks:
		if brick.team == 1 and brick.hp < Rules.BRICK_LIVES:
			hurt += 1
			if brick.p.distance_to(centre) > Rules.EXPLOSION_RADIUS:
				outside += 1
	check(hurt >= 2 and outside == 0, "The blast damages several enemy bricks, none beyond its radius (%d bricks)" % hurt)
	check(team_health(r, 1) == before_enemy - hurt * Rules.EXPLOSION_DAMAGE and team_health(r, 0) == before_own, "Each brick in the blast loses 2 lives and allied bricks are untouched")
	check(r.events.any(func(e): return e.kind == "explosion" and is_equal_approx(e.radius, Rules.EXPLOSION_RADIUS)), "The blast reports its radius for the effect")
	r = playing()
	var near_goal = Rules.track_position(1, 0.0)
	r.explode({"owner": 0, "p": near_goal, "power": 1})
	check(r.players[1].hp == Rules.PLAYER_LIVES - Rules.EXPLOSION_DAMAGE and r.players[0].hp == Rules.PLAYER_LIVES, "A blast on the rival costs two lives and never hurts the shooter")

	# A real explosive shot fired from the arc, through the normal collision code.
	r = playing()
	var angle = angle_hitting_brick(r)
	check(angle < INF, "Some arc position lines up an enemy brick")
	r.players[0].angle = angle
	r.players[0].p = Rules.track_position(0, angle)
	r.powers[0].charge[0] = cost(r, 0)
	before_enemy = team_health(r, 1)
	r.step(1.0 / 60, [{"move": Vector2.ZERO, "fire": false, "power": 0}, idle])
	check(r.balls.size() == 1 and r.balls[0].power == 1, "Power 1 fires a single explosive round")
	var blasted = false
	for tick in range(240):
		r.step(1.0 / 60, [idle, idle])
		if r.events.any(func(e): return e.kind == "explosion"):
			blasted = true
			break
	check(blasted, "The explosive round detonates when it lands")
	check(before_enemy - team_health(r, 1) >= 3, "One explosive round takes more health than a plain shot (%d lives)" % (before_enemy - team_health(r, 1)))

	# Machine gun: one long stream of rounds, fired on its own.
	r = playing()
	r.powers[0].charge[1] = cost(r, 1)
	var shots = 0
	var volley_balls = 0
	var burst_end = 0.0
	for tick in range(roundi((Rules.RAPID_SECONDS + 0.6) * 60)):
		r.step(1.0 / 60, [{"move": Vector2.ZERO, "fire": false, "power": 1 if tick == 0 else -1}, idle])
		var fired = r.events.filter(func(e): return e.kind == "shot" and e.team == 0).size()
		if fired > 0 and shots == 0:
			volley_balls = r.balls.size()
		shots += fired
		if r.powers[0].rapid_time > 0:
			burst_end = (tick + 1) / 60.0
	# The cadence is whole physics frames: one round every ceil(interval * 60) frames.
	var expected = roundi(Rules.RAPID_SECONDS / (ceilf(Rules.RAPID_INTERVAL * 60.0) / 60.0))
	check(shots == expected and expected == Rules.RAPID_ROUNDS, "The burst fires %d rounds without holding the trigger (%d)" % [expected, shots])
	check(volley_balls == 1, "They leave one behind the other, never side by side (%d at once)" % volley_balls)
	check(absf(burst_end - Rules.RAPID_SECONDS) < 0.05 and r.powers[0].rapid_time == 0, "The burst lasts %.1f s and then stops" % Rules.RAPID_SECONDS)
	check(r.events.filter(func(e): return e.kind == "shot" and e.team == 0).is_empty(), "No round is fired after the burst ends")

	# Air burst: a fan of pellets in slightly random directions.
	r = playing()
	r.powers[0].charge[2] = cost(r, 2)
	r.step(1.0 / 60, [{"move": Vector2.ZERO, "fire": false, "power": 2}, idle])
	check(r.balls.size() == Rules.AIR_PELLETS and Rules.AIR_PELLETS == 5, "The air burst throws %d pellets at once" % Rules.AIR_PELLETS)
	check(r.balls.all(func(b): return b.damage == Rules.AIR_DAMAGE and Rules.AIR_DAMAGE == 2, ), "Each pellet carries 2 of damage")
	var heading = Rules.forward_direction(0, r.players[0].angle).angle()
	var offsets: Array = []
	for ball in r.balls:
		check(ball.power == 3 and ball.owner == 0, "Every pellet belongs to the shooter")
		offsets.append(angle_difference(heading, ball.v.angle()))
	var widest = 0.0
	for offset in offsets:
		widest = maxf(widest, absf(offset))
	check(widest <= Rules.AIR_SPREAD + 0.06 and widest > Rules.AIR_SPREAD * 0.8, "The pellets stay inside the fan in front of the pilot")
	check(offsets.min() < -0.2 and offsets.max() > 0.2, "The fan opens to both sides")
	check(offsets.all(func(a): return offsets.count(a) == 1), "No two pellets take exactly the same direction")
	var again = playing()
	again.powers[0].charge[2] = cost(again, 2)
	again.step(1.0 / 60, [{"move": Vector2.ZERO, "fire": false, "power": 2}, idle])
	var repeat: Array = again.balls.map(func(b): return b.v.angle())
	check(repeat != r.balls.map(func(b): return b.v.angle()), "Two air bursts never spread exactly alike")

	# The boss: same powers, same costs, its own pace.
	r = playing()
	var boss_used: Array = []
	for tick in range(roundi(45 * 60)):
		r.step(1.0 / 60, [idle, r.ai_command()])
		for event in r.events:
			if event.kind == "power" and event.team == 1:
				boss_used.append(event.power)
		if r.phase == "finished":
			break
	check(r.powers[1].destroyed >= cost(r, 0), "The boss earns charge by destroying your bricks (%d bricks)" % r.powers[1].destroyed)
	check(boss_used.size() > 0, "The boss spends the powers it earned in a real match (%d uses)" % boss_used.size())
	var quiet = count_boss_powers(0, 30).size()
	var relentless = count_boss_powers(2, 30).size()
	check(quiet < relentless, "Fácil holds its powers back and Difícil keeps them coming (%d / %d in 30 s)" % [quiet, relentless])
	check(quiet > 0 and relentless <= 30.0 / Rules.AI_LEVELS[2].power_gap + 1, "Even Fácil uses them, and Difícil never spams them")
	var first_boss: Dictionary = Campaign.ai_profile(0, 1)
	var last_boss: Dictionary = Campaign.ai_profile(Campaign.LEVELS.size() - 1, 1)
	check(first_boss.power_gap > last_boss.power_gap and last_boss.power_gap >= 3.0, "Campaign bosses use powers more often level after level")
	check(Campaign.ai_profile(0, 0).power_gap > first_boss.power_gap and Campaign.ai_profile(0, 2).power_gap < first_boss.power_gap, "The chosen difficulty shifts that pace as well")
	r = playing()
	r.ai_level = 2
	var unaffordable = 0
	for tick in range(600):
		var held: Array = r.powers[1].charge.duplicate()
		var command: Dictionary = r.ai_command()
		var wanted: int = command.get("power", -1)
		if wanted >= 0 and held[wanted] < r.power_charge_cost(1, wanted):
			unaffordable += 1
		r.step(1.0 / 60, [idle, command])
	check(unaffordable == 0, "The boss never asks for a power it has not earned")

	# Goals and new matches.
	r = playing()
	r.powers[0].charge = [4, 9, 11]
	r.powers[0].rapid_time = 2.0
	r.reset_round()
	check(r.powers[0].charge == [4, 9, 11] and r.powers[0].rapid_time == 0, "Charges survive a goal, a running burst does not")
	r.reset_match()
	check(r.powers[0].charge == [0, 0, 0] and r.powers[0].destroyed == 0, "A new match starts from zero again")

	# Network: the client sees the same charges, bursts and explosive rounds.
	var host = playing()
	host.powers[0].charge = [3, 7, 12]
	host.powers[0].destroyed = 25
	host.powers[1].rapid_time = 0.75
	host.balls = [{"id": 5, "owner": 0, "p": Vector2(0.4, 0.2), "v": Vector2(0, 12), "bounces": 0, "boosted": false, "damage": 1, "ttl": 3.0, "power": 1}]
	var client = playing()
	check(client.apply_network_snapshot(host.network_snapshot()), "The power state travels in the match packet")
	check(client.powers[0].charge == [3, 7, 12] and client.powers[0].destroyed == 25 and is_equal_approx(client.powers[1].rapid_time, 0.75), "Charges, totals and the burst timer arrive intact")
	check(client.balls.size() == 1 and client.balls[0].power == 1, "The client knows which round is explosive")
	var packet: Dictionary = host.network_snapshot()
	var tampered: PackedFloat32Array = packet.b
	tampered[Rules.BALL_FIELDS - 1] = 9.0
	packet["b"] = tampered
	check(not client.apply_network_snapshot(packet), "An unknown power type is rejected")
	var state: Dictionary = host.snapshot().duplicate(true)
	var mirror = playing()
	mirror.apply_snapshot(host.snapshot().duplicate(true))
	check(mirror.powers[0].charge == [3, 7, 12] and host.snapshot().powers == state.powers, "The local snapshot carries the powers without sharing them")

	# HUD buttons and the match loop that reads them.
	root.size = Vector2i(720, 1600)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	# The match loop is driven by hand here, one tick at a time.
	game.set_process(false)
	game.set_physics_process(false)
	game.pause_ai = true
	await settle()
	var hud = game.hud
	game.start_pve()
	await settle()
	check(hud.power_centers.size() == Rules.POWER_SLOTS and game.rules.loadouts[0] == game.power_shop.kit + [String(game.Skins.CATALOG[game.skins.selected].ultimate)], "The match carries the saved kit plus the ultimate of the equipped skin")
	var screen = Rect2(Vector2.ZERO, hud.size)
	for orientation in [Vector2i(720, 1600), Vector2i(1280, 720)]:
		root.size = orientation
		await settle()
		screen = Rect2(Vector2.ZERO, hud.size)
		var tag = "%dx%d: " % [orientation.x, orientation.y]
		var fps_rect: Rect2 = hud.fps_label.get_rect()
		var stun_rect = Rect2(hud.size.x * 0.5 - 130, hud.size.y - 77, 260, 36)
		var stadium: Rect2 = drawn_arena(game)
		for index in range(3):
			var spot: Vector2 = hud.power_centers[index]
			var button = Rect2(spot - Vector2.ONE * hud.POWER_RADIUS, Vector2.ONE * hud.POWER_RADIUS * 2)
			check(screen.encloses(button), tag + "Power %d stays on screen" % index)
			check(spot.distance_to(hud.move_home) > hud.STICK_RADIUS + hud.POWER_RADIUS, tag + "Power %d never covers the movement stick" % index)
			check(not button.intersects(fps_rect) and not button.intersects(stun_rect), tag + "Power %d leaves the FPS and stun lines clear" % index)
			check(not button.intersects(hud.card_rects[0]) and not button.intersects(hud.card_rects[1]), tag + "Power %d stays clear of the player cards" % index)
			check(not button.intersects(stadium), tag + "Power %d never covers the stadium" % index)
		# A row across the bottom on a phone, a row under your own card on a wide screen.
		check(hud.power_centers[0].x < hud.power_centers[1].x and hud.power_centers[1].x < hud.power_centers[2].x, tag + "The three buttons keep their order")

	root.size = Vector2i(720, 1600)
	await settle()
	var touch = InputEventScreenTouch.new()
	touch.index = 7
	touch.pressed = true
	touch.position = hud.power_centers[2]
	hud._input(touch)
	check(hud.power_request == 2 and hud.move_id == -1, "Tapping a power button asks for that power instead of grabbing the stick")
	check(hud.power_at(hud.power_centers[0]) == 0 and hud.power_at(hud.move_home) == -1, "Only the buttons themselves answer to a tap")
	check(game.local_command().power == 2 and game.local_command().power == -1, "The match loop reads the request once")
	hud.request_power(1)
	hud.reset_touch()
	check(hud.power_request == -1, "Leaving the match forgets a pending power")
	var key = InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	game._unhandled_key_input(key)
	check(hud.power_request == 1, "On a PC the number keys ask for a power")
	hud.take_power()

	game.rules.phase = "play"
	# Slot 2 of the starter kit is the air burst; slot 3 waits for the skin ultimates.
	game.rules.powers[0].charge[1] = game.rules.power_charge_cost(0, 1)
	hud.request_power(1)
	game._physics_process(1.0 / 60)
	check(game.rules.powers[0].charge[1] == 0 and game.rules.balls.size() == Rules.AIR_PELLETS, "A button press fires the power in the match")
	check(Rules.power_label("") == "ULTIMATE" and Rules.power_label("sun_ray") == "SOL", "An empty third slot reads ULTIMATE; a skin with one names it")
	check(game.audio_voices.any(func(v): return v.playing and v.stream == game.tones.power), "Using a power has its own sound")
	for voice in game.audio_voices:
		voice.stop()
	check(game.tones.has("blast") and game.tones.has("ready") and game.tones.blast != game.tones.power and game.tones.ready != game.tones.power, "The blast and the ready chime are separate sounds")

	hud.update_match(game.rules, "")
	check(hud.match_data.has("powers") and hud.match_data.powers[0].charge[1] == 0 and hud.match_loadout(0, 1) == "air", "The HUD reads the charges and the kit from the match")
	game.arena.explosion(Vector2(0.2, 0.4), Rules.EXPLOSION_RADIUS)
	check(game.arena.effects.any(func(e): return e.get("grow", false)), "The blast draws an expanding ring")
	game.arena.update_state(game.rules, 0, 1.0 / 60)
	var pellet = game.arena.projectiles[game.rules.balls[0].id]
	check(pellet.get_node("Core").scale.x < 0.26 and pellet.get_node("Aura").scale.x < 0.39, "Air pellets are drawn smaller than a normal shot")
	game.return_to_menu()
	print("POWERS_RESULT failures=", failures)
	quit(failures)
