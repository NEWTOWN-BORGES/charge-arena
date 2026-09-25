extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host = OS.get_cmdline_user_args().has("--host")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.power_shop.config_path = "res://tests/feedback-net-wallet-%s.tmp" % host
	game.skins.config_path = "res://tests/feedback-net-skins-%s.tmp" % host
	game.game_settings.auto_fire = false
	game.hud.sync_game(game.game_settings)
	if host: game.host_game()
	else: game.join_game("127.0.0.1")
	var sent = false
	var observed = false
	var connected_ticks = 0
	for n in range(1200):
		await create_timer(0.025).timeout
		if not game.connected: continue
		connected_ticks += 1
		if not host and game.rules.phase == "play" and not sent:
			game.hud.fire_tap = 1
			sent = true
		if game.shot_variants[1] == 2: observed = true
		if connected_ticks > 180 and observed:
			var passed = game.shot_variants[1] == 2 and game.shot_variants[0] == 0
			print("FEEDBACK_NETWORK ", "host" if host else "client", " one_tap_one_shot=", passed)
			await create_timer(1.5 if host else 0.4).timeout
			game.close_network()
			quit(0 if passed else 1)
			return
	push_error("Manual PvP shot was not observed")
	game.close_network()
	quit(1)

