extends SceneTree
# Skins viewer, unlock banner and coloured shots (needs a GPU; omit --headless).
# Progress is written to a temporary file, never to the real save.
const TMP = "res://tests/skins-capture.tmp"

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png("res://" + path)
	print("SCREENSHOT ", path, " result=", error)

func run() -> void:
	root.size = Vector2i(540, 1200)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.skins.config_path = TMP
	game.skins.defeated = [1, 2, 3]
	game.skins.selected = 1
	game.hud.sync_skins(game.skins)
	game.dress_pilots(0)
	await create_timer(0.5).timeout
	game.hud.open_skins()
	for view in [[1, 0.5, "faroleiro"], [3, -0.6, "jardineiro"], [5, 2.4, "sentinela"]]:
		game.hud.preview_skin(view[0])
		game.hud.viewer_yaw = view[1]
		await create_timer(1.3).timeout
		await capture("preview-skins-viewer-%s.png" % view[2])
	game.hud.close_skins()
	game.start_pve()
	game.pause_ai = true
	await create_timer(3.4).timeout
	game.skins.defeat(4)
	game.hud.sync_skins(game.skins)
	game.hud.announce_unlock([game.Skins.CATALOG[4].name])
	await create_timer(0.3).timeout
	await capture("preview-skins-unlock.png")
	game.return_to_menu()
	game.select_skin(2)
	game.start_pve()
	game.pause_ai = true
	await create_timer(3.2).timeout
	for i in range(3):
		game.rules.players[0].cooldown = 0
		game.rules.shoot(0)
		game.rules.shoot(1)
		await create_timer(0.12).timeout
	await capture("preview-skins-match-shots.png")
	root.size = Vector2i(1280, 720)
	game.return_to_menu()
	game.hud.open_skins()
	game.hud.preview_skin(4)
	game.hud.viewer_yaw = 0.9
	await create_timer(1.0).timeout
	await capture("preview-skins-landscape.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	quit(0)
