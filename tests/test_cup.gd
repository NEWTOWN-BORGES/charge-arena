extends SceneTree
const Cup = preload("res://scripts/cup.gd")
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS ", message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var c = Cup.new()
	c.complete([2, 0]) # Fixture starts after admission.
	c.path = "res://tests/cup-test.tmp"
	check(c.entrants.size() == 1024, "Full regional field")
	var names = c.entrants.map(func(p): return p.name)
	var unique = {}
	for n in names:
		unique[n] = true
	check(unique.size() == 1024, "Unique participant identities")
	var last_gap = 100.0
	for step in range(Cup.STAGE_MATCHES):
		check(c.profile(1).fire_gap <= last_gap, "Difficulty rises %d" % step)
		last_gap = c.profile(1).fire_gap
		check(c.level().map.has("outline"), "Playable arena %d" % step)
		check(c.complete([2, step % 2]), "Win advances once")
		if step < Cup.QUALIFIERS:
			var round_data = c.rounds.back()
			check(round_data.winners.size() == 1024 >> ((step + 1) * 2), "Bracket halves")
			check(round_data.fixtures.size() == round_data.winners.size(), "Every advancement has a result")
	check(c.rounds.back().winners[0].name == "Faroleiro", "Boss earned the regional final")
	check(c.confirmed_match().round == 7, "Sector victory opens the next stage")
	check(c.headlines.any(func(h): return "Vértice elimina Lira" in h.title), "Upset is backed by a fixture")
	check(c.save() == OK, "Save succeeds")
	var restored = Cup.new()
	restored.path = c.path
	restored.restore()
	check(restored.history == c.history and restored.rounds == c.rounds and restored.headlines == c.headlines, "Restoring preserves all results and news")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(c.path))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.cup = Cup.new()

	game.cup.path = "res://tests/cup-test.tmp"
	game.cup_screen.cup = game.cup
	game.start_cup()
	check(game.cup_active and game.rules.players.size() == 2, "Cup starts a real match")
	game.rules.players[0].hp = 3
	game.pause_pve()
	game.resume_pve()
	check(game.rules.players[0].hp == 3, "Pause resumes exact state")
	game.rules.winner = 1
	game.finish_cup()
	check(game.cup.wins == 0 and game.cup.rounds.is_empty(), "Loss does not simulate or advance")
	game.start_cup()
	game.rules.winner = 0
	game.rules.scores = [2, 1]
	game.finish_cup()
	check(game.cup.entrance_passed and game.cup.wins == 0 and game.cup_screen.visible, "Admission win opens the tournament without consuming a qualifier")
	game.start_cup()
	game.rules.winner = 0
	game.rules.scores = [2, 0]
	game.finish_cup()
	check(game.cup.wins == 1 and game.cup_screen.visible, "First qualifier advances after admission")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.cup.path))
	game.queue_free()
	await process_frame
	print("CUP FAILURES: ", failures)
	quit(1 if failures else 0)
