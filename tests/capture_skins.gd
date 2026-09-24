extends SceneTree
# Close-up sheet of every pilot skin (needs a GPU; omit --headless).
# Top rows: studio views. Bottom row: the real gameplay camera, zoomed.
const TILE = 360

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

func gameplay(game, cam: Camera3D, unit: Node3D) -> Image:
	unit.get_node("Body").rotation.y = 0
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.global_position = Vector3(0, 26, 15)
	cam.look_at(Vector3(0, -0.15, 0))
	cam.size = 3.2
	var offset = unit.global_position + Vector3.UP * 0.9 - cam.global_position
	cam.h_offset = offset.dot(cam.global_transform.basis.x)
	cam.v_offset = offset.dot(cam.global_transform.basis.y)
	return await shot()

func bank_center(arena) -> Vector3:
	# Middle of the player's left brick bank (bricks 0-19 belong to team 0, side -1).
	var total = Vector3.ZERO
	for i in range(20):
		total += arena.brick_nodes[i].global_position
	return total / 20.0

func bricks_gameplay(cam: Camera3D, center: Vector3) -> Image:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.global_position = Vector3(0, 26, 15)
	cam.look_at(Vector3(0, -0.15, 0))
	cam.size = 3.4
	var offset = center + Vector3.UP * 0.3 - cam.global_position
	cam.h_offset = offset.dot(cam.global_transform.basis.x)
	cam.v_offset = offset.dot(cam.global_transform.basis.y)
	return await shot()

func bricks_studio(cam: Camera3D, center: Vector3) -> Image:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 24
	cam.h_offset = 0
	cam.v_offset = 0
	cam.global_position = center + Vector3(-0.9, 1.3, 2.6)
	cam.look_at(center + Vector3.UP * 0.3)
	return await shot()

func run() -> void:
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
	var cam: Camera3D = arena.camera
	var count: int = game.Skins.CATALOG.size()
	var columns: Array = []
	for skin in range(count):
		columns.append([])
		arena.set_skin(0, skin)
		await process_frame
		var unit: Node3D = arena.units[0]
		columns[skin].append(await studio(cam, unit, PI))
		columns[skin].append(await studio(cam, unit, 0))
		columns[skin].append(await studio(cam, unit, PI * 0.5))
		columns[skin].append(await gameplay(game, cam, unit))
		columns[skin].append(await bricks_gameplay(cam, bank_center(arena)))
		columns[skin].append(await bricks_studio(cam, bank_center(arena)))
	# Rows: front, back, side, gameplay, bricks in play, bricks close up. One column per skin.
	var sheet = Image.create(TILE * count, TILE * 6, false, columns[0][0].get_format())
	for skin in range(count):
		for row in range(6):
			sheet.blit_rect(columns[skin][row], Rect2i(0, 0, TILE, TILE), Vector2i(skin * TILE, row * TILE))
	var error = sheet.save_png("res://preview-skins-sheet.png")
	print("SKIN_SHEET result=", error)
	quit(error)
