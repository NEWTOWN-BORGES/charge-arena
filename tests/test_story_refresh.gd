extends SceneTree
const Cup = preload("res://scripts/cup.gd")
const Rules = preload("res://scripts/arena_rules.gd")
const News = preload("res://scripts/cup_news.gd")
func geometry(node: Node) -> String:
	var signature = ""
	if node is Node3D: signature += str(node.transform)
	if node is MeshInstance3D: signature += str(node.mesh.get_aabb()) + node.mesh.get_class()
	for child in node.get_children(): signature += geometry(child)
	return signature
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cup = Cup.new()
	var designs = {}
	var maps = {}
	var scenes = {}
	for i in range(cup.FULL_MATCHES):
		assert(cup.confirmed_match().is_final == (i % 6 == 5))
		var entry = cup.level()
		var rule = Rules.new()
		rule.set_map(entry.map)
		if i % 6 < 5:
			assert(not designs.has(entry.boss))
			designs[entry.boss] = true
			var signature = str(entry.map.outline) + str(entry.map.bricks) + str(entry.map.obstacles) + str(entry.map.brick_variant)
			assert(not maps.has(signature))
			maps[signature] = true
			for brick in Rules.map_bricks(entry.map): assert(Rules.point_inside(Rules.map_outline(entry.map), brick.p))
		assert(cup.complete([2, i % 2]))
		var cover = News.edition(cup, cup.wins)[0]
		scenes[cover.cenario] = true
	assert(designs.size() == 50 and maps.size() == 50 and scenes.size() >= 7)
	assert(cup.history.size() == 60 and cup.defeated_bosses().size() == 10)
	assert(cup.rounds.size() == 100)
	var signatures = {}
	for id in designs:
		var models = preload("res://scripts/indie_arena_view.gd").new()
		var pilot = models.build_player(Color.WHITE, 0, id)
		var signature = geometry(pilot)
		assert(not signatures.has(signature))
		signatures[signature] = true
		models.free()
	assert(signatures.size() == 50)
	for old_count in [0, 1, 5, 10, 11, 55, 109, 110]:
		var saved = ConfigFile.new()
		var records: Array = []
		for n in range(old_count): records.append({"opponent": "Original %d" % n, "score": [2, n % 2], "round": n + 1})
		saved.set_value("cup", "version", 2)
		saved.set_value("cup", "seed", 2026)
		saved.set_value("cup", "wins", old_count)
		saved.set_value("cup", "history", records)
		var migrated = Cup.new()
		migrated.path = "user://migration-five-%d.cfg" % old_count
		saved.save(migrated.path)
		migrated.restore()
		assert(migrated.wins == mini(60, old_count / 11 * 6 + ceili((old_count % 11) / 2.0)))
		assert(migrated.legacy_history == records)
		assert(migrated.defeated_bosses().size() == old_count / 11)
		assert(FileAccess.file_exists(migrated.path + ".before-five-battles"))
		migrated.save()
		var restored = Cup.new()
		restored.path = migrated.path
		restored.restore()
		assert(restored.history == migrated.history)
		DirAccess.remove_absolute(migrated.path)
		DirAccess.remove_absolute(migrated.path + ".before-five-battles")
	for id in ["b_charge", "b_quick", "b_fan", "b_bar", "b_slow", "b_aim", "b_drill"]:
		var rule = Rules.new()
		rule.phase = "play"
		rule.loadouts[1] = ["blast", "air", id]
		rule.powers[1].charge[2] = rule.power_charge_cost(1, 2)
		assert(rule.activate_power(1, 2))
		assert(rule.powers[1].ultimate_windup > 0)
		rule.step_ultimate(1, Rules.ULTIMATE_WINDUP + 0.1)
		assert(rule.events.any(func(e): return e.kind == "ultimate" and e.id == id))
		if id == "b_charge": assert(rule.balls.size() == 1)
		if id == "b_fan": assert(rule.balls.size() == Rules.AIR_PELLETS + 2)
		if id == "b_quick": assert(rule.powers[1].rapid_time > Rules.RAPID_SECONDS)
	print("PASS STORY: 60 bouts, 50 designs/maps, journal variety, geometry, legacy progression and rewards")
	quit()

