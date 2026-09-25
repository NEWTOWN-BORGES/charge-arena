extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var output = []
	if OS.execute("git", ["show", "3bd4bb1:scripts/indie_arena_view.gd"], output) != 0:
		quit(1)
		return
	var baseline = GDScript.new()
	baseline.source_code = output[0]
	if baseline.reload() != OK:
		quit(1)
		return
	for script in [baseline, load("res://scripts/indie_arena_view.gd")]:
		var arena = script.new()
		root.add_child(arena)
		arena.build()
		arena.set_quality(2)
		var before = arena.get_child_count()
		var start = Time.get_ticks_usec()
		for i in range(300):
			arena.emitter(Vector3.ZERO, Color.WHITE, 12, 0.3, 2, 30, 0.2)
			arena.flash(Vector3.ZERO, Color.WHITE, 2, 0.2)
		print("FX_BURST ", "baseline" if script == baseline else "optimized", " cpu_us=", Time.get_ticks_usec()-start, " new_nodes=", arena.get_child_count()-before, " effects=", arena.effects.size())
		arena.free()
	quit()
