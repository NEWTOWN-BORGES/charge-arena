extends SceneTree
var failures = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_pve()
	game.set_physics_process(false)
	game.rules.phase = "play"
	game.rules.bricks[0].hp = 2
	game.rules.bricks[1].hp = 1
	game.rules.bricks[2].hp = 0
	game.rules.bricks[2].alive = false
	game.arena.update_state(game.rules, 0, 1.0 / 60)
	check(game.arena.brick_nodes.size() == game.rules.bricks.size(), "All four banks have matching visual bricks (%d)" % game.arena.brick_nodes.size())
	check(is_equal_approx(game.arena.brick_nodes[0].scale.x, 0.76) and is_equal_approx(game.arena.brick_nodes[1].scale.x, 0.52), "Damaged brick models shrink to match the collision scale")
	check(not game.arena.brick_nodes[2].visible, "Destroyed brick model is hidden")
	check(not game.arena.brick_nodes[0].get_node("HP2").visible and not game.arena.brick_nodes[1].get_node("HP1").visible, "Visible health marks disappear with each lost life")
	game.rules.balls.append({"id": 999, "owner": 0, "p": Vector2.ZERO, "v": Vector2.RIGHT * 25.575, "boosted": true, "damage": 2, "bounces": 1, "ttl": 2.0})
	game.arena.update_state(game.rules, 0, 1.0 / 60)
	check(is_equal_approx(game.arena.projectiles[999].get_node("Aura").scale.x, 0.52), "Boosted projectile displays the larger golden aura")
	for brick in game.rules.bricks:
		if brick.team == 1:
			brick.hp = 0
			brick.alive = false
	game.arena.update_state(game.rules, 0, 1.0 / 60)
	var opening: float = game.arena.goals[1].material_override.get_shader_parameter("unlocked")
	for n in range(30):
		game.arena.update_state(game.rules, 0, 1.0 / 60)
	check(opening < 1.0 and is_equal_approx(game.arena.goals[1].material_override.get_shader_parameter("unlocked"), 1.0), "Removing both banks opens the goal shield, in a ramp rather than a switch")
	game.rules.reset_round()
	game.arena.update_state(game.rules, 0, 1.0 / 60)
	check(game.arena.brick_nodes.all(func(b): return b.visible and is_equal_approx(b.scale.x, 1.0)), "New round restores all brick models at full size")
	print("MAP_VIEW_RESULT failures=", failures)
	quit(failures)
