extends SceneTree
# Requires this repository's Git history: compares simulation with the pre-optimisation build (including the 2.9.4 wall fixes).
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output: Array = []
	if OS.execute("git", ["show", "3bd4bb1:scripts/arena_rules.gd"], output) != 0:
		push_error("Pre-optimisation revision unavailable")
		quit(1)
		return
	var reference = GDScript.new()
	reference.source_code = output[0]
	if reference.reload() != OK:
		quit(1)
		return
	var before = reference.new()
	var after = preload("res://scripts/arena_rules.gd").new()
	before.phase = "play"
	after.phase = "play"
	for tick in range(1200):
		var commands = [{"move": Vector2(sin(tick * 0.013), 0), "fire": true}, {"move": Vector2(cos(tick * 0.017), 0), "fire": tick % 3 == 0}]
		seed(tick)
		before.step(1.0 / 60.0, commands)
		seed(tick)
		after.step(1.0 / 60.0, commands)
		if before.snapshot() != after.snapshot():
			push_error("Simulation diverged at tick %d" % tick)
			quit(1)
			return
	print("FEEDBACK_PARITY_PASS: 1200 ticks identical to 2.9.4 physics")
	quit()
