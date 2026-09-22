extends SceneTree
const Data = preload("res://scripts/cup_tree_data.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cup = preload("res://scripts/cup.gd").new()
	assert(Data.profile(cup, "Faroleiro").wins == 0)
	for i in range(7): cup.complete([2, 1])
	var lira = Data.profile(cup, "Lira")
	assert(lira.state == "ELIMINATED" and lira.eliminated_by == "Vértice")
	assert(lira.wins == 6 and lira.history.size() == 7)
	var rival = Data.profile(cup, "Vértice")
	assert(rival.wins == 7 and rival.history.back().loser == "Lira")
	assert(Data.profile(cup, "Tu").wins == 7)
	assert(Data.profile(cup, "Nadir").confirmed_only)
	var screen = preload("res://scripts/cup_screen.gd").new()
	screen.cup = cup
	root.add_child(screen)
	screen.tab = 1
	screen.refresh()
	await process_frame
	var tree = screen.tree_view
	assert(tree.map.nodes.size() > 10)
	tree.locate_player()
	assert(tree.level == 1)
	var center = Vector2.ZERO
	for node in tree.map.nodes:
		if node.key == "Tu": center = node.rect.get_center() * tree.map.zoom + tree.map.pan
	assert(center.distance_to(tree.map.size * 0.5) < 1)
	tree.open_person("Lira")
	assert(is_instance_valid(tree.detail))
	tree.follow("Vértice")
	assert(tree.following == "Vértice")
	assert(tree.map.nodes.size() == rival.history.size() + 2)
	tree.show_level(2)
	assert(tree.level == 2)
	assert(Data.fixtures(cup, 0, 0).size() == 8)
	assert(Data.fixtures(cup, 0, 63).size() == 8)
	var pan_before = tree.map.pan
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100, 100)
	tree.map.input_map(press)
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(40, 25)
	tree.map.input_map(motion)
	press.pressed = false
	tree.map.input_map(press)
	assert(tree.map.pan == pan_before + Vector2(40, 25))
	var z = tree.map.zoom
	tree.map.scale_at(1.2, Vector2(100, 100))
	assert(tree.map.zoom > z)
	screen.tab = 2
	screen.refresh()
	var journal = screen.content.get_child(0)
	journal.tree_requested.emit("Vértice")
	await process_frame
	assert(screen.tab == 1 and is_instance_valid(screen.tree_view.detail))
	for i in range(3): cup.complete([2, 0])
	assert(Data.profile(cup, "Vértice").eliminated_by == "Faroleiro")
	assert(Data.profile(cup, "Faroleiro").wins == 10)
	cup.complete([2, 1])
	assert(Data.profile(cup, "Faroleiro").eliminated_by == "Tu")
	screen.free()
	print("PASS TREE: public states, upset, trajectories, locate, zoom, pages, journal deep link, final")
	quit()
