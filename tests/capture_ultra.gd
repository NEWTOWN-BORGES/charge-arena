extends SceneTree
# Before/after shots for the visual pass: the arena in play, a fight in full swing and the
# pilots up close. Needs a real window (not --headless). Output folder: --out=<dir>.
var out_dir = "res://previews/ultra/"

func _initialize(): call_deferred("run")

func capture(name: String) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	img.save_png(out_dir + name + ".png")
	return img

func settle(game, seconds: float) -> void:
	var steps = int(seconds * 60.0)
	for i in range(steps):
		game.arena.update_state(game.rules, 0, 1.0 / 60, 1.0)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
			if not out_dir.ends_with("/"): out_dir += "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("res://") else out_dir)
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if root.focus_exited.is_connected(game.pause_pve): root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "res://tests/ultra-preview.tmp"
	game.set_process(false)
	game.set_physics_process(false)
	game.start_level(3)
	game.set_process(false)
	game.set_physics_process(false)
	game.rules.phase = "play"
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.fit_content_scale()
	game.hud.layout()
	game.frame_arena()
	# A few rounds in the air from both sides.
	for i in range(3):
		game.rules.players[0].cooldown = 0.0
		game.rules.players[1].cooldown = 0.0
		game.rules.step(1.0 / 60, [{"move": Vector2(0.4, 0), "fire": true}, {"move": Vector2(-0.3, 0), "fire": true}])
		game.play_events()
		for t in range(14):
			game.rules.step(1.0 / 60, [{"move": Vector2(0.4, 0), "fire": false}, {"move": Vector2(-0.3, 0), "fire": false}])
			game.play_events()
			game.arena.update_state(game.rules, 0, 1.0 / 60, 1.0)
	game.hud.update_match(game.rules, "")
	await capture("1-arena")
	# The fight: a blast, a thunderbolt and bricks breaking, caught mid-flash.
	var events: Array = [
		{"kind": "explosion", "p": Vector2(1.2, -3.5), "radius": 1.65, "team": 0},
		{"kind": "thunder", "p": Vector2(-1.8, 3.2), "radius": 1.0, "team": 1},
	]
	game.rules.events = events
	game.play_events()
	game.arena.burst(Vector2(-2.6, -4.6), game.arena.shot_colors[0], true)
	game.arena.burst(Vector2(2.9, 4.4), game.arena.shot_colors[1], true)
	settle(game, 0.1)
	await capture("2-combate-impacto")
	settle(game, 0.22)
	await capture("3-combate-depois")
	for i in range(120): game.arena.update_state(game.rules, 0, 1.0 / 60, 1.0)
	# Pilots up close.
	root.size = Vector2i(512, 640)
	game.hud.hide()
	game.arena.units[1].hide()
	var cam = game.arena.camera
	var shots: Array = []
	for skin in [0, 5, 10, 100]:
		game.arena.set_skin(0, skin, skin >= 100, "5fc8ff" if skin >= 100 else "")
		var unit = game.arena.units[0]
		unit.get_node("Body").rotation.y = PI + 0.35
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 26
		cam.h_offset = 0
		cam.v_offset = 0
		cam.global_position = unit.global_position + Vector3(0, 1.6, 5.7)
		cam.look_at(unit.global_position + Vector3.UP * 1.0)
		shots.append(await capture("piloto-%d" % skin))
	var sheet = Image.create(2048, 640, false, shots[0].get_format())
	for i in range(shots.size()): sheet.blit_rect(shots[i], Rect2i(0, 0, 512, 640), Vector2i(i * 512, 0))
	sheet.save_png(out_dir + "4-pilotos.png")
	game.queue_free()
	await process_frame
	quit()
