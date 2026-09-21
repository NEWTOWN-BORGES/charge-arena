extends SceneTree
# Validates the new PvP Colosseum map: 8-wall chamfered rectangle outline,
# dual goals, 56 bricks per team (112 total), obstacles, and 3D arena assembly.
const Rules = preload("res://scripts/arena_rules.gd")
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var pvp = Rules.pvp_map()
	check(pvp.id == "colosseum" and pvp.outline == "colosseum" and pvp.bricks == "colosseum", "PvP map definition is complete")

	# 1. Outline geometry: 8 vertices, chamfered corners, clockwise winding
	var walls = Rules.outline_points("colosseum")
	check(walls.size() == 8, "Colosseum outline has 8 vertices (chamfered rectangle)")
	var l = Rules.HALF_LENGTH
	var w = Rules.HALF_WIDTH
	for p in walls:
		check(absf(p.x) <= w + 0.001 and absf(p.y) <= l + 0.001, "Vertex %s stays within half-dimensions" % str(p))

	# All edge normals point inward
	var all_inward = true
	for i in range(walls.size()):
		var a: Vector2 = walls[i]
		var b: Vector2 = walls[(i + 1) % walls.size()]
		var edge = b - a
		var inward_normal = Vector2(-edge.y, edge.x).normalized()
		var midpoint = (a + b) * 0.5
		var test_pt = midpoint + inward_normal * 0.1
		if not Rules.point_inside(walls, test_pt):
			all_inward = false
	check(all_inward, "Every edge normal points into the arena")

	# 2. Dual goals are inside the arena
	var goal_0 = Rules.goal_center(0)
	var goal_1 = Rules.goal_center(1)
	check(is_equal_approx(goal_0.x, 0.0) and is_equal_approx(goal_1.x, 0.0), "Goals are centered horizontally")
	check(Rules.point_inside(walls, goal_0 - Vector2(0, 0.2)), "Team 0 goal area is inside the arena")
	check(Rules.point_inside(walls, goal_1 + Vector2(0, 0.2)), "Team 1 goal area is inside the arena")

	# 3. Dense brick layout: 56 bricks per team, 112 total
	var bricks = Rules.make_bricks("colosseum")
	check(bricks.size() == 112, "Colosseum layout creates 112 bricks in total (56 per team)")
	var team_0 = bricks.filter(func(b): return b.team == 0)
	var team_1 = bricks.filter(func(b): return b.team == 1)
	check(team_0.size() == 56 and team_1.size() == 56, "Each team defends 56 bricks")
	var inside_arena = bricks.all(func(b): return Rules.point_inside(walls, b.p))
	check(inside_arena, "All 112 bricks lie strictly inside the arena walls")

	# 4. Simulation with the PvP map
	var r = Rules.new()
	r.set_map(pvp)
	r.phase = "play"
	check(r.obstacles.size() == 3, "Colosseum has 3 dynamic obstacles (2 slides + 1 central orbit)")
	check(r.brick_count(0) == 56 and r.brick_count(1) == 56, "Match begins with all 56 bricks alive on each side")

	# 5. Full 3D arena assembly with main scene in host (PvP) mode
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.close_network()
	scene.host_game()
	await process_frame
	await process_frame
	check(scene.mode == "host", "Main scene entered host mode")
	check(scene.rules.map.id == "colosseum", "Host mode active map is colosseum")
	check(scene.arena.walls.size() == 8, "3D Arena built with 8-wall colosseum outline")
	check(scene.rules.bricks.size() == 112, "Rules instantiated 112 bricks")
	check(scene.arena.brick_nodes.size() == 112, "3D Arena instantiated all 112 brick nodes")
	check(scene.hud.host_ai_button.visible, "Host waiting shows host_ai_button to play vs AI")

	# 6. Switch from host waiting to AI mode
	scene.hud.pvp_ai_requested.emit()
	await process_frame
	await process_frame
	check(scene.mode == "pve", "Switched from host to PvE mode")
	check(scene.rules.map.id == "colosseum", "PvE mode stays on colosseum map")
	check(scene.rules.bricks.size() == 112, "PvE colosseum has 112 bricks")
	check(not scene.hud.host_ai_button.visible, "host_ai_button hidden in PvE mode")

	# 7. Direct start_pvp_ai() test
	scene.return_to_menu()
	await process_frame
	check(scene.mode == "menu", "Returned to menu")
	scene.start_pvp_ai()
	await process_frame
	await process_frame
	check(scene.mode == "pve", "start_pvp_ai sets mode to pve")
	check(scene.rules.map.id == "colosseum", "start_pvp_ai sets colosseum map")
	check(scene.rules.bricks.size() == 112, "Colosseum has 112 bricks in PvE")
	scene.rules.phase = "play"
	for _i in range(10):
		var ai_cmd = scene.rules.ai_command()
		check(typeof(ai_cmd) == TYPE_DICTIONARY and ai_cmd.has("move"), "AI command generated valid move")
		scene.rules.step(0.016, [{"move": Vector2.ZERO, "fire": false, "power": -1}, ai_cmd])
	check(scene.rules.obstacles.size() == 3, "Obstacles updated without errors")

	scene.close_network()

	print("PVP_MAP_RESULT failures=", failures)
	quit(failures)
