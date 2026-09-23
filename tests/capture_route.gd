extends SceneTree
func _initialize() -> void: call_deferred("run")
func snap(name_value: String) -> void:
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-route-" + name_value + ".png")
func run() -> void:
	root.size = Vector2i(540, 960)
	var screen = preload("res://scripts/cup_screen.gd").new()
	screen.cup = preload("res://scripts/cup.gd").new()
	root.add_child(screen)
	screen.refresh()
	await snap("start")
	for i in range(7): screen.cup.complete([2, 1])
	screen.refresh()
	await snap("seven")
	screen.scroll.scroll_vertical = 500
	await snap("history")
	for i in range(3): screen.cup.complete([2, 0])
	screen.refresh()
	await snap("confirmed")
	screen.cup.rounds.pop_back()
	screen.refresh()
	await snap("waiting")
	root.size = Vector2i(1280, 720)
	await snap("landscape")
	quit()
