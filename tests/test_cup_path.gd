extends SceneTree
const Cup = preload("res://scripts/cup.gd")
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func labels(node: Node) -> String:
	var value = node.text + "\n" if node is Label else ""
	for child in node.get_children():
		value += labels(child)
	return value

func run() -> void:
	var cup = Cup.new()
	cup.complete([2, 0]) # Fixture starts after admission.
	var screen = preload("res://scripts/cup_screen.gd").new()
	screen.cup = cup
	root.add_child(screen)
	for step in range(Cup.DEMO_MATCHES + 1):
		screen.refresh()
		var copy = labels(screen.content).to_upper()
		check("TU ESTÁS AQUI" in copy, "Protagonist remains the focus at %d" % step)
		check(not "NADIR" in copy and not "AUREL" in copy and not "VÉRTICE" in copy and not "LIRA" in copy, "Other storylines stay outside the path")
		for future in range(step + 1, Cup.NAMES.size()):
			check(not Cup.NAMES[future].to_upper() in copy, "No future qualifier at %d" % step)
		if step < Cup.QUALIFIERS:
			check(not "FAROLEIRO" in copy, "Sector winner is not predicted")
			check(cup.confirmed_match().name == Cup.NAMES[step], "Only the current scheduled qualifier is confirmed")
		elif step == Cup.QUALIFIERS:
			check("FAROLEIRO" in copy and "FINAL DO SETOR · CONFIRMADA" in copy, "Actual bracket winner becomes the opponent")
		elif step == Cup.FULL_MATCHES:
			check(screen.play.disabled and not "SE VENCER" in copy and not "PRÓXIMO CONFRONTO" in copy, "Completion has no invented future")
		var last_position = copy.find("TU ESTÁS AQUI")
		for i in range(cup.history.size() - 1, -1, -1):
			var name_at = copy.find(cup.history[i].opponent.to_upper(), last_position)
			check(name_at > last_position, "Victories are behind the protagonist, most recent first")
			last_position = name_at
			check("VITÓRIA %d–%d" % [cup.history[i].score[0], cup.history[i].score[1]] in copy, "Real saved score is displayed")
		if step < Cup.DEMO_MATCHES:
			cup.complete([2, step % 2])
	# A seeded narrative winner without a completed fixture must not be revealed.
	cup.reset()
	cup.complete([2, 0]) # Fixture starts after admission.
	for i in range(4): cup.complete([2, 1])
	cup.wins = 5
	screen.refresh()
	check(cup.confirmed_match().is_empty() and screen.play.disabled, "Pending bracket blocks play")
	check("ADVERSÁRIO A DEFINIR" in labels(screen.content) and not "FAROLEIRO" in labels(screen.content), "Pending bracket does not leak seeded winner")
	cup.wins = 4
	cup.complete([2, 1])
	var fixture = cup.rounds.back().fixtures[0]
	fixture.winner = "Not the recorded winner"
	check(cup.confirmed_match().is_empty(), "Winner must be backed by the final fixture")
	fixture.winner = "Faroleiro"
	cup.path = "user://path-test.cfg"
	check(cup.save() == OK, "Save path progress")
	var restored = Cup.new()
	restored.path = cup.path
	restored.restore()
	check(restored.history == cup.history and restored.confirmed_match() == cup.confirmed_match(), "Restoration preserves history and confirmed match")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cup.path))
	screen.cup = restored
	screen.result = "Derrota · 1–2 contra FAROLEIRO"
	screen.refresh()
	check(restored.wins == 5 and not screen.play.disabled, "Defeat allows retry without advancing")
	screen.free()
	await process_frame
	print("PATH FAILURES: ", failures)
	quit(failures)
