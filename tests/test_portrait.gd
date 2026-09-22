extends SceneTree
# Vertical phones: every HUD element keeps its place without overlapping the
# stadium, the camera frames the whole arena, and landscape stays as it was.
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in range(3):
		await process_frame

func drawn_arena(game) -> Rect2:
	# Project the measured stadium bounds through the real camera, offsets included.
	if game.arena.camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		# A leaning arena has no single camera plane to measure on: the far end really is
		# smaller, so the stadium is projected mark by mark instead.
		return game.arena.projected_bounds(game.hud.size)
	var cam: Camera3D = game.arena.camera
	var basis = cam.global_transform.basis
	var b: Rect2 = game.arena.view_bounds
	var result = Rect2()
	var first = true
	for corner in [b.position, b.end, Vector2(b.position.x, b.end.y), Vector2(b.end.x, b.position.y)]:
		var world = cam.global_position + basis.x * corner.x + basis.y * corner.y - basis.z * 20.0
		var pixel = cam.unproject_position(world)
		result = Rect2(pixel, Vector2.ZERO) if first else result.expand(pixel)
		first = false
	return result

func control_rects(hud) -> Array:
	# The stick disc with the captions under it, and each power key beside it.
	var stick = hud.STICK_RADIUS
	var rects = [Rect2(hud.move_home - Vector2(stick, stick), Vector2(stick * 2, stick + 124))]
	for spot in hud.power_centers:
		var span: float = hud.power_button_radius(hud.power_centers.find(spot))
		rects.append(Rect2(spot - Vector2.ONE * span, Vector2.ONE * span * 2))
	return rects

func touch(hud, id: int, position: Vector2, down: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.index = id
	event.position = position
	event.pressed = down
	hud._input(event)

func run() -> void:
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_PORTRAIT, "Android build is locked to portrait")
	root.size = Vector2i(720, 1600)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await settle()
	var hud = game.hud
	var screen = Rect2(Vector2.ZERO, hud.size)
	check(root.content_scale_size == Vector2i(720, 1280) and hud.size.is_equal_approx(Vector2(720, 1600)), "A tall screen switches the HUD to 720 units wide")
	check(hud.vertical, "HUD detects the vertical layout")

	var arena = drawn_arena(game)
	check(hud.arena_rect.grow(1).encloses(arena), "Menu: the whole stadium is framed above the menu")
	check(screen.encloses(hud.menu.get_rect()), "Menu: the panel fits on screen")
	check(arena.end.y + 50 <= hud.menu.position.y, "Menu: the slogan has room between the stadium and the panel")

	for size in [Vector2i(720, 1600), Vector2i(720, 1280)]:
		root.size = size
		game.start_pve()
		await settle()
		screen = Rect2(Vector2.ZERO, hud.size)
		arena = drawn_arena(game)
		var tag = "%dx%d: " % [size.x, size.y]
		var card_player: Rect2 = hud.card_rects[0]
		var card_rival: Rect2 = hud.card_rects[1]
		var controls = control_rects(hud)
		check(hud.back.get_rect().end.y <= hud.score_rect.position.y and hud.video_button.get_rect().end.y <= hud.score_rect.position.y, tag + "MENU and OPÇÕES buttons sit above the score")
		check(hud.score_rect.end.y <= arena.position.y, tag + "Score sits above the stadium")
		check(card_player.end.y <= arena.position.y and card_rival.end.y <= arena.position.y, tag + "Both player cards sit above the stadium without overlap")
		check(arena.end.y <= controls[0].position.y and arena.end.y <= controls[1].position.y, tag + "Stadium sits above the thumb controls")
		check(screen.encloses(controls[0]) and screen.encloses(controls[1]) and screen.encloses(card_player) and screen.encloses(card_rival), tag + "Cards and controls stay on screen")
		check(arena.size.x >= hud.size.x * 0.85, tag + "Stadium uses the full width (%d px)" % arena.size.x)
		check(arena.has_point(hud.message_center) and screen.encloses(hud.replay.get_rect()), tag + "Countdown, goal and replay messages centre on the stadium")
		var fps = hud.fps_label.get_rect()
		check(screen.encloses(fps) and controls.all(func(c): return not fps.intersects(c)), tag + "FPS counter keeps clear of the thumb controls")
		var stun: Rect2 = hud.stun_banner_rect()
		check(screen.encloses(stun) and controls.all(func(c): return not stun.intersects(c)), tag + "Stun banner sits over the controls, clear of them")

	check(hud.card_rects[0].position.x < hud.card_rects[1].position.x, "Host/PvE player card is on the left of the top band")
	hud.show_game("client", 1)
	await settle()
	check(hud.card_rects[0].position.x > hud.card_rects[1].position.x, "Client local card stays on the left of the top band")
	hud.show_game("pve", 0)
	await settle()

	touch(hud, 0, Vector2(120, hud.touch_top - 20), true)
	check(hud.move_id == -1, "Touches over the stadium do not grab the stick")
	touch(hud, 0, hud.move_home, true)
	check(hud.move_id == 0, "The thumb grabs the stick in the vertical layout")
	check(game.local_command().fire, "The pilot fires by itself in the vertical layout")
	touch(hud, 0, hud.move_home, false)
	check(hud.move_center == hud.move_home and hud.move_id == -1, "Releasing returns the stick to its resting place")

	hud.open_video()
	await settle()
	check(screen.encloses(hud.video_panel.get_rect()), "Graphics and sound panel fits the vertical screen")
	hud.close_video()

	root.size = Vector2i(1280, 720)
	await settle()
	check(root.content_scale_size == Vector2i(1280, 720) and not hud.vertical, "A wide window returns to the landscape layout")
	check(is_equal_approx(game.arena.camera.size, game.arena.LANDSCAPE_SIZE) and game.arena.camera.h_offset == 0 and is_equal_approx(game.arena.camera.v_offset, 0.52), "Landscape match camera uses the enlarged safe framing")
	check(hud.card_rects[0] == Rect2(38, 184, 200, 222) and hud.card_rects[1] == Rect2(1042, 184, 200, 222), "Landscape side cards keep their positions")
	check(hud.score_rect == Rect2(488, 19, 304, 59) and hud.touch_top == 302.4, "Landscape score and touch zone keep their positions")
	game.return_to_menu()
	await settle()
	check(game.arena.camera.h_offset == -4.5 and hud.menu.position.x == 48 and is_equal_approx(hud.menu.get_rect().end.y, 680), "Landscape menu sits bottom-left, within thumb reach, with the stadium to its right")
	print("PORTRAIT_RESULT failures=", failures)
	quit(failures)
