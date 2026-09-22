extends SceneTree
func _initialize() -> void: call_deferred("run")
func snap(name_value: String) -> void:
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-journal-" + name_value + ".png")
func run() -> void:
	root.size = Vector2i(540, 960)
	var screen = preload("res://scripts/cup_screen.gd").new()
	screen.cup = preload("res://scripts/cup.gd").new()
	root.add_child(screen)
	screen.tab = 2
	screen.refresh()
	await snap("opening")
	for n in range(11): screen.cup.complete([2, 1])
	screen.refresh()
	await snap("final")
	var journal = screen.content.get_child(0)
	journal.edition_number = 4
	journal.front()
	await snap("interview")
	journal.article(preload("res://scripts/cup_news.gd").edition(screen.cup, 7)[0])
	await snap("article")
	root.size = Vector2i(1280, 720)
	await snap("landscape")
	quit()
