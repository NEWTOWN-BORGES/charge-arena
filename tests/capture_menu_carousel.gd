extends SceneTree
# Menu carousel: previews of several levels in portrait and landscape, and how long
# rebuilding a previewed stadium takes (needs a GPU; omit --headless).
const Campaign = preload("res://scripts/campaign.gd")
const TMP = "res://tests/carousel-capture.tmp"

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
	game.campaign = Campaign.new()
	game.campaign.config_path = TMP
	game.campaign.completed = [0, 1]
	game.hud.sync_campaign(game.campaign)
	await create_timer(0.6).timeout
	var timings: Array = []
	for level in [0, 4, 9]:
		game.menu_level = level
		game.hud.sync_menu_level(level)
		var start = Time.get_ticks_msec()
		game.show_menu_preview()
		timings.append(Time.get_ticks_msec() - start)
		await create_timer(0.5).timeout
		await capture("preview-carousel-level-%02d.png" % (level + 1))
	print("PREVIEW_REBUILD_MS ", timings)
	root.size = Vector2i(1280, 720)
	game.menu_level = 6
	game.hud.sync_menu_level(6)
	game.show_menu_preview()
	await create_timer(0.6).timeout
	await capture("preview-carousel-landscape.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	quit(0)
