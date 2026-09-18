extends SceneTree
# Power shop, kit and the new powers in play (needs a GPU; omit --headless).
# Progress is written to a temporary file, never to the real save.
const TMP = "res://tests/powers-capture.tmp"

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
	game.power_shop.config_path = TMP
	game.power_shop.bricks = 1400
	game.power_shop.unlock_all = false
	game.power_shop.owned = ["blast", "air", "ghost", "laser", "mirror", "walls", "stun"]
	game.power_shop.kit = ["walls", "stun"]
	game.hud.sync_powers(game.power_shop)
	await create_timer(0.5).timeout
	game.hud.open_powers()
	for index in [4, 6, 8]:
		game.hud.preview_power(index)
		await create_timer(0.4).timeout
		await capture("preview-powers-shop-%d.png" % index)
	root.size = Vector2i(1280, 720)
	await create_timer(0.6).timeout
	await capture("preview-powers-shop-landscape.png")
	game.hud.close_powers()

	# In play: the buttons carry the equipped kit, and each power on the field.
	root.size = Vector2i(540, 1200)
	game.start_pve()
	game.pause_ai = true
	await create_timer(1.2).timeout
	game.rules.phase = "play"
	game.rules.powers[0].charge = [99, 99, 99]
	await create_timer(0.3).timeout
	await capture("preview-powers-buttons.png")
	game.rules.activate_power(0, 0)
	await create_timer(0.7).timeout
	await capture("preview-powers-walls.png")
	await create_timer(3.6).timeout
	game.rules.powers[0].charge = [99, 99, 99]
	game.rules.shoot(0)
	game.rules.shoot(1)
	game.rules.activate_power(0, 1)
	await create_timer(0.55).timeout
	await capture("preview-powers-shock.png")
	# The machine gun stream, fired from the kit swapped in for the shot.
	await create_timer(1.2).timeout
	game.rules.loadouts[0] = ["rapid", "mirror", ""]
	game.rules.powers[0].charge = [99, 99, 99]
	game.rules.activate_power(0, 0)
	await create_timer(0.55).timeout
	await capture("preview-powers-rapid.png")
	await create_timer(1.0).timeout
	game.rules.powers[0].charge = [99, 99, 99]
	game.rules.activate_power(0, 1)
	await create_timer(0.3).timeout
	await capture("preview-powers-mirror.png")
	game.rules.powers[1].charge = [99, 99, 99]
	game.rules.loadouts[1] = ["rebuild", "shield", ""]
	for i in range(game.rules.bricks.size()):
		if game.rules.bricks[i].team == 1 and i % 3 != 0:
			game.rules.bricks[i].hp = 0
			game.rules.bricks[i].alive = false
	game.rules.activate_power(1, 0)
	await create_timer(0.12).timeout
	await capture("preview-powers-rebuild.png")
	game.rules.powers[1].charge = [99, 99, 99]
	game.rules.activate_power(1, 1)
	await create_timer(0.4).timeout
	await capture("preview-powers-shield.png")
	game.return_to_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	quit(0)
