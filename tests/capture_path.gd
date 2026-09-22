extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://path-" + label + ".png")

func run() -> void:
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var screen = preload("res://scripts/cup_screen.gd").new()
	screen.cup = preload("res://scripts/cup.gd").new()
	root.add_child(screen)
	screen.refresh()
	await shot("opening")
	for i in range(7): screen.cup.complete([2, i % 2])
	screen.refresh()
	await shot("progress")
	screen.scroll.scroll_vertical = 380
	await shot("history")
	for i in range(3): screen.cup.complete([2, 1])
	screen.refresh()
	await shot("final")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	screen.refresh()
	await shot("wide")
	screen.cup.complete([2, 1])
	screen.refresh()
	await shot("complete")
	screen.free()
	quit()
