extends SceneTree
const Rules = preload("res://scripts/arena_rules.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Music = preload("res://scripts/music_player.gd")
var failures = 0
func check(ok, message):
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ", message)
func _initialize(): call_deferred("run")
func run():
	var homes_ok = true
	var flight_ok = true
	for level in Campaign.LEVELS:
		var r = Rules.new()
		r.set_map(level.map)
		var homes = r.bricks.map(func(b): return b.p)
		for brick in r.bricks:
			homes_ok = homes_ok and brick.home == brick.p and Rules.point_inside(r.walls, brick.p)
		for tick in range(21):
			r.powers[0].plunder_time = Rules.PLUNDER_SWAP * (1.0 - tick / 21.0)
			r.carry_bricks()
			for brick in r.bricks:
				flight_ok = flight_ok and Rules.point_inside(r.walls, brick.p)
		r.powers[0].plunder_time = 0.0
		r.carry_bricks()
		homes_ok = homes_ok and r.bricks.map(func(b): return b.p) == homes
	check(homes_ok, "Corsair returns to final map coordinates on every arena")
	check(flight_ok, "Corsair flight remains inside every arena")
	var r = Rules.new()
	r.bricks.clear()
	r.obstacles.clear()
	r.barriers.clear()
	r.boost_centers.clear()
	var ball = {"id":999, "owner":0, "p":Vector2(2, Rules.HALF_LENGTH - 1), "v":Vector2(0, 100), "bounces":0, "boosted":false, "damage":1, "ttl":3.0, "ghost":true}
	r.advance_ball(ball, 0.02)
	check(ball.v.y < 0 and ball.p.y <= Rules.HALF_LENGTH - Rules.PERIMETER_RADIUS - Rules.BALL_RADIUS, "Fast ghost projectile bounces on inner rear wall")
	var laser_ok = true
	for level in Campaign.LEVELS:
		r.set_map(level.map)
		for angle in [-0.8, 0.0, 0.8]:
			for point in r.laser_path(Vector2.ZERO, Vector2.UP.rotated(angle)):
				laser_ok = laser_ok and Rules.point_inside(r.walls, point)
	check(laser_ok, "Every reflected laser endpoint stays inside walls")
	var visible = Campaign.menu_levels()
	check(visible.size() == 11 and visible.all(func(i): return not Campaign.is_minor(i)), "Only Aurora and ten bosses in menu")
	var campaign = Campaign.new()
	campaign.unlock_all = false
	campaign.unlocked = 1
	for index in visible:
		check(campaign.is_unlocked(index), "Boss route unlocks without hidden outposts: %d" % index)
		campaign.complete(index)
	var bot_hashes = []
	for i in range(1,11):
		var hash = FileAccess.get_sha256("res://audio/bots/music_bot_%d.ogg" % i)
		check(hash != "" and not hash in bot_hashes and Music.TRACKS["bot_%d" % i] != Music.TRACKS["skin_%d" % i], "Bot music %d is separate" % i)
		bot_hashes.append(hash)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.show_game("pve", 0)
	game.rules.phase = "play"
	game.hud.update_match(game.rules, "")
	game.rules.bricks[0].hp -= 1
	game.hud.update_match(game.rules, "")
	check(game.hud.wall_delta[0] == -1, "Wall health records damage")
	game.hud._process(0.1)
	check(game.hud.wall_display[0] > game.hud.wall_health[0] and game.hud.wall_trail[0] > game.hud.wall_display[0], "Damage animates with a delayed trail")
	game.rules.bricks[0].hp += 2
	game.hud.update_match(game.rules, "")
	check(game.hud.wall_delta[0] == 2 and game.hud.wall_health[0] == game.rules.team_health(0), "Wall health records healing including buffs")
	var before_heal = game.hud.wall_display[0]
	game.hud._process(0.1)
	check(game.hud.wall_display[0] > before_heal and game.hud.wall_display[0] < game.hud.wall_health[0], "Healing fills the bar smoothly")
	game.hud.wall_delta_time[0] = 0.0
	var health_before = game.rules.team_health(0)
	game.rules.damage_brick(1, 99, 1, game.rules.bricks[1].p)
	game.hud.update_match(game.rules, "")
	check(game.hud.wall_delta[0] == -3 and game.hud.wall_health[0] == health_before - 3, "Destroying a three-life brick removes three, never the attack overkill")
	game.hud.wall_delta_time[0] = 0.0
	game.rules.bricks[2].hp = 1
	game.hud.update_match(game.rules, "")
	game.hud.wall_delta_time[0] = 0.0
	game.rules.damage_brick(2, 99, 1, game.rules.bricks[2].p)
	game.hud.update_match(game.rules, "")
	check(game.hud.wall_delta[0] == -1, "Finishing a damaged brick removes only its remaining life")
	game.queue_free()
	await process_frame
	quit(failures)
