extends SceneTree
# Capture a screenshot of the new PvP Colosseum map for visual inspection.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	# Set up the colosseum map directly without needing network
	game.mode = "pve"
	game.local_team = 0
	var Rules = preload("res://scripts/arena_rules.gd")
	game.leave_campaign(Rules.pvp_map())
	game.rules.reset_match()
	game.dress_pilots(0)
	game.hud.show_game("pve", 0)
	game.rules.phase = "play"
	game.pause_ai = true
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-colosseum.png")
	print("CAPTURED preview-colosseum.png")
	# Portrait too
	root.size = Vector2i(540, 960)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview-colosseum-portrait.png")
	print("CAPTURED preview-colosseum-portrait.png")
	quit()
