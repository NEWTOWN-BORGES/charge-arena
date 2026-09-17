extends SceneTree
# Menu, level list, PvP panel, level intro, win screen and a campaign arena in play
# (needs a GPU; omit --headless). Progress goes to a temporary file.
const Campaign = preload("res://scripts/campaign.gd")
const TMP = "res://tests/campaign-capture.tmp"

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
	game.campaign.unlocked = 4
	game.campaign.completed = [0, 1, 2]
	game.hud.sync_campaign(game.campaign)
	await create_timer(0.8).timeout
	await capture("preview-campaign-menu.png")
	game.hud.open_levels()
	await create_timer(0.3).timeout
	await capture("preview-campaign-levels.png")
	game.hud.close_levels()
	game.hud.open_pvp()
	await create_timer(0.3).timeout
	await capture("preview-campaign-pvp.png")
	game.hud.close_pvp()
	game.start_level(3)
	game.pause_ai = true
	await create_timer(0.7).timeout
	await capture("preview-campaign-intro.png")
	await create_timer(3.0).timeout
	for i in range(3):
		game.rules.players[0].cooldown = 0
		game.rules.shoot(0)
		await create_timer(0.15).timeout
	await capture("preview-campaign-play.png")
	game.rules.phase = "finished"
	game.rules.winner = 0
	await create_timer(0.5).timeout
	await capture("preview-campaign-win.png")
	root.size = Vector2i(1280, 720)
	game.return_to_menu()
	await create_timer(0.6).timeout
	await capture("preview-campaign-menu-landscape.png")
	game.hud.open_levels()
	await create_timer(0.3).timeout
	await capture("preview-campaign-levels-landscape.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	quit(0)
