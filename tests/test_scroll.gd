extends SceneTree
## Drag scrolling in the menus: the gesture picks the list under the finger, honours the
## axis that list allows, never fires on a tap, leaves real sliders their own gesture and
## keeps throwing after the finger leaves. A closing panel drops the gesture with it.
var failures = 0
var checks = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func settle() -> void:
	for i in range(5): await process_frame

func press(gestures, at: Vector2, down: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = down
	gestures._input(event)

func drag(gestures, at: Vector2) -> void:
	var event = InputEventScreenDrag.new()
	event.index = 0
	event.position = at
	gestures._input(event)

func run() -> void:
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await settle()
	var hud = game.hud
	var gestures = hud.get_node_or_null("ScrollGestures")
	check(gestures != null, "The menus carry the shared scroll gesture")
	hud.open_skins()
	await settle()

	# A column taller than its window scrolls under the finger.
	var column: ScrollContainer = hud.skins_scroll
	check(column.get_v_scroll_bar().max_value > column.size.y, "The pilot details column has more than one screen of content")
	var middle: Vector2 = column.get_global_rect().get_center()
	press(gestures, middle, true)
	drag(gestures, middle - Vector2(0, 90))
	var travelled: int = column.scroll_vertical
	check(travelled > 0, "Dragging up scrolls the column down (%d px)" % travelled)
	check(gestures.dragging, "A drag past the deadzone takes over the gesture")

	# The throw carries on after the finger leaves, then settles.
	press(gestures, middle - Vector2(0, 90), false)
	gestures._process(0.05)
	var thrown: int = column.scroll_vertical
	check(thrown > travelled, "The list keeps moving after the finger leaves (%d px)" % (thrown - travelled))
	for i in range(60): gestures._process(0.05)
	check(gestures.velocity.length() < 10, "The throw comes to a stop instead of drifting")
	var rested: int = column.scroll_vertical

	# A tap is not a drag: a press and release inside the deadzone must not move the list.
	press(gestures, middle, true)
	drag(gestures, middle + Vector2(0, 4))
	press(gestures, middle + Vector2(0, 4), false)
	check(column.scroll_vertical == rested and not gestures.dragging, "A tap leaves the list where it was, so buttons still answer")

	# The strip of pilots scrolls sideways only; a vertical pull must not move it.
	var strip: ScrollContainer = hud.skin_strip
	check(strip.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and strip.get_h_scroll_bar().max_value > strip.size.x, "The pilot strip is a sideways list")
	var on_strip: Vector2 = strip.get_global_rect().get_center()
	press(gestures, on_strip, true)
	drag(gestures, on_strip - Vector2(120, 0))
	check(gestures.target == strip, "The gesture picks the list under the finger, not the one behind it")
	check(strip.scroll_horizontal > 0 and strip.scroll_vertical == 0, "The strip scrolls sideways and stays put vertically (%d px)" % strip.scroll_horizontal)
	press(gestures, on_strip - Vector2(120, 0), false)

	# A progress bar is a Range, but no finger ever drags one: shown, it must not punch a
	# dead band through the column. It only appears on a pilot you have not won yet.
	var bar: Control = hud.skin_progress
	bar.visible = true
	await settle()
	for attempt in range(24):
		if column.get_global_rect().has_point(bar.get_global_rect().get_center()): break
		column.scroll_vertical += 40
		await process_frame
	check(bar.is_visible_in_tree() and bar.size.x > 100 and column.get_global_rect().has_point(bar.get_global_rect().get_center()), "The progress bar is showing inside the scrolling window")
	check(gestures.find_scroll(bar.get_global_rect().get_center()) == column, "A drag starting on the progress bar still scrolls the column")
	# Closing the panel drops the gesture instead of leaving it aimed at a hidden list.
	press(gestures, middle, true)
	drag(gestures, middle - Vector2(0, 40))
	hud.close_skins()
	await settle()
	gestures._process(0.05)
	check(gestures.target == null and not gestures.dragging, "Closing a panel cancels the gesture it was holding")

	# A real slider keeps its own gesture: the list must not steal the drag.
	hud.open_video()
	await settle()
	var slider: Control = hud.music_volume
	var options: ScrollContainer = hud.options_scroll
	var on_slider: Vector2 = slider.get_global_rect().get_center()
	check(options.get_global_rect().has_point(on_slider), "The volume slider sits inside the options list")
	check(gestures.find_scroll(on_slider) == null, "A drag starting on the volume slider is left to the slider")
	var on_text: Vector2 = options.get_child(0).get_child(1).get_global_rect().get_center()
	check(gestures.find_scroll(on_text) == options, "Elsewhere in the panel the list still takes the drag")
	hud.close_video()
	print("SCROLL_RESULT ", checks - failures, "/", checks, " passed")
	quit(1 if failures > 0 else 0)
