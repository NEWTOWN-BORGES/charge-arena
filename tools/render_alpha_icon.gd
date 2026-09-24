extends SceneTree
var foreground = false
var painter: Node2D
var portraits = preload("res://scripts/game_hud.gd").new()
func _initialize() -> void: call_deferred("run")
func draw_icon() -> void:
	if not foreground:
		painter.draw_rect(Rect2(0, 0, 512, 512), Color("101d29"))
		painter.draw_circle(Vector2(256, 236), 202, Color("1b2d39"), true, -1, true)
	painter.draw_set_transform(Vector2(256, 236), 0, Vector2.ONE * 3.7)
	portraits.archon_portrait(painter, Vector2.ZERO, preload("res://scripts/skins.gd").colors(10, Color.WHITE), false)
	painter.draw_set_transform(Vector2.ZERO)
	var badge = StyleBoxFlat.new()
	badge.bg_color = Color("d2ad73")
	badge.set_corner_radius_all(12)
	painter.draw_style_box(badge, Rect2(206, 391, 100, 36))
	var font = ThemeDB.fallback_font
	painter.draw_string(font, Vector2(223, 417), "ALFA", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("101d29"))
func run() -> void:
	root.size = Vector2i(512, 512)
	root.transparent_bg = true
	root.content_scale_size = Vector2i.ZERO
	painter = Node2D.new()
	root.add_child(painter)
	painter.draw.connect(draw_icon)
	for name in ["icon", "foreground"]:
		foreground = name == "foreground"
		painter.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var error = root.get_texture().get_image().save_png("res://art/archon_alpha_%s.png" % name)
		if error != OK:
			quit(error)
			return
	portraits.free()
	quit()
