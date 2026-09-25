extends SceneTree
# Close-up of one pilot skin: front, back, side and the gameplay camera (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_pilot.gd -- <skin> <output.png> [hue, e.g. ef947e]
const TILE = 480

func _initialize() -> void:
	call_deferred("run")

func shot() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func studio(cam: Camera3D, unit: Node3D, turn: float) -> Image:
	unit.get_node("Body").rotation.y = turn
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 26
	cam.h_offset = 0
	cam.v_offset = 0
	cam.global_position = unit.global_position + Vector3(0, 1.45, 4.6)
	cam.look_at(unit.global_position + Vector3.UP * 0.95)
	return await shot()

func gameplay(cam: Camera3D, unit: Node3D) -> Image:
	unit.get_node("Body").rotation.y = 0
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.global_position = Vector3(0, 26, 15)
	cam.look_at(Vector3(0, -0.15, 0))
	cam.size = 3.2
	var offset = unit.global_position + Vector3.UP * 0.9 - cam.global_position
	cam.h_offset = offset.dot(cam.global_transform.basis.x)
	cam.v_offset = offset.dot(cam.global_transform.basis.y)
	return await shot()

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var skin = int(args[0]) if args.size() > 0 else 0
	var path = args[1] if args.size() > 1 else "res://preview-pilot.png"
	root.size = Vector2i(TILE, TILE)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.3).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.start_pve()
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.visible = false
	var arena = game.arena
	arena.set_skin(0, skin, false, args[2] if args.size() > 2 else "")
	await process_frame
	var unit: Node3D = arena.units[0]
	var tiles = [await studio(arena.camera, unit, PI), await studio(arena.camera, unit, 0), await studio(arena.camera, unit, PI * 0.5), await gameplay(arena.camera, unit)]
	var sheet = Image.create(TILE * tiles.size(), TILE, false, tiles[0].get_format())
	for i in range(tiles.size()):
		sheet.blit_rect(tiles[i], Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
	var error = sheet.save_png(path)
	print("PILOT_SHEET skin=", skin, " result=", error)
	quit(error)
