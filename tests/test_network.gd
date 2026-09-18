extends SceneTree
var game
var role = ""
var ticks = 0
var observed_remote_fire = false
var observed_boost = false
var observed_extra_ricochet = false
var fixture_started = false

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
			if role == "host" and ticks > 170 and not fixture_started:
				fixture_started = true
				# Authoritative damage fixture plus a real collision with the right booster.
				game.rules.bricks[0].hp = 2
				game.rules.bricks[1].hp = 1
				game.rules.balls.append({"id": game.rules.next_id, "owner": 0, "p": Vector2(game.Rules.HALF_WIDTH - 1, 0), "v": Vector2(game.Rules.BALL_SPEED, 0), "bounces": 0, "ttl": 4.0, "boosted": false, "damage": 1})
				game.rules.next_id += 1
				# A real bumper contact grants an extra budget, then travels to the client.
				var bumper: Vector2 = game.rules.obstacles[1].p
				var extra = {"id": game.rules.next_id, "owner": 0, "p": bumper + Vector2(0, 1.15), "v": Vector2.UP * game.Rules.BALL_SPEED, "bounces": 0, "ricochets_left": 1, "ttl": 4.0, "boosted": false, "damage": 1}
				game.rules.next_id += 1
				game.rules.balls.append(extra)
				game.rules.advance_ball(extra, 0.05)
			if role == "client":
				game.hud.move_vector = Vector2.RIGHT if ticks % 150 < 75 else Vector2.LEFT
			for b in game.rules.balls:
				if b.owner == 1:
					observed_remote_fire = true
				if b.get("boosted", false) and b.damage == 2:
					observed_boost = true
				if b.get("ricochets_left", 0) >= 2:
					observed_extra_ricochet = true
			var synced_health = game.rules.bricks[0].hp == 2 and game.rules.bricks[1].hp == 1
			var synced_size = is_equal_approx(game.arena.brick_nodes[0].scale.x, 0.76) and is_equal_approx(game.arena.brick_nodes[1].scale.x, 0.52)
			var on_arc = is_equal_approx(game.rules.players[1].p.distance_to(game.Rules.goal_center(1)), game.Rules.TRACK_RADIUS)
			var fixed_aim = game.rules.players[1].aim.is_equal_approx(game.Rules.forward_direction(1, game.rules.players[1].angle))
			var synced_obstacles = game.rules.obstacles.size() == 2 and game.rules.obstacle_time > 0.5
			for o in game.rules.obstacles:
				synced_obstacles = synced_obstacles and o.p.is_equal_approx(game.Rules.obstacle_position(o.id, game.rules.obstacle_time))
			if ticks > 230 and game.packets_received > 60 and observed_remote_fire and observed_boost and observed_extra_ricochet and synced_health and synced_size and on_arc and fixed_aim and synced_obstacles:
				print("NETWORK_PASS role=", role, " packets=", game.packets_received, " remote_firing=true boosted_shot=true extra_ricochet=true brick_hp_and_size=true arc=true fixed_aim=true moving_obstacles=true")
				# Either process may start first; let the peer finish before disconnecting.
				await create_timer(3.0 if role == "host" else 1.0).timeout
				game.close_network()
				quit(0)
				return
	push_error("NETWORK_FAIL role=" + role + " packets=" + str(game.packets_received) + " fire=" + str(observed_remote_fire) + " boost=" + str(observed_boost) + " ricochet=" + str(observed_extra_ricochet))
	game.close_network()
	quit(1)
