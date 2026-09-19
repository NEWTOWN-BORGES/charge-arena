extends SceneTree
var game
var role = ""
var ticks = 0
var observed_remote_fire = false
var observed_boost = false
var observed_held = false
var fixture_started = false
var last_state = {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	role = "host" if OS.get_cmdline_user_args().has("--host") else "client"
	if role == "host":
		game.host_game()
	else:
		game.join_game("127.0.0.1")
	while ticks < 600:
		await create_timer(0.02).timeout
		ticks += 1
		if game.connected:
			if role == "host" and ticks > 170:
				# Authoritative damage fixture, pinned every tick so the shots cannot undo it.
				game.rules.bricks[0].hp = 2
				game.rules.bricks[0].alive = true
				game.rules.bricks[1].hp = 1
				game.rules.bricks[1].alive = true
			if role == "host" and ticks > 170 and not fixture_started:
				fixture_started = true
				game.rules.balls.append({"id": game.rules.next_id, "owner": 0, "p": Vector2(game.Rules.HALF_WIDTH - 1, 0), "v": Vector2(game.Rules.BALL_SPEED, 0), "bounces": 0, "ttl": 4.0, "boosted": false, "damage": 1})
				game.rules.next_id += 1
				# A round caught inside a singularity: held on the host, held on the client.
				var caught = {"id": game.rules.next_id, "owner": 1, "p": Vector2(0, 1.15), "v": Vector2.UP * game.Rules.BALL_SPEED * 0.2, "bounces": 0, "ttl": 4.0, "boosted": false, "damage": 1, "held": true}
				game.rules.next_id += 1
				game.rules.balls.append(caught)
			if role == "client":
				game.hud.move_vector = Vector2.RIGHT if ticks % 150 < 75 else Vector2.LEFT
			for b in game.rules.balls:
				if b.owner == 1:
					observed_remote_fire = true
				if b.get("boosted", false) and b.damage == 2:
					observed_boost = true
				if b.get("held", false):
					observed_held = true
			var synced_health = game.rules.bricks[0].hp == 2 and game.rules.bricks[1].hp == 1
			var synced_size = is_equal_approx(game.arena.brick_nodes[0].scale.x, 0.76) and is_equal_approx(game.arena.brick_nodes[1].scale.x, 0.52)
			var on_arc = is_equal_approx(game.rules.players[1].p.distance_to(game.Rules.goal_center(1)), game.Rules.TRACK_RADIUS)
			var fixed_aim = game.rules.players[1].aim.is_equal_approx(game.Rules.forward_direction(1, game.rules.players[1].angle))
			# The colosseum carries three: two sliders and the orbiting one in the middle.
			var synced_obstacles = game.rules.obstacles.size() == game.rules.map.obstacles.size() and game.rules.obstacles.size() >= 2 and game.rules.obstacle_time > 0.5
			for i in range(game.rules.obstacles.size()):
				# The client rebuilds these from the shared clock, so they must land exactly
				# where the map's own spec puts them at that time.
				synced_obstacles = synced_obstacles and game.rules.obstacles[i].p.is_equal_approx(game.rules.obstacle_at(i, game.rules.obstacle_time))
			last_state = {"ticks": ticks, "packets": game.packets_received, "fire": observed_remote_fire,
				"boost": observed_boost, "held": observed_held, "health": synced_health, "size": synced_size,
				"arc": on_arc, "aim": fixed_aim, "obstacles": synced_obstacles}
			if ticks > 230 and game.packets_received > 60 and observed_remote_fire and observed_boost and observed_held and synced_health and synced_size and on_arc and fixed_aim and synced_obstacles:
				print("NETWORK_PASS role=", role, " packets=", game.packets_received, " remote_firing=true boosted_shot=true held_round=true brick_hp_and_size=true arc=true fixed_aim=true moving_obstacles=true")
				# Either process may start first; let the peer finish before disconnecting.
				await create_timer(3.0 if role == "host" else 1.0).timeout
				game.close_network()
				quit(0)
				return
	push_error("NETWORK_FAIL role=" + role + " " + str(last_state))
	game.close_network()
	quit(1)
