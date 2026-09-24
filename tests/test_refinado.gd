extends SceneTree
const Cup = preload("res://scripts/cup.gd")
const View = preload("res://scripts/indie_arena_view.gd")
const Video = preload("res://scripts/video_settings.gd")
const News = preload("res://scripts/cup_news.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(Video.AA_LEVELS[2] == Viewport.MSAA_8X)
	assert(Video.SCREEN_AA[2] == Viewport.SCREEN_SPACE_AA_DISABLED)
	var view = View.new()
	var dimensions = Vector3(0.7, 0.9, 0.4)
	var mesh = view.rounded_pilot_shape(dimensions, 0.07)
	assert(mesh == view.rounded_pilot_shape(dimensions, 0.07))
	var arrays = mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	assert(vertices.size() == 900 and normals.size() == vertices.size())
	for i in range(vertices.size()):
		assert(vertices[i].is_finite() and normals[i].is_normalized())
		assert(vertices[i].abs().x <= dimensions.x * 0.5 + 0.0001)
	for i in range(0, vertices.size(), 3):
		var outward = (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i])
		assert(outward.dot(normals[i]) > 0)
	view.free()
	var cup = Cup.new()
	cup.path = "user://refinado-admission-test.cfg"
	assert(cup.opponent() == "Aurora" and cup.level().boss == 0)
	assert(News.edition(cup, 0)[0].personagemPrincipal == "Aurora")
	assert(cup.complete([2, 1]) and cup.wins == 0 and cup.rounds.is_empty())
	assert(cup.opponent() == "Téo" and cup.entrance_score == [2, 1])
	assert(cup.save() == OK)
	var restored = Cup.new()
	restored.path = cup.path
	restored.restore()
	assert(restored.entrance_passed and restored.entrance_score == [2, 1] and restored.wins == 0)
	assert(restored.boss_order == Cup.STORY_BOSSES)
	# Legacy randomized story: preserve conquered bosses and their score history.
	cup.boss_order = [1, 5, 2, 8, 4, 9, 6, 3, 7, 10]
	cup.prepare_entrants()
	for i in range(14): assert(cup.complete([2, i % 2]))
	var previous_history = cup.history.duplicate(true)
	assert(cup.save() == OK)
	var legacy = ConfigFile.new()
	assert(legacy.load(cup.path) == OK)
	legacy.set_value("cup", "version", 3)
	assert(legacy.save(cup.path) == OK)
	restored.restore()
	assert(restored.wins == 14 and restored.history == previous_history)
	assert(restored.defeated_bosses() == [1, 5])
	assert(restored.boss_order == [1, 5, 4, 8, 6, 3, 2, 7, 9, 10])
	assert(FileAccess.file_exists(cup.path + ".before-story-order"))
	assert(restored.save() == OK)
	var again = Cup.new()
	again.path = cup.path
	again.restore()
	assert(again.history == restored.history and again.boss_order == restored.boss_order)
	for suffix in ["", ".before-story-order"]: DirAccess.remove_absolute(cup.path + suffix)
	print("PASS REFINADO: outward smooth geometry, caching, admission persistence, legacy victories and remaining boss order")
	quit()
