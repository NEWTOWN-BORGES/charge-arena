extends SceneTree
# Sheet of the ten campaign arenas with their bosses (needs a GPU; omit --headless).
const Rules = preload("res://scripts/arena_rules.gd")
const ArenaView = preload("res://scripts/indie_arena_view.gd")
const Campaign = preload("res://scripts/campaign.gd")
const TILE = Vector2i(480, 560)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = TILE
	var sheet = Image.create(TILE.x * 5, TILE.y * 2, false, Image.FORMAT_RGBA8)
	for index in range(Campaign.LEVELS.size()):
		var level: Dictionary = Campaign.LEVELS[index]
		var rules = Rules.new()
		rules.set_map(level.map)
		rules.phase = "play"
		var arena = ArenaView.new()
		root.add_child(arena)
		arena.build(level.map)
		arena.set_skin(1, level.boss)
		rules.obstacle_time = 1.3
		for obstacle in rules.obstacles:
			obstacle.p = rules.obstacle_at(obstacle.id, rules.obstacle_time)
		arena.update_state(rules, 0, 1.0 / 60)
		arena.frame_rect(Rect2(Vector2(8, 8), Vector2(TILE) - Vector2(16, 16)), Vector2(TILE))
		for i in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var image = root.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, TILE), Vector2i(index % 5 * TILE.x, index / 5 * TILE.y))
		arena.queue_free()
		await process_frame
	var error = sheet.save_png("res://preview-levels-sheet.png")
	print("LEVEL_SHEET result=", error)
	quit(error)
