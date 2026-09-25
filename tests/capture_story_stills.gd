extends SceneTree
# The story's stills - the versus portraits and the newspaper photographs - developed as
# the game develops them (needs a GPU; omit --headless).

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", path, " result=", root.get_texture().get_image().save_png("res://" + path))

func run() -> void:
	root.size = Vector2i(720, 1440)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.campaign.config_path = "res://tests/stills-campaign.tmp"
	game.skins.config_path = "res://tests/stills-skins.tmp"
	game.power_shop.config_path = "res://tests/stills-powers.tmp"
	game.cup.path = "res://tests/stills-cup.tmp"
	game.cup.seed_value = 31337
	game.cup.reset()
	game.sync_story()
	await create_timer(0.8).timeout
	game.hud.campaign_button.pressed.emit()
	await create_timer(0.3).timeout
	var hub = game.cup_screen
	hub.open_versus()
	await create_timer(1.4).timeout
	await capture("preview-stills-versus.png")
	hub.close_overlay()
	hub.open_paper(0)
	await create_timer(2.5).timeout
	await capture("preview-stills-paper.png")
	for f in ["stills-campaign.tmp", "stills-skins.tmp", "stills-powers.tmp", "stills-cup.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/" + f))
	quit(0)
