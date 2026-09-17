extends SceneTree
const Rules = preload("res://scripts/arena_rules.gd")
var failures = 0

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func ball(r, owner: int, pos: Vector2, velocity: Vector2) -> Dictionary:
	var b = {"id": r.next_id, "owner": owner, "p": pos, "v": velocity, "bounces": 2, "ricochets_left": 3, "ttl": 4.0, "damage": 2, "boosted": true}
	r.next_id += 1
	r.balls.append(b)
	return b

func run() -> void:
	var r = Rules.new()
	r.phase = "play"
	check(Rules.PLAYER_LIVES == 5 and Rules.STUN_SECONDS == 0.5 and r.players[0].hp == 5, "Players use five lives and a half-second stun")
	check(Rules.MAP_SCALE >= 1.24 and Rules.HALF_WIDTH > 7.4 and Rules.HALF_LENGTH > 8.5 and Rules.BRICK_EXTENT == Vector2(0.27, 0.14), "Expanded arena preserves brick dimensions")
	for team in range(2):
		var p: Vector2 = r.players[team].p
		var own = ball(r, team, p - Vector2(0.8, 0), Vector2(10, 0))
		r.advance_ball(own, 0.16)
		check(r.players[team].stun == 0 and r.balls.has(own), "Reflected own shot passes through player %d" % team)
		r.balls.clear()
		for hit in range(5):
			var enemy = ball(r, 1 - team, p - Vector2(0.8, 0), Vector2(10, 0))
			r.advance_ball(enemy, 0.16)
		check(r.players[team].hp == 0 and is_equal_approx(r.players[team].stun, 0.5), "Five enemy hits stun player %d" % team)
		var empty = {"move": Vector2.ZERO, "fire": false}
		r.step(0.51, [empty, empty])
		check(r.players[team].stun == 0 and r.players[team].hp == 5, "Player recovers five lives after half a second")
	# Isolate one friendly brick so the wall behind it is the next collision.
	for brick in r.bricks:
		brick.alive = false
		brick.hp = 0
	var brick = r.bricks[0]
	brick.p = Vector2(Rules.HALF_WIDTH - 0.7, 2.5)
	brick.hp = 3
	brick.alive = true
	var shot = ball(r, 0, brick.p - Vector2(0.8, 0), Vector2(10, 0))
	r.advance_ball(shot, 0.2)
	check(brick.hp == 3 and r.balls.has(shot) and shot.v.x < 0 and shot.bounces == 3, "Friendly brick passes shot through to a real wall ricochet")
	var replica = Rules.new()
	r.players[0].hp = 2
	r.players[0].stun = 0.4
	check(replica.apply_network_snapshot(r.network_snapshot()) and replica.players[0].hp == 2 and is_equal_approx(replica.players[0].stun, 0.4), "PvP synchronizes player lives and stun")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_pve()
	game.rules.phase = "play"
	game.rules.bricks[0].hp = 1
	game.rules.scores = [1, 2]
	game.rules.shoot(0)
	game.request_menu()
	var before = game.rules.snapshot().duplicate(true)
	for tick in range(60):
		game._physics_process(1.0 / 60)
		game._process(1.0 / 60)
	check(game.pve_paused and game.hud.pause_overlay.visible and game.rules.snapshot() == before, "PAUSA freezes projectiles, score, stun, timer and obstacles")
	game.hud.resume_requested.emit()
	check(not game.pve_paused and game.rules.snapshot() == before, "Resume retains exact match without resetting")
	game._physics_process(1.0 / 60)
	check(game.rules.elapsed > before.elapsed and game.rules.scores == [1, 2], "Simulation continues after resume")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.pve_paused, "Backgrounding the mobile app pauses PvE")
	game.return_to_menu()
	check(game.mode == "menu" and not game.hud.pause_overlay.visible, "Explicit end exits pause to menu")
	game.free()
	print("REVISION03 failures=", failures)
	quit(1 if failures else 0)
