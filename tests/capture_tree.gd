extends SceneTree
func _initialize() -> void: call_deferred("run")
func snap(name_value: String) -> void:
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-tree-" + name_value + ".png")
func run() -> void:
	root.size = Vector2i(540, 960)
	var screen = preload("res://scripts/cup_screen.gd").new()
	screen.cup = preload("res://scripts/cup.gd").new()
	for i in range(7): screen.cup.complete([2, 1])
	root.add_child(screen)
	screen.tab = 1
	screen.refresh()
	await snap("overview")
	screen.tree_view.locate_player()
	await snap("sector")
	screen.tree_view.open_person("Lira")
	await snap("eliminated")
	screen.tree_view.follow("Vértice")
	await snap("rival")
	screen.tree_view.show_level(2)
	screen.tree_view.round_index = 6
	screen.tree_view.show_level(2)
	await snap("matches")
	root.size = Vector2i(1280, 720)
	screen.tree_view.show_level(0)
	await snap("landscape")
	quit()
