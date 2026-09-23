extends SceneTree
const Data = preload("res://scripts/cup_route_data.gd")
func _initialize() -> void: call_deferred("run")
func visible_text(node: Node) -> String:
	var result = node.text + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): result += visible_text(child)
	return result
func run() -> void:
	var cup = preload("res://scripts/cup.gd").new()
	var screen = preload("res://scripts/cup_screen.gd").new()
	screen.cup = cup
	root.add_child(screen)
	for n in range(cup.FULL_MATCHES + 1):
		screen.refresh()
		var route = Data.snapshot(cup)
		var words: String = visible_text(screen.content).to_upper()
		for forbidden in ["AUREL", "NADIR", "LIRA", "VÉRTICE"]: assert(not words.contains(forbidden))
		for future in range(n + 1, 10): assert(not words.contains(cup.NAMES[future].to_upper()))
		assert(not words.contains("FAROLEIRO") if n < 10 else words.contains("FAROLEIRO"))
		assert(route.history.size() == n)
		if n > 0: assert(route.history[0].round == n)
		if n < cup.FULL_MATCHES:
			assert(route.state == "CONFIRMED" and not screen.play.disabled)
			cup.complete([2, n % 2])
		else: assert(route.state == "COMPLETE" and screen.play.disabled)
	cup.reset()
	for i in range(10): cup.complete([2, 1])
	var complete_round: Dictionary = cup.rounds.pop_back()
	screen.refresh()
	assert(Data.snapshot(cup).state == "WAITING")
	assert(not visible_text(screen.content).to_upper().contains("FAROLEIRO"))
	assert(screen.play.disabled)
	cup.rounds.append(complete_round)
	screen.refresh()
	assert(Data.snapshot(cup).large_encounter)
	assert(not screen.play.disabled)
	screen.free()
	print("PASS ROUTE: no future names, no world news, reverse history, confirmed/waiting/final/complete states")
	quit()
